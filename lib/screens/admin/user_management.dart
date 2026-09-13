import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import 'web/admin_web_layout.dart';

/// User Management screen – admin view of registered accounts.
///
/// Features:
/// - Top part: Registered Citizen Users (Pet owners, finders, users) with search & filters.
/// - Bottom part (Super Admin only): Barangay Administrators list.
/// - Barangay Admins only see citizen users of their own barangay (no admins visible).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  int _filterIndex = 0;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _citizenUsers = [];
  List<Map<String, dynamic>> _barangayAdmins = [];
  List<Map<String, dynamic>> _newsPosts = [];

  bool _isLoading = true;
  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.user;

  final List<String> _filters = ['All Users', 'Unverified'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    _currentUserRole = await AuthService.instance.getCurrentUserRole();
    await Future.wait([
      _fetchUsers(),
      _fetchNewsPosts(),
    ]);
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      if (_currentUserRole == UserRole.superAdmin) {
        // Super admin fetches all citizen users and all barangay admins
        final citizensData = await Supabase.instance.client
            .from('users')
            .select()
            .neq('role', 'admin')
            .neq('role', 'super_admin')
            .order('created_at', ascending: false);

        final adminsData = await Supabase.instance.client
            .from('users')
            .select()
            .eq('role', 'admin')
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _citizenUsers = List<Map<String, dynamic>>.from(citizensData);
            _barangayAdmins = List<Map<String, dynamic>>.from(adminsData);
            _isLoading = false;
          });
        }
      } else {
        // Barangay admin: strictly fetch citizen users from their barangay (no admins)
        var query = Supabase.instance.client
            .from('users')
            .select()
            .neq('role', 'admin')
            .neq('role', 'super_admin');

        if (_adminBarangay.isNotEmpty) {
          query = query.eq('barangay', _adminBarangay);
        }

        final citizensData = await query.order('created_at', ascending: false);
        if (mounted) {
          setState(() {
            _citizenUsers = List<Map<String, dynamic>>.from(citizensData);
            _barangayAdmins = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchNewsPosts() async {
    try {
      var query = Supabase.instance.client.from('news').select();
      if (_currentUserRole != UserRole.superAdmin && _adminBarangay.isNotEmpty) {
        query = query.eq('barangay', _adminBarangay);
      }
      final data = await query.order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _newsPosts = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
  }

  Future<void> _deleteNewsPost(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete News Post?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('news').delete().eq('id', id);
      await _fetchNewsPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('News post deleted'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting news: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredCitizens {
    List<Map<String, dynamic>> list = List.from(_citizenUsers);
    if (_filterIndex == 1) {
      // Filter for unverified users (empty phone)
      list = list.where((u) => (u['phone'] ?? '').toString().isEmpty).toList();
    }
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((u) {
        final fName = (u['first_name'] ?? '').toString().toLowerCase();
        final sName = (u['surname'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final barangay = (u['barangay'] ?? '').toString().toLowerCase();
        return fName.contains(q) ||
            sName.contains(q) ||
            email.contains(q) ||
            barangay.contains(q);
      }).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredAdmins {
    List<Map<String, dynamic>> list = List.from(_barangayAdmins);
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((u) {
        final fName = (u['first_name'] ?? '').toString().toLowerCase();
        final sName = (u['surname'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final barangay = (u['barangay'] ?? '').toString().toLowerCase();
        return fName.contains(q) ||
            sName.contains(q) ||
            email.contains(q) ||
            barangay.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      backgroundColor: AppColors.surface,
      body: AdminLayout(
        currentIndex: 3,
        pageTitle: 'User Management',
        role: _currentUserRole,
        child: _buildBody(context),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDesktopLayout() {
    if (_isLoading) {
      return const AdminWebLayout(
        currentIndex: 3,
        pageTitle: 'User Management',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return AdminWebLayout(
      currentIndex: 3,
      pageTitle: 'User Management',
      body: _buildDesktopContent(),
    );
  }

  Widget _buildDesktopContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. News Posts Section Card ──
        Card(
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
                    'News Posts & Announcements (${_newsPosts.length})',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, AppRoutes.postNews);
                      _fetchNewsPosts();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'Create Post',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              rowsPerPage: 10,
              showFirstLastButtons: true,
              columns: const [
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Source')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Actions')),
              ],
              source: _NewsDataTableSource(
                _newsPosts,
                onDelete: _deleteNewsPost,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── 2. Registered Users Section Card ──
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar and filter chips in header area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildSearchBar()),
                      const SizedBox(width: 16),
                      _buildFilterPills(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(
                    cardColor: Colors.white,
                    dividerColor: Colors.grey.shade200,
                  ),
                  child: PaginatedDataTable(
                    header: Row(
                      children: [
                        Text(
                          'Registered Users (${_filteredCitizens.length})',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          onPressed: () {
                            _fetchUsers();
                            _fetchNewsPosts();
                          },
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
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    source: _UsersDataTableSource(
                      _filteredCitizens,
                      onAction: _handleUserAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    final fName = user['first_name'] ?? '';
    final sName = user['surname'] ?? '';
    final fullName = '$fName $sName'.trim();
    final phone = user['phone']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    if (action == 'view') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(fullName.isNotEmpty ? fullName : 'User Profile',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${email.isNotEmpty ? email : 'None'}',
                  style: GoogleFonts.inter()),
              const SizedBox(height: 6),
              Text('Phone: ${phone.isNotEmpty ? phone : 'Not provided'}',
                  style: GoogleFonts.inter()),
              const SizedBox(height: 6),
              Text('Barangay: ${user['barangay'] ?? 'N/A'}',
                  style: GoogleFonts.inter()),
              const SizedBox(height: 6),
              Text('Role: ${user['role'] ?? 'user'}',
                  style: GoogleFonts.inter()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else if (action == 'contact') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(phone.isNotEmpty
              ? 'Contacting $phone...'
              : 'No phone number for $fullName'),
          backgroundColor: AppColors.primary,
        ),
      );
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
                  onRefresh: _fetchUsers,
                  color: AppColors.primary,
                  child: AdminContentWrapper(
                    maxWidth: 1100,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 800;
                        return isWide
                            ? _buildWideLayout()
                            : _buildNarrowLayout();
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── NARROW / MOBILE LAYOUT ────────────────────────────────────────────────

  Widget _buildNarrowLayout() {
    final showAdmins =
        _currentUserRole == UserRole.superAdmin && _barangayAdmins.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // ── TOP PART: Registered Users ──
        _buildUsersSectionHeader(),
        const SizedBox(height: 14),
        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildFilterPills(),
        const SizedBox(height: 16),
        if (_filteredCitizens.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'No users found.',
                    style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          )
        else
          ..._filteredCitizens.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildUserCard(u, isCompact: false),
              )),

        // ── BOTTOM PART: Barangay Admins (Super Admin Only) ──
        if (showAdmins) ...[
          const SizedBox(height: 32),
          const Divider(height: 1, color: AppColors.surfaceContainer),
          const SizedBox(height: 24),
          _buildAdminsSectionHeader(),
          const SizedBox(height: 16),
          if (_filteredAdmins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No administrators found.',
                  style: GoogleFonts.inter(
                      color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                ),
              ),
            )
          else
            ..._filteredAdmins.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildUserCard(u, isCompact: false),
                )),
        ],
      ],
    );
  }

  // ─── WIDE / DESKTOP LAYOUT ─────────────────────────────────────────────────

  Widget _buildWideLayout() {
    final showAdmins =
        _currentUserRole == UserRole.superAdmin && _barangayAdmins.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP PART: Registered Users ──
          _buildUsersSectionHeader(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSearchBar()),
              const SizedBox(width: 16),
              _buildFilterPills(),
            ],
          ),
          const SizedBox(height: 16),
          if (_filteredCitizens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No users found matching your query.',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._filteredCitizens.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildUserCard(u, isCompact: true),
                )),

          // ── BOTTOM PART: Barangay Admins (Super Admin Only) ──
          if (showAdmins) ...[
            const SizedBox(height: 40),
            const Divider(height: 1, color: AppColors.surfaceContainer),
            const SizedBox(height: 28),
            _buildAdminsSectionHeader(),
            const SizedBox(height: 16),
            if (_filteredAdmins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No administrators found matching your search.',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                  ),
                ),
              )
            else
              ..._filteredAdmins.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildUserCard(u, isCompact: true),
                  )),
          ],
        ],
      ),
    );
  }

  // ─── SECTION HEADERS ───────────────────────────────────────────────────────

  Widget _buildUsersSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.group_rounded,
              color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registered Users',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_adminBarangay.isNotEmpty &&
                  _currentUserRole != UserRole.superAdmin)
                Text(
                  'Brgy. $_adminBarangay',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_filteredCitizens.length} of ${_citizenUsers.length} Users',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminsSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shield_rounded,
              color: Color(0xFF00796B), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Barangay Administrators',
                style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Assigned Barangay Admins across Catanduanes',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_filteredAdmins.length} of ${_barangayAdmins.length} Admins',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00796B)),
          ),
        ),
      ],
    );
  }

  // ─── SEARCH & FILTER PILLS ────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: AppColors.outline),
        hintText: 'Search by name, email, or barangay...',
        hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildFilterPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _filterIndex;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : AppColors.outlineVariant.withOpacity(0.2)),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: AppColors.primaryContainer.withOpacity(0.25),
                            blurRadius: 8)
                      ]
                    : [],
              ),
              child: Text(
                _filters[i],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.onPrimaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── USER & ADMIN CARDS ───────────────────────────────────────────────────

  Widget _buildUserCard(Map<String, dynamic> user, {bool isCompact = false}) {
    final fName = user['first_name'] as String? ?? '';
    final mName = user['middle_name'] as String? ?? '';
    final sName = user['surname'] as String? ?? '';
    final suffix = user['suffix'] as String? ?? '';
    final name =
        [fName, mName, sName, suffix].where((s) => s.isNotEmpty).join(' ');

    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? 'owner';
    final barangay = user['barangay'] as String? ?? '';
    final photoUrl = user['photo_url'] as String? ?? '';
    final phone = user['phone'] as String? ?? '';
    final verified = phone.isNotEmpty;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceContainer),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarFallback(name),
                      )
                    : _avatarFallback(name),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name.isNotEmpty ? name : 'Unnamed User',
                          style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _roleBadge(role),
                    ],
                  ),
                  if (barangay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Brgy. $barangay',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant.withOpacity(0.8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: verified
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFFBBF24),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  verified ? 'Verified' : 'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: verified
                        ? const Color(0xFF15803D)
                        : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.outline, size: 20),
              onPressed: () => _showUserMenu(name, user),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 46,
              height: 46,
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(name),
                    )
                  : _avatarFallback(name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isNotEmpty ? name : 'Unnamed User',
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _roleBadge(role),
                  ],
                ),
                Text(email,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: verified
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          verified ? 'Verified' : 'Pending Verification',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: verified
                                ? const Color(0xFF15803D)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                    if (barangay.isNotEmpty)
                      Text(
                        '•  Brgy. $barangay',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.more_vert, color: AppColors.outline, size: 20),
            onPressed: () => _showUserMenu(name, user),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppColors.secondaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isSuperAdmin = role.toLowerCase() == 'super_admin';
    final isAdmin = role.toLowerCase() == 'admin';

    Color bg = AppColors.secondaryContainer;
    Color fg = AppColors.onSecondaryContainer;
    String label = 'USER';

    if (isSuperAdmin) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      label = 'SUPER ADMIN';
    } else if (isAdmin) {
      bg = const Color(0xFF00796B).withOpacity(0.15);
      fg = const Color(0xFF00796B);
      label = 'ADMIN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }

  void _showUserMenu(String name, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name.isNotEmpty ? name : 'User Details',
              style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.person_outline, color: AppColors.primary),
              title:
                  Text('View Profile', style: GoogleFonts.inter(fontSize: 14)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  const Icon(Icons.verified_user, color: Color(0xFF22C55E)),
              title:
                  Text('Verify User', style: GoogleFonts.inter(fontSize: 14)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Remove User',
                  style:
                      GoogleFonts.inter(fontSize: 14, color: AppColors.error)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // Hidden on web — AdminLayout provides the top bar
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 800) return const SizedBox.shrink();
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding:
          EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Text(
            'User Management',
            style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.onSurfaceVariant),
            onPressed: () async {
              final nav = Navigator.of(context);
              await AuthService.instance.signOut();
              nav.pushNamedAndRemoveUntil('/', (_) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: () {
          // Add user modal
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add User',
                    style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a new citizen user account for Brgy. ${_adminBarangay.isNotEmpty ? _adminBarangay : 'Catanduanes'}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text('Pet Owner',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Can register and manage pets',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurfaceVariant)),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF9333EA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.search,
                          color: Color(0xFF9333EA), size: 20),
                    ),
                    title: Text('Finder',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Can report and scan found pets',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.onSurfaceVariant)),
                    onTap: () => Navigator.pop(context),
                  ),
                  if (_currentUserRole == UserRole.superAdmin) ...[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.admin_panel_settings,
                            color: Color(0xFF00796B), size: 20),
                      ),
                      title: Text('Barangay Admin',
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Can manage a barangay\'s news and pets',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant)),
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        icon: const Icon(Icons.add),
        label: Text('Add User',
            style: GoogleFonts.montserrat(
                fontSize: 13, fontWeight: FontWeight.w700)),
        elevation: 8,
        extendedIconLabelSpacing: 6,
      ),
    );
  }
}

