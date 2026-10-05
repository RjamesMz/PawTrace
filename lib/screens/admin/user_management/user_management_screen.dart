import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../services/auth/auth_service.dart';
import '../../../widgets/admin/admin_content_wrapper.dart';
import '../../../widgets/admin/admin_layout.dart';
import '../../../widgets/admin/user_management/add_admin_dialog.dart';
import '../../../widgets/admin/user_management/user_card.dart';
import '../../../widgets/admin/user_management/user_action_handler.dart';
import '../../../widgets/admin/user_management/user_management_desktop_view.dart';
import '../../../widgets/admin/web/admin_web_layout.dart';

/// User Management screen – admin view of registered accounts.
///
/// Features:
/// - Top part: Registered Citizen Users (Pet owners, finders, users) with search & filters.
/// - Bottom part (Super Admin only): Barangay Administrators list.
/// - Barangay Admins only see citizen users of their own barangay (no admins visible).
class UserManagementScreen extends StatefulWidget {
  final int initialTab;
  const UserManagementScreen({super.key, this.initialTab = 0});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  int _filterIndex = 0;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _citizenUsers = [];
  List<Map<String, dynamic>> _barangayAdmins = [];

  bool _isLoading = true;
  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.user;


  int _selectedUserTypeTab = 0; // 0 = Citizen Users, 1 = Barangay Admins
  bool _tabFromArgsInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedUserTypeTab = widget.initialTab;
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tabFromArgsInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['tab'] is int) {
        _selectedUserTypeTab = args['tab'] as int;
      } else if (args is int) {
        _selectedUserTypeTab = args;
      }
      _tabFromArgsInitialized = true;
    }
  }

  Future<void> _init() async {
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    _currentUserRole = await AuthService.instance.getCurrentUserRole();
    await _fetchUsers();
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

  List<Map<String, dynamic>> get _filteredCitizens {
    List<Map<String, dynamic>> list = List.from(_citizenUsers);
    if (_filterIndex == 1) {
      // Active (Verified & Not Deactivated)
      list = list.where((u) {
        final st = (u['status'] ?? 'unverified').toString().toLowerCase();
        return (st == 'active' || st == 'verified') &&
            st != 'deactivated' &&
            st != 'de_activated';
      }).toList();
    } else if (_filterIndex == 2) {
      // Unverified
      list = list.where((u) {
        final st = (u['status'] ?? 'unverified').toString().toLowerCase();
        return (st == 'unverified' || st == 'pending') &&
            st != 'deactivated' &&
            st != 'de_activated';
      }).toList();
    } else if (_filterIndex == 3) {
      // Deactivated
      list = list.where((u) {
        final st = (u['status'] ?? 'unverified').toString().toLowerCase();
        return st == 'deactivated' || st == 'de_activated';
      }).toList();
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
    if (_filterIndex == 1) {
      // Active
      list = list.where((u) {
        final st = (u['status'] ?? 'unverified').toString().toLowerCase();
        return (st == 'active' || st == 'verified') &&
            st != 'deactivated' &&
            st != 'de_activated';
      }).toList();
    } else if (_filterIndex == 2) {
      // Unverified
      list = list.where((u) {
        final st = (u['status'] ?? 'unverified').toString().toLowerCase();
        return (st == 'unverified' || st == 'pending') &&
            st != 'deactivated' &&
            st != 'de_activated';
      }).toList();
    } else if (_filterIndex == 3) {
      // Deactivated
      list = list.where((u) {
        final st = (u['status'] ?? 'unverified').toString().toLowerCase();
        return st == 'deactivated' || st == 'de_activated';
      }).toList();
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

  Widget _buildRoleSegmentedSwitcher() {
    if (_currentUserRole != UserRole.superAdmin) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleSegmentButton(
              index: 0,
              title: 'Citizen Users',
              count: _citizenUsers.length,
              icon: Icons.people_alt_rounded,
              activeColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildRoleSegmentButton(
              index: 1,
              title: 'Barangay Admins',
              count: _barangayAdmins.length,
              icon: Icons.shield_rounded,
              activeColor: const Color(0xFF00796B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSegmentButton({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedUserTypeTab == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedUserTypeTab != index) {
            setState(() {
              _selectedUserTypeTab = index;
              _searchCtrl.clear();
              _filterIndex = 0;
            });
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? activeColor : AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.12)
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent() {
    return UserManagementDesktopView(
      currentUserRole: _currentUserRole,
      selectedUserTypeTab: _selectedUserTypeTab,
      filteredCitizens: _filteredCitizens,
      filteredAdmins: _filteredAdmins,
      roleSegmentedSwitcher: _buildRoleSegmentedSwitcher(),
      searchBar: _buildSearchBar(),
      filterPills: _buildFilterPills(),
      onRefresh: _fetchUsers,
      onShowAddAdminModal: _showAddAdminModal,
      onAction: _handleUserAction,
    );
  }

  void _showAddAdminModal() {
    AddAdminDialog.show(
      context,
      onAdminRegistered: _fetchUsers,
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) async {
    await UserActionHandler.handleAction(
      context: context,
      action: action,
      user: user,
      onRefresh: _fetchUsers,
    );
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
    final isSuperAdmin = _currentUserRole == UserRole.superAdmin;
    final showAdmins = isSuperAdmin && _selectedUserTypeTab == 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (isSuperAdmin) _buildRoleSegmentedSwitcher(),
        if (!showAdmins) ...[
          // ── Registered Citizen Users ──
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
        ] else ...[
          // ── Barangay Administrators ──
          _buildAdminsSectionHeader(),
          const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterPills(),
          const SizedBox(height: 16),
          if (_filteredAdmins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No administrators found.',
                      style: GoogleFonts.inter(
                          color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                    ),
                  ],
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
    final isSuperAdmin = _currentUserRole == UserRole.superAdmin;
    final showAdmins = isSuperAdmin && _selectedUserTypeTab == 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperAdmin) _buildRoleSegmentedSwitcher(),
          if (!showAdmins) ...[
            // ── Registered Citizen Users ──
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
          ] else ...[
            // ── Barangay Administrators ──
            _buildAdminsSectionHeader(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSearchBar()),
                const SizedBox(width: 16),
                _buildFilterPills(),
              ],
            ),
            const SizedBox(height: 16),
            if (_filteredAdmins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No administrators found matching your search.',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                      ),
                    ],
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
        ElevatedButton.icon(
          onPressed: _showAddAdminModal,
          icon: const Icon(Icons.add, size: 14),
          label: Text(
            'Add Admin',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
        hintText: _selectedUserTypeTab == 1
            ? 'Search admins by name, email, or barangay...'
            : 'Search users by name, email, or barangay...',
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
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
    final filters = [
      _selectedUserTypeTab == 1 ? 'All Admins' : 'All Users',
      'Active',
      'Unverified',
      'Deactivated',
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _filterIndex;
          final activeColor = _selectedUserTypeTab == 1
              ? const Color(0xFF00796B)
              : AppColors.primary;
          final activeContainer = _selectedUserTypeTab == 1
              ? const Color(0xFF00796B).withOpacity(0.15)
              : AppColors.primaryContainer;

          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? activeContainer
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : AppColors.outlineVariant.withOpacity(0.2)),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: activeColor.withOpacity(0.25),
                            blurRadius: 8)
                      ]
                    : [],
              ),
              child: Text(
                filters[i],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.black
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
    return UserCard(
      user: user,
      isCompact: isCompact,
      onMenuPressed: () => _showUserMenu(name, user),
    );
  }

  void _showUserMenu(String name, Map<String, dynamic> user) {
    final rawStatus = (user['status'] ?? 'active').toString().toLowerCase();
    final isDeactivated = rawStatus == 'deactivated' || rawStatus == 'de_activated';

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
              onTap: () {
                Navigator.pop(context);
                _handleUserAction('view', user);
              },
            ),
            ListTile(
              leading: Icon(
                isDeactivated
                    ? Icons.check_circle_outline_rounded
                    : Icons.block_rounded,
                color: isDeactivated
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
              title: Text(
                isDeactivated ? 'Reactivate Account' : 'Deactivate Account',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDeactivated
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleUserAction('toggle_status', user);
              },
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
          AppConstants.buildLogoGraphic(size: 24),
          const SizedBox(width: 8),
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

  Widget? _buildFab() {
    if (_currentUserRole != UserRole.superAdmin) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: _showAddAdminModal,
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Admin',
            style: GoogleFonts.montserrat(
                fontSize: 13, fontWeight: FontWeight.w700)),
        elevation: 8,
        extendedIconLabelSpacing: 6,
      ),
    );
  }
}
