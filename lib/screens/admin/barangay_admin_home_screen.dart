import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import '../../widgets/stat_card.dart';
import '../shared/news_detail_screen.dart';
import 'admin_pets_screen.dart';
import 'admin_reports_screen.dart';
import 'web/admin_web_layout.dart';

/// Barangay Admin Home Screen — main dashboard visible when the admin taps Home.
///
/// Shows greeting, 4 stat cards, pending verification reports, AI match preview,
/// and recent activity. All data scoped by the admin's assigned barangay.
class BarangayAdminHomeScreen extends StatefulWidget {
  const BarangayAdminHomeScreen({super.key});

  @override
  State<BarangayAdminHomeScreen> createState() =>
      _BarangayAdminHomeScreenState();
}

class _BarangayAdminHomeScreenState extends State<BarangayAdminHomeScreen> {
  final _supabase = Supabase.instance.client;

  String _adminBarangay = '';
  String _adminName = 'Admin';
  bool _isLoading = true;

  // Stat counts
  int _registeredPets = 0;
  int _lostReports = 0;
  int _registeredUsers = 0;
  int _aiMatches = 0;
  int _pendingCount = 0;

  // Data lists
  List<Map<String, dynamic>> _news = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _pendingReports = [];
  bool _newsExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    // Fetch admin barangay and profile
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    final profile = await AuthService.instance.getCurrentUserProfile();
    if (profile != null) {
      final first = profile['first_name'] ?? '';
      final surname = profile['surname'] ?? '';
      if (first.toString().isNotEmpty) {
        _adminName = '$first $surname'.trim();
      }
    }