/// DataTableSource for News Posts on desktop web in UserManagementScreen.
class _NewsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> news;
  final Function(String id) onDelete;

  _NewsDataTableSource(this.news, {required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= news.length) return null;
    final item = news[index];

    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Untitled';
    final category = item['category']?.toString() ?? 'General';
    final source = item['source']?.toString() ?? 'PawTrace';
    final createdAt = item['created_at']?.toString() ?? '';

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
      } catch (_) {
        formattedDate = createdAt;
      }
    }

    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Category chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Title
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
        // Source
        DataCell(Text(source, style: GoogleFonts.inter(fontSize: 13))),
        // Date
        DataCell(Text(formattedDate, style: GoogleFonts.inter(fontSize: 13))),
        // Delete action
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
            tooltip: 'Delete Announcement',
            onPressed: () => onDelete(id),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => news.length;

  @override
  int get selectedRowCount => 0;
}

/// DataTableSource for Registered Users on desktop web in UserManagementScreen.
class _UsersDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> users;
  final Function(String action, Map<String, dynamic> user) onAction;

  _UsersDataTableSource(this.users, {required this.onAction});

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final user = users[index];

    final fName = user['first_name'] as String? ?? '';
    final sName = user['surname'] as String? ?? '';
    final fullName = '$fName $sName'.trim();
    final email = user['email'] as String? ?? '';
    final phone = user['phone'] as String? ?? '';
    final role = (user['role'] as String? ?? 'user').toLowerCase();
    final initial =
        fullName.isNotEmpty ? fullName[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : 'U');

    final isVerified = phone.isNotEmpty;
    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Avatar: CircleAvatar with initial
        DataCell(
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryContainer,
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
        // Name
        DataCell(
          Text(
            fullName.isNotEmpty ? fullName : 'Unnamed User',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
        // Email
        DataCell(
          Text(
            email.isNotEmpty ? email : '-',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        // Phone
        DataCell(
          Text(
            phone.isNotEmpty ? phone : '-',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        // Role badge chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: role == 'admin' || role == 'super_admin'
                  ? const Color(0xFF00796B).withOpacity(0.15)
                  : AppColors.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: role == 'admin' || role == 'super_admin'
                    ? const Color(0xFF00796B)
                    : AppColors.primary,
              ),
            ),
          ),
        ),
        // Verified status chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isVerified
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isVerified ? 'VERIFIED' : 'UNVERIFIED',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isVerified
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
            ),
          ),
        ),
        // Three dot PopupMenuButton
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) => onAction(action, user),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'contact',
                child: Row(
                  children: [
                    Icon(Icons.call_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Contact User'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => users.length;

  @override
  int get selectedRowCount => 0;
}

