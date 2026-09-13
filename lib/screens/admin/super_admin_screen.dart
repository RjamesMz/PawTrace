import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import '../../widgets/stat_card.dart';
import 'admin_reports_screen.dart';
import 'admin_pets_screen.dart';
import 'web/admin_web_layout.dart';

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

  // ── Admin form controllers ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegistering = false;

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

  String _selectedMunicipality = 'Virac';
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

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    if (mounted) setState(() => _isLoading = true);

    await Future.wait([
      _fetchStatCounts(),
      _fetchBarangayOverview(),
      _fetchAdmins(),
      _fetchRecentReports(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStatCounts() async {
    try {
      final results = await Future.wait([
        // Total Pets
        _supabase
            .from('pets')
            .select('pet_id')
            .count(CountOption.exact),
        // Total Users (owners + finders)
        _supabase
            .from('users')
            .select('user_id')
            .inFilter('role', ['owner', 'finder'])
            .count(CountOption.exact),
        // Active Lost Reports
        _supabase
            .from('lost_reports')
            .select('report_id')
            .eq('status', 'active')
            .count(CountOption.exact),
        // Total Barangay Admins
        _supabase
            .from('users')
            .select('user_id')
            .eq('role', 'admin')
            .count(CountOption.exact),
      ]);

      _totalPets = results[0].count;
      _totalUsers = results[1].count;
      _totalLostReports = results[2].count;
      _totalAdmins = results[3].count;
    } catch (e) {
      debugPrint('Error fetching stat counts: $e');
    }
  }

  Future<void> _fetchBarangayOverview() async {
    try {
      final pets = await _supabase
          .from('pets')
          .select('barangay, status');

      final admins = await _supabase
          .from('users')
          .select('first_name, surname, barangay')
          .eq('role', 'admin');

      // Group by barangay
      final Map<String, Map<String, dynamic>> grouped = {};
      for (final m in _municipalities) {
        grouped[m] = {'name': m, 'pets': 0, 'lost': 0, 'admin': null};
      }

      for (final p in pets) {
        final b = p['barangay']?.toString() ?? '';
        if (grouped.containsKey(b)) {
          grouped[b]!['pets'] = (grouped[b]!['pets'] as int) + 1;
          final status = p['status']?.toString().toLowerCase() ?? '';
          if (status == 'lost' || status == 'missing') {
            grouped[b]!['lost'] = (grouped[b]!['lost'] as int) + 1;
          }
        }
      }

      for (final a in admins) {
        final b = a['barangay']?.toString() ?? '';
        if (grouped.containsKey(b) && grouped[b]!['admin'] == null) {
          final fn = a['first_name'] ?? '';
          final sn = a['surname'] ?? '';
          grouped[b]!['admin'] = '$fn $sn'.trim();
        }
      }

      _barangayOverview = grouped.values.toList();
    } catch (e) {
      debugPrint('Error fetching barangay overview: $e');
      _barangayOverview = [];
    }
  }

  Future<void> _fetchAdmins() async {
    try {
      final data = await _supabase
          .from('users')
          .select('user_id, first_name, surname, email, phone, barangay, role, created_at')
          .eq('role', 'admin')
          .order('created_at', ascending: false)
          .limit(5);
      _admins = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching admins: $e');
      _admins = [];
    }
  }

  Future<void> _fetchRecentReports() async {
    try {
      final data = await _supabase
          .from('lost_reports')
          .select('report_id, reported_at, barangay, pets(name, photo_url), owner_id(first_name, surname)')
          .order('reported_at', ascending: false)
          .limit(5);
      _recentReports = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching recent reports: $e');
      _recentReports = [];
    }
  }

  // ─── Admin CRUD ──────────────────────────────────────────────────────────

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final fName = _firstNameCtrl.text.trim();
    final sName = _surnameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() => _isRegistering = true);

    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': fName,
          'surname': sName,
          'phone': phone,
          'barangay': _selectedMunicipality,
          'role': 'admin',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barangay Admin registered successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        _firstNameCtrl.clear();
        _surnameCtrl.clear();
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _passwordCtrl.clear();
        Navigator.pop(context);
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register admin: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _deleteAdmin(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Admin?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to remove the admin account for $email? This action is permanent.',
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('users').delete().eq('user_id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin account removed successfully.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete admin: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return _buildDesktopLayout();
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
                        _buildAdminsSection(),
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
    );
  }

  // ─── Desktop Web Layout ───────────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    final isAdminTab = _webTabIndex == 4 || _webTabIndex == 5;
    if (_isLoading) {
      return AdminWebLayout(
        currentIndex: isAdminTab ? 5 : 0,
        pageTitle: isAdminTab ? 'Barangay Admins' : 'Super Admin Dashboard',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (isAdminTab) {
      return AdminWebLayout(
        currentIndex: 5,
        pageTitle: 'Barangay Admins',
        body: _buildWebAdminsSection(),
      );
    }

    return AdminWebLayout(
      currentIndex: 0,
      pageTitle: 'Super Admin Dashboard',
      body: _buildWebDashboard(),
    );
  }

  Widget _buildWebDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner full width orange gradient Container height 100 border radius 16
        Container(
          height: 100,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                      'Good morning Super Admin',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Province-wide control center',
                      style: GoogleFonts.inter(
                        fontSize: 14,
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
        ),
        const SizedBox(height: 20),

        // Row of 4 StatCard widgets each in Expanded with height 110 spacing 16
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Total Pets',
                  count: _totalPets,
                  icon: Icons.pets_rounded,
                  color: const Color(0xFFFF6600),
                  isLoading: _isLoading,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Registered Users',
                  count: _totalUsers,
                  icon: Icons.people_rounded,
                  color: const Color(0xFF4E7AC7),
                  isLoading: _isLoading,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Active Reports',
                  count: _totalLostReports,
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFBA1A1A),
                  isLoading: _isLoading,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Barangay Admins',
                  count: _totalAdmins,
                  icon: Icons.shield_rounded,
                  color: const Color(0xFF00796B),
                  isLoading: _isLoading,
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
            // Left 60%: Card with PaginatedDataTable of recent lost reports
            Expanded(
              flex: 6,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    cardColor: Colors.white,
                    dividerColor: Colors.grey.shade200,
                  ),
                  child: PaginatedDataTable(
                    header: Row(
                      children: [
                        Text(
                          'Recent Lost Reports',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminReportsScreen()),
                          ),
                          child: Text(
                            'View All Reports',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    rowsPerPage: 10,
                    showFirstLastButtons: true,
                    columns: const [
                      DataColumn(label: Text('Photo')),
                      DataColumn(label: Text('Pet Name')),
                      DataColumn(label: Text('Municipality')),
                      DataColumn(label: Text('Owner')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Status')),
                    ],
                    source: _RecentReportsDataTableSource(_recentReports),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right 40%: Card with title Barangay Admins list showing each admin as compact ListTile
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Barangay Admins',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _webTabIndex = 5);
                            },
                            child: Text(
                              'Manage All',
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
                      if (_admins.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No Barangay Admins registered yet.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _admins.length > 5 ? 5 : _admins.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0x12000000)),
                          itemBuilder: (context, index) {
                            final admin = _admins[index];
                            final fName = admin['first_name'] ?? '';
                            final sName = admin['surname'] ?? '';
                            final name = '$fName $sName'.trim();
                            final barangay = admin['barangay'] ?? '';
                            final initial =
                                name.isNotEmpty ? name[0].toUpperCase() : 'A';

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.15),
                                child: Text(
                                  initial,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                barangay.isNotEmpty
                                    ? 'Brgy. $barangay'
                                    : 'No Barangay',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
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
          ],
        ),
      ],
    );
  }

  Widget _buildWebAdminsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          cardColor: Colors.white,
          dividerColor: Colors.grey.shade200,
        ),
        child: PaginatedDataTable(
          header: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Dashboard',
                onPressed: () {
                  setState(() => _webTabIndex = 0);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Barangay Administrators',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddAdminSheet,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Add Admin',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          rowsPerPage: 10,
          showFirstLastButtons: true,
          columns: const [
            DataColumn(label: Text('Avatar')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Assigned Barangay')),
            DataColumn(label: Text('Actions')),
          ],
          source: _AdminsDataTableSource(_admins, onDelete: _deleteAdmin),
        ),
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
              return StatCardGrid(
                crossAxisCount: isWide ? 4 : 2,
                childAspectRatio: isWide ? 1.1 : 1.3,
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
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Section 3 — Barangay Overview ───────────────────────────────────────

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
                'BARANGAY BREAKDOWN',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full barangay list
                },
                child: Text(
                  'See All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 145,
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
                      return _buildBarangayCard(b);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarangayCard(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? '';
    final petCount = data['pets'] as int? ?? 0;
    final lostCount = data['lost'] as int? ?? 0;
    final adminName = data['admin']?.toString();

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to BarangayDetailScreen(barangay: name)
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Pet count pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$petCount pets',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Lost / safe pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: lostCount > 0
                    ? AppColors.errorContainer.withOpacity(0.4)
                    : const Color(0xFF22C55E).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lostCount > 0 ? '$lostCount lost' : 'All Safe',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: lostCount > 0
                      ? AppColors.error
                      : const Color(0xFF22C55E),
                ),
              ),
            ),
            const Spacer(),
            // Admin name
            Text(
              adminName != null && adminName.isNotEmpty
                  ? adminName
                  : 'No Admin Assigned',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: adminName != null && adminName.isNotEmpty
                    ? AppColors.onSurfaceVariant
                    : AppColors.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section 4 — Barangay Admins ─────────────────────────────────────────

  Widget _buildAdminsSection() {
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
                'BARANGAY ADMINS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddAdminSheet,
                icon: const Icon(Icons.add_circle_outline,
                    size: 16, color: AppColors.primary),
                label: Text(
                  'Add Admin',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_admins.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No Barangay Admins registered yet.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return _buildAdminsDataTable();
                }
                return Column(
                  children: List.generate(_admins.length, (i) {
                    final admin = _admins[i];
                    return _buildAdminCard(admin);
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAdminsDataTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.surfaceContainerLow),
          headingTextStyle: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
          dataTextStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurface,
          ),
          columns: const [
            DataColumn(label: Text('Avatar')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Barangay')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _admins.map((admin) {
            final fName = admin['first_name'] as String? ?? '';
            final sName = admin['surname'] as String? ?? '';
            final email = admin['email'] as String? ?? '';
            final phone = admin['phone'] as String? ?? '';
            final barangay = admin['barangay'] as String? ?? '';
            final userId = admin['user_id'] as String? ?? '';
            final initial = fName.isNotEmpty ? fName[0].toUpperCase() : 'A';

            return DataRow(
              cells: [
                DataCell(
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      initial,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '$fName $sName',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                DataCell(Text(email.isNotEmpty ? email : '-')),
                DataCell(Text(phone.isNotEmpty ? phone : '-')),
                DataCell(
                  barangay.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            barangay,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : const Text('-'),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'Remove Admin',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () => _deleteAdmin(userId, email),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final fName = admin['first_name'] as String? ?? '';
    final sName = admin['surname'] as String? ?? '';
    final email = admin['email'] as String? ?? '';
    final phone = admin['phone'] as String? ?? '';
    final barangay = admin['barangay'] as String? ?? '';
    final userId = admin['user_id'] as String? ?? '';
    final initial = fName.isNotEmpty ? fName[0].toUpperCase() : 'A';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              initial,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fName $sName',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (barangay.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              constraints: const BoxConstraints(maxWidth: 80),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                barangay,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          IconButton(
            tooltip: 'Remove Admin',
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
            onPressed: () => _deleteAdmin(userId, email),
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
                      return _buildReportItem(_recentReports[i],
                          removeBottomMargin: true);
                    },
                  );
                }
                return Column(
                  children: List.generate(_recentReports.length, (i) {
                    final report = _recentReports[i];
                    return _buildReportItem(report);
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> report,
      {bool removeBottomMargin = false}) {
    // Extract pet info (may be a map from FK join)
    final pet = report['pets'];
    final petName = pet is Map ? (pet['name']?.toString() ?? 'Unknown Pet') : 'Unknown Pet';
    final petPhoto = pet is Map ? (pet['photo_url']?.toString() ?? '') : '';

    // Extract owner info
    final owner = report['owner_id'];
    final ownerName = owner is Map
        ? '${owner['first_name'] ?? ''} ${owner['surname'] ?? ''}'.trim()
        : 'Unknown Owner';

    final barangay = report['barangay']?.toString() ?? report['municipality']?.toString() ?? '';
    final reportedAt = report['reported_at']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: removeBottomMargin ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pet photo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: petPhoto.isNotEmpty
                ? Image.network(
                    petPhoto,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                  )
                : _buildPhotoPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Owner: $ownerName',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                if (barangay.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    barangay,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
                if (reportedAt.isNotEmpty)
                  Text(
                    _formatTimeAgo(reportedAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          // LOST badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'LOST',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.pets, color: AppColors.primary, size: 24),
    );
  }

  // ─── Section 6 — Action Buttons ──────────────────────────────────────────

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
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
      ),
    );
  }

  // ─── Add Admin Bottom Sheet ──────────────────────────────────────────────

  void _showAddAdminSheet() {
    _selectedMunicipality = 'Virac';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                    'Register Barangay Admin',
                    style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Assign a new admin to a municipality in Catanduanes.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _firstNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'First Name *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _surnameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Surname *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address *',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Temp Password *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) =>
                        v == null || v.trim().length < 6
                            ? 'Min 6 characters'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMunicipality,
                    decoration: InputDecoration(
                      labelText: 'Assigned Municipality',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: _municipalities
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        _selectedMunicipality = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isRegistering ? null : _registerAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isRegistering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Register Admin',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DataTableSource for Recent Lost Reports in SuperAdmin web dashboard.
class _RecentReportsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> reports;

  _RecentReportsDataTableSource(this.reports);

  @override
  DataRow? getRow(int index) {
    if (index >= reports.length) return null;
    final report = reports[index];

    final pet = report['pets'];
    final petName = pet is Map
        ? (pet['name']?.toString() ?? 'Unknown Pet')
        : 'Unknown Pet';
    final petPhoto = pet is Map ? (pet['photo_url']?.toString() ?? '') : '';

    final owner = report['owner_id'];
    final ownerName = owner is Map
        ? '${owner['first_name'] ?? ''} ${owner['surname'] ?? ''}'.trim()
        : 'Unknown Owner';

    final municipality = report['barangay']?.toString() ??
        report['municipality']?.toString() ??
        'Catanduanes';
    final reportedAt = report['reported_at']?.toString() ?? '';
    final status = (report['status']?.toString() ?? 'active').toLowerCase();

    String formattedDate = '';
    if (reportedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(reportedAt);
        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
      } catch (_) {
        formattedDate = reportedAt;
      }
    }

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage:
                petPhoto.isNotEmpty ? NetworkImage(petPhoto) : null,
            child: petPhoto.isEmpty
                ? const Icon(Icons.pets, size: 16, color: AppColors.primary)
                : null,
          ),
        ),
        DataCell(Text(
          petName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        )),
        DataCell(Text(municipality, style: GoogleFonts.inter())),
        DataCell(Text(
          ownerName.isNotEmpty ? ownerName : 'Unknown',
          style: GoogleFonts.inter(),
        )),
        DataCell(Text(formattedDate, style: GoogleFonts.inter())),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'resolved'
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status == 'resolved'
                    ? const Color(0xFF22C55E)
                    : AppColors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => reports.length;

  @override
  int get selectedRowCount => 0;
}

/// DataTableSource for Barangay Admins in SuperAdmin web dashboard.
class _AdminsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> admins;
  final Function(String userId, String email) onDelete;

  _AdminsDataTableSource(this.admins, {required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= admins.length) return null;
    final admin = admins[index];

    final fName = admin['first_name'] as String? ?? '';
    final sName = admin['surname'] as String? ?? '';
    final email = admin['email'] as String? ?? '';
    final phone = admin['phone'] as String? ?? '';
    final barangay = admin['barangay'] as String? ?? '';
    final userId = admin['user_id'] as String? ?? '';
    final initial = fName.isNotEmpty ? fName[0].toUpperCase() : 'A';

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              initial,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        DataCell(Text(
          '$fName $sName',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        )),
        DataCell(Text(email.isNotEmpty ? email : '-')),
        DataCell(Text(phone.isNotEmpty ? phone : '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              barangay.isNotEmpty ? barangay : '-',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Remove Admin',
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
            onPressed: () => onDelete(userId, email),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => admins.length;

  @override
  int get selectedRowCount => 0;
}