    await Future.wait([
      _fetchStats(),
      _fetchNews(),
      _fetchRecentActivity(),
      _fetchPendingReports(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStats() async {
    try {
      // Registered pets
      final pets = await _supabase
          .from('pets')
          .select('pet_id')
          .eq('barangay', _adminBarangay);
      _registeredPets = pets.length;

      // Lost reports
      final lost = await _supabase
          .from('lost_reports')
          .select('report_id')
          .eq('barangay', _adminBarangay);
      _lostReports = lost.length;

      // Registered Users count (scoped to barangay)
      final users = await _supabase
          .from('users')
          .select('user_id')
          .eq('barangay', _adminBarangay);
      _registeredUsers = users.length;
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> _fetchNews() async {
    try {
      final data = await _supabase
          .from('news')
          .select()
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false)
          .limit(3);
      _news = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
  }

  Future<void> _fetchRecentActivity() async {
    try {
      // Fetch recently registered pets as activity items
      final pets = await _supabase
          .from('pets')
          .select('name, created_at, users(first_name, surname)')
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false)
          .limit(5);

      final List<Map<String, dynamic>> activities = [];
      for (final p in pets) {
        final petName = p['name'] ?? 'A pet';
        final u = p['users'];
        final ownerName = u != null
            ? '${u['first_name'] ?? ''} ${u['surname'] ?? ''}'.trim()
            : 'Someone';
        activities.add({
          'description': '$petName was registered by $ownerName',
          'timestamp': p['created_at'],
          'color': const Color(0xFF22C55E),
        });
      }

      // Fetch recent lost reports as activity
      final reports = await _supabase
          .from('lost_reports')
          .select('*, pets(name), owner_id(first_name, surname)')
          .eq('barangay', _adminBarangay)
          .order('reported_at', ascending: false)
          .limit(5);

      for (final r in reports) {
        final petData = r['pets'];
        final petName = petData is Map ? (petData['name'] ?? 'A pet') : 'A pet';
        final userData = r['owner_id'];
        final reporterName = userData is Map
            ? '${userData['first_name'] ?? ''} ${userData['surname'] ?? ''}'
                .trim()
            : 'Someone';
        activities.add({
          'description': '$petName was reported lost by $reporterName',
          'timestamp': r['reported_at'],
          'color': AppColors.error,
        });
      }

      // Sort by timestamp descending
      activities.sort((a, b) {
        final ta = a['timestamp']?.toString() ?? '';
        final tb = b['timestamp']?.toString() ?? '';
        return tb.compareTo(ta);
      });

      _recentActivity = activities.take(8).toList();
    } catch (e) {
      debugPrint('Error fetching activity: $e');
    }
  }

  Future<void> _fetchPendingReports() async {
    try {
      final data = await _supabase
          .from('lost_reports')
          .select('*, pets(name, photo_url), owner_id(first_name, surname, phone)')
          .eq('barangay', _adminBarangay)
          .order('reported_at', ascending: false);

      final reports = List<Map<String, dynamic>>.from(data);
      _pendingReports = reports.where((r) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        return status == 'pending' || status == 'active';
      }).toList();
      _pendingCount = _pendingReports.length;
      // Simulated AI match count based on reports with pet photo
      _aiMatches = reports.where((r) {
        final pet = r['pets'];
        return pet is Map && (pet['photo_url']?.toString().isNotEmpty ?? false);
      }).length;
    } catch (e) {
      debugPrint('Error fetching pending reports: $e');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: AdminLayout(
        currentIndex: 0,
        pageTitle: 'Dashboard',
        role: UserRole.admin,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    if (_isLoading) {
      return const AdminWebLayout(
        currentIndex: 0,
        pageTitle: 'Barangay Dashboard',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return AdminWebLayout(
      currentIndex: 0,
      pageTitle: 'Barangay Dashboard',
      body: _buildDesktopDashboard(),
    );
  }

  Widget _buildDesktopDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner orange gradient height 90 showing Good morning Admin and barangay name subtitle
        Container(
          height: 90,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Good morning Admin',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _adminBarangay.isNotEmpty
                          ? 'Brgy. $_adminBarangay Control Center'
                          : 'Barangay Control Center',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_work_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Row of 4 StatCard widgets height 110 spacing 16
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Registered Pets',
                  count: _registeredPets,
                  icon: Icons.pets_rounded,
                  color: const Color(0xFFFF6600),
                  isLoading: _isLoading,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPetsScreen()),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Lost Reports',
                  count: _lostReports,
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFBA1A1A),
                  isLoading: _isLoading,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen()),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'AI Matches',
                  count: _aiMatches,
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF9333EA),
                  isLoading: _isLoading,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Pending',
                  count: _pendingCount,
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFF59E0B),
                  isLoading: _isLoading,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen()),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Row with two Expanded sections: left 60%, right 40%
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left 60%: Card showing pending verification reports as a ListView of compact ListTile items
            Expanded(
              flex: 6,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Verification Reports',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminReportsScreen()),
                            ),
                            child: Text(
                              'View All',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      if (_pendingReports.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No pending reports to verify',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingReports.length > 5
                              ? 5
                              : _pendingReports.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: Color(0x12000000)),
                          itemBuilder: (context, index) {
                            final report = _pendingReports[index];
                            final pet = report['pets'];
                            final petName = pet is Map
                                ? (pet['name']?.toString() ?? 'Unknown Pet')
                                : 'Unknown Pet';
                            final petPhoto = pet is Map
                                ? (pet['photo_url']?.toString() ?? '')
                                : '';
                            final location =
                                report['barangay']?.toString() ?? _adminBarangay;
                            final status = (report['status']?.toString() ??
                                    'pending')
                                .toUpperCase();

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryContainer,
                                backgroundImage: petPhoto.isNotEmpty
                                    ? NetworkImage(petPhoto)
                                    : null,
                                child: petPhoto.isEmpty
                                    ? const Icon(Icons.pets,
                                        size: 16, color: AppColors.primary)
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    petName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 12,
                                      color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text(
                                    location,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminReportsScreen()),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Review',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right 40%: Card showing recent activity as a Timeline-style ListView
            Expanded(
              flex: 4,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      if (_recentActivity.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              'No recent activity',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentActivity.length > 6
                              ? 6
                              : _recentActivity.length,
                          itemBuilder: (context, index) {
                            final act = _recentActivity[index];
                            final desc = act['description']?.toString() ?? '';
                            final color =
                                (act['color'] as Color?) ?? AppColors.primary;
                            final ts = act['timestamp']?.toString() ?? '';
                            final isLast = index ==
                                (_recentActivity.length > 6
                                    ? 5
                                    : _recentActivity.length - 1);

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (ts.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatRelativeTime(ts),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRelativeTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  Widget _buildBody(BuildContext context) {
    return Column(
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
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                    child: AdminContentWrapper(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGreeting(),
                              const SizedBox(height: 18),
                              _buildStatCards(constraints.maxWidth),
                              const SizedBox(height: 24),
                              _buildNewsSection(),
                              const SizedBox(height: 24),
                              _buildRecentActivity(),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── AppBar (mobile only — hidden on web by AdminLayout) ────────────────────

  Widget _buildAppBar(BuildContext context) {
    // On wide screens AdminLayout renders its own top bar; hide this one.
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Access the parent AdminLayout breakpoint via MediaQuery
        final screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth >= 800) return const SizedBox.shrink();
        return Container(
          height: 64 + MediaQuery.of(context).padding.top,
          padding:
              EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            children: [
              // PawTrace logo + name
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'PawTrace',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              // Notification bell with red badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppColors.onSurfaceVariant, size: 26),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              // Admin avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Greeting ────────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()}, $_adminName',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s what\'s happening in Brgy. $_adminBarangay today.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Cards ──────────────────────────────────────────────────────────────

  Widget _buildStatCards(double availableWidth) {
    final isWide = availableWidth >= 900;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StatCardGrid(
        crossAxisCount: isWide ? 3 : 2,
        childAspectRatio: isWide ? 1.4 : 1.3,
        children: [
          StatCard(
            label: 'Registered Pets',
            count: _registeredPets,
            icon: Icons.pets,
            color: AppColors.primary,
            isLoading: _isLoading,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPetsScreen()),
            ),
          ),
          StatCard(
            label: 'Lost Reports',
            count: _lostReports,
            icon: Icons.flag_rounded,
            color: AppColors.error,
            isLoading: _isLoading,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
            ),
          ),
          StatCard(
            label: 'Registered Users',
            count: _registeredUsers,
            icon: Icons.group_rounded,
            color: const Color(0xFF9333EA),
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ─── News Announcements Section ─────────────────────────────────────────────

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        content: Text('This will permanently remove the news post.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _supabase.from('news').delete().eq('id', postId);
      _fetchNews();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting post: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Widget _buildNewsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'News & Announcements',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.postNews);
                  _fetchNews();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Create Post',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryContainer.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _newsExpanded = !_newsExpanded),
                child: AnimatedRotation(
                  turns: _newsExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          firstChild: _news.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('No announcements yet',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.6))),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: _news
                      .map((post) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: _buildPostCard(post),
                          ))
                      .toList(),
                ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _newsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final title = post['title'] as String? ?? 'Untitled';
    final summary = post['summary'] as String? ?? '';
    final category = post['category'] as String? ?? '';
    final imageUrl = post['image_url'] as String? ?? '';
    final accentHex = post['accent_color'] as String? ?? '#FF6600';
    final postId = post['id']?.toString() ?? '';

    Color accentColor = AppColors.primary;
    try {
      final hex = accentHex.replaceFirst('#', '');
      accentColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewsDetailScreen(news: post),
                  ),
                );
              },
              child: Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14)),
                      child: Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: accentColor.withOpacity(0.15),
                            child: Icon(Icons.article_rounded,
                                color: accentColor, size: 28)),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14)),
                      ),
                      child: Icon(Icons.article_rounded, color: accentColor, size: 28),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(category,
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor)),
                            ),
                          Text(title,
                              style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (summary.isNotEmpty)
                            Text(summary,
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            tooltip: 'Delete post',
            onPressed: () => _deletePost(postId),
          ),
        ],
      ),
    );
  }

  // ─── Recent Activity ─────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recent Activity',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text('No recent activity',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withOpacity(0.6))),
              ),
            ),
          )
        else
          ...List.generate(
            _recentActivity.length,
            (i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _buildActivityItem(_recentActivity[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final description = activity['description'] as String? ?? '';
    final color = activity['color'] as Color? ?? AppColors.primary;
    final timeAgo = _formatTimeAgo(activity['timestamp']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }
}

