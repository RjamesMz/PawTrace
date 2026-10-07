import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/admin/admin_content_wrapper.dart';
import '../../widgets/admin/admin_layout.dart';
import '../../widgets/admin/stat_card.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../admin/reports/admin_reports_screen.dart';
import '../admin/pets/admin_pets_screen.dart';
import '../../widgets/super_admin/add_admin_sheet.dart';
import '../../widgets/super_admin/super_admin_cards.dart';
import '../../widgets/super_admin/super_admin_desktop_view.dart';

/// Super Admin Dashboard — province-wide control center for PawTrace
/// in Catanduanes. Shows aggregate stats, barangay breakdown, admin
/// management, and recent lost reports.
class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _supabase = Supabase.instance.client;

  // ── Loading state ────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _adminName = 'Super Admin';
  String? _photoUrl;

  // ── Province-wide stat counts ────────────────────────────────────────────
  int _totalPets = 0;
  int _totalUsers = 0;
  int _totalLostReports = 0;
  int _totalAdmins = 0;

  // ── Barangay overview data ───────────────────────────────────────────────
  List<Map<String, dynamic>> _barangayOverview = [];

  // ── Admins list ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _admins = [];

  // ── Recent lost reports ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _recentReports = [];

  /// Catanduanes municipalities used for barangay dropdown
  static const List<String> _municipalities = [
    'Bagamanoc',
    'Baras',
    'Bato',
    'Caramoran',
    'Gigmoto',
    'Pandan',
    'Panganiban',
    'San Andres',
    'San Miguel',
    'Viga',
    'Virac',
  ];

  int _webTabIndex = 0;
  bool _webTabInitialized = false;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_webTabInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['tab'] is int) {
        _webTabIndex = args['tab'] as int;
      }
      _webTabInitialized = true;
    }
  }

  // ─── Data Loading ────────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final profile = await AuthService.instance.getCurrentUserProfile();
      if (profile != null) {
        final first = profile['first_name'] ?? '';
        final surname = profile['surname'] ?? '';
        if (first.toString().isNotEmpty) {
          _adminName = '$first $surname'.trim();
        }
        _photoUrl = profile['photo_url']?.toString();
      }
    } catch (_) {}

    await Future.wait([
      _loadProvinceStats(),
      _loadBarangayOverview(),
      _loadAdmins(),
      _loadRecentReports(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProvinceStats() async {
    try {
      final results = await Future.wait([
        _supabase
            .from('pets')
            .select('pet_id')
            .neq('status', 'archived')
            .neq('status', 'Archived'),
        _supabase
            .from('users')
            .select('user_id')
            .neq('role', 'admin')
            .neq('role', 'super_admin'),
        _supabase.from('lost_reports').select('report_id').eq('status', 'active'),
        _supabase.from('users').select('user_id').eq('role', 'admin'),
      ]);

      _totalPets = (results[0] as List).length;
      _totalUsers = (results[1] as List).length;
      _totalLostReports = (results[2] as List).length;
      _totalAdmins = (results[3] as List).length;
    } catch (e) {
      debugPrint('Error fetching province stats: $e');
    }
  }

  Future<void> _loadBarangayOverview() async {
    try {
      final petsData = await _supabase
          .from('pets')
          .select('barangay, status')
          .neq('status', 'archived')
          .neq('status', 'Archived');
      final adminsData = await _supabase
          .from('users')
          .select('barangay, first_name, surname')
          .eq('role', 'admin');

      final petCounts = <String, int>{};
      final lostCounts = <String, int>{};
      for (final p in petsData as List) {
        final b = (p['barangay'] as String?)?.trim() ?? '';
        if (b.isEmpty) continue;
        petCounts[b] = (petCounts[b] ?? 0) + 1;
        final rawStatus = (p['status'] as String?)?.toLowerCase() ?? '';
        final isLost = rawStatus == 'lost' || rawStatus == 'missing';
        if (isLost) {
          lostCounts[b] = (lostCounts[b] ?? 0) + 1;
        }
      }

      final adminMap = <String, String>{};
      for (final a in adminsData as List) {
        final b = (a['barangay'] as String?)?.trim() ?? '';
        if (b.isNotEmpty && !adminMap.containsKey(b)) {
          final fName = a['first_name'] ?? '';
          final sName = a['surname'] ?? '';
          adminMap[b] = '$fName $sName'.trim();
        }
      }

      final allBarangays = <String>{
        ..._municipalities,
        ...petCounts.keys,
        ...adminMap.keys,
      }.toList()
        ..sort();

      _barangayOverview = allBarangays.map((name) {
        return {
          'name': name,
          'pets': petCounts[name] ?? 0,
          'lost': lostCounts[name] ?? 0,
          'admin': adminMap[name] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching barangay overview: $e');
      _barangayOverview = _municipalities.map((m) {
        return {'name': m, 'pets': 0, 'lost': 0, 'admin': ''};
      }).toList();
    }
  }

  Future<void> _loadAdmins() async {
    try {
      final data = await _supabase
          .from('users')
          .select('user_id, first_name, surname, email, phone, barangay, status')
          .eq('role', 'admin')
          .order('first_name');
      _admins = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching admins: $e');
      _admins = [];
    }
  }

  Future<void> _loadRecentReports() async {
    try {
      final data = await _supabase
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)')
          .order('reported_at', ascending: false)
          .limit(10);
      _recentReports = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching recent reports: $e');
      _recentReports = [];
    }
  }

  // ─── Admin Status Management ──────────────────────────────────────────────

  Future<void> _toggleAdminStatus(
      String userId, String email, bool isDeactivated) async {
    final actionTitle = isDeactivated ? 'Reactivate Admin' : 'Deactivate Admin';
    final targetStatus = isDeactivated ? 'active' : 'deactivated';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$actionTitle?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text(
            isDeactivated
                ? 'Are you sure you want to reactivate the admin account for $email?'
                : 'Are you sure you want to deactivate the admin account for $email? The account will be marked as deactivated, but no data will be deleted.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDeactivated ? const Color(0xFF16A34A) : AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionTitle,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('users')
          .update({'status': targetStatus})
          .eq('user_id', userId);
      if (mounted) {
        AppToast.success(
            context, 'Admin account has been $targetStatus successfully.');
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to update admin status: $e');
      }
    }
  }

  void _showAddAdminSheet() {
    AddAdminSheet.show(
      context,
      municipalities: _municipalities,
      onAdminRegistered: _loadDashboard,
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return SuperAdminDesktopView(
        isLoading: _isLoading,
        totalPets: _totalPets,
        totalUsers: _totalUsers,
        totalLostReports: _totalLostReports,
        totalAdmins: _totalAdmins,
        recentReports: _recentReports,
        admins: _admins,
        webTabIndex: _webTabIndex,
        onTabChanged: (index) => setState(() => _webTabIndex = index),
        onToggleAdminStatus: _toggleAdminStatus,
        onAddAdmin: _showAddAdminSheet,
      );
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdminLayout(
        currentIndex: 0,
        pageTitle: 'Super Admin Dashboard',
        role: UserRole.superAdmin,
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _loadDashboard,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: AdminContentWrapper(
                          maxWidth: 1200,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWelcomeBanner(),
                              const SizedBox(height: 8),
                              _buildProvinceStats(),
                              const SizedBox(height: 8),
                              _buildBarangayOverview(),
                              const SizedBox(height: 8),
                              _buildRecentReports(),
                              const SizedBox(height: 8),
                              _buildActionButtons(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AppBar (mobile only — hidden on web by AdminLayout) ────────────────────

  Widget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 800) return const SizedBox.shrink();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // PawTrace logo + name
          AppConstants.buildLogoGraphic(size: 26),
          const SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          const NotificationBellButton(size: 24),
          const SizedBox(width: 8),
          // Super Admin avatar
          InkWell(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.adminSettings),
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? NetworkImage(_photoUrl!)
                  : null,
              child: (_photoUrl == null || _photoUrl!.isEmpty)
                  ? Text(
                      _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'S',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section 1 — Welcome Banner ──────────────────────────────────────────

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6600), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6600).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, Super Admin',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Province-wide Control Center',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // ─── Section 2 — Province Stats ──────────────────────────────────────────

  Widget _buildProvinceStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'PROVINCE OVERVIEW',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final crossAxisCount = isWide ? 4 : 2;
              final childAspectRatio = isWide ? 2.2 : 1.35;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                    label: 'Total Pets',
                    count: _totalPets,
                    icon: Icons.pets_rounded,
                    color: const Color(0xFFFF6600),
                    isLoading: _isLoading,
                  ),
                  StatCard(
                    label: 'Registered Users',
                    count: _totalUsers,
                    icon: Icons.people_rounded,
                    color: const Color(0xFF4E7AC7),
                    isLoading: _isLoading,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.userManagement,
                        arguments: {'tab': 0},
                      );
                    },
                  ),
                  StatCard(
                    label: 'Active Reports',
                    count: _totalLostReports,
                    icon: Icons.flag_rounded,
                    color: const Color(0xFFBA1A1A),
                    isLoading: _isLoading,
                  ),
                  StatCard(
                    label: 'Barangay Admins',
                    count: _totalAdmins,
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF00796B),
                    isLoading: _isLoading,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.userManagement,
                        arguments: {'tab': 1},
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Section 3 — Barangay Breakdown Carousel ─────────────────────────────

  Widget _buildBarangayOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MUNICIPALITIES & BARANGAYS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${_barangayOverview.length} areas',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 155,
            child: _barangayOverview.isEmpty
                ? Center(
                    child: Text('No barangay data available.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.onSurfaceVariant)),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _barangayOverview.length,
                    itemBuilder: (context, index) {
                      final b = _barangayOverview[index];
                      return SuperAdminBarangayCard(data: b);
                    },
                  ),
          ),
        ],
      ),
    );
  }



  // ─── Section 5 — Recent Lost Reports ─────────────────────────────────────

  Widget _buildRecentReports() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'RECENT REPORTS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (_recentReports.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'No recent reports.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3.4,
                    ),
                    itemCount: _recentReports.length,
                    itemBuilder: (context, i) {
                      return SuperAdminReportItem(
                        report: _recentReports[i],
                        removeBottomMargin: true,
                        onRefreshNeeded: _loadDashboard,
                      );
                    },
                  );
                }
                return Column(
                  children: List.generate(_recentReports.length, (i) {
                    final report = _recentReports[i];
                    return SuperAdminReportItem(
                      report: report,
                      onRefreshNeeded: _loadDashboard,
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Section 6 — Action Buttons ──────────────────────────────────────────

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          if (isNarrow) {
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminReportsScreen()),
                    ),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text('View All Reports',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPetsScreen()),
                    ),
                    icon: const Icon(Icons.pets_rounded, size: 18),
                    label: Text('View All Pets',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen()),
                  ),
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: Text('View All Reports',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminPetsScreen()),
                  ),
                  icon: const Icon(Icons.pets_rounded, size: 18),
                  label: Text('View All Pets',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
