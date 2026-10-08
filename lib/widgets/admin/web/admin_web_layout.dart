import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../services/auth/auth_service.dart';
import '../../../widgets/common/notification_bell_button.dart';

/// Master desktop web layout widget for all PawTrace admin screens.
///
/// Displayed when screen width is on the DESKTOP breakpoint (>= 900px).
/// Features a permanent 240px dark sidebar (#1A1F36) on the left and an
/// Expanded main content area (#F5F5F5) with a 64px top bar and padded body.
class AdminWebLayout extends StatefulWidget {
  final int currentIndex;
  final Widget body;
  final String? pageTitle;

  const AdminWebLayout({
    super.key,
    required this.currentIndex,
    required this.body,
    this.pageTitle,
  });

  @override
  State<AdminWebLayout> createState() => _AdminWebLayoutState();
}

class _AdminWebLayoutState extends State<AdminWebLayout> {
  final _supabase = Supabase.instance.client;
  static bool _isSidebarCollapsed = false;

  String _adminName = 'Admin';
  UserRole _role = UserRole.admin;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    AuthService.instance.profileNotifier.addListener(_onProfileChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    AuthService.instance.profileNotifier.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    final profile = AuthService.instance.profileNotifier.value;
    if (profile != null && mounted) {
      setState(() {
        final first = profile['first_name']?.toString() ?? '';
        final surname = profile['surname']?.toString() ?? '';
        if (first.isNotEmpty) _adminName = '$first $surname'.trim();
        _photoUrl = profile['photo_url']?.toString();
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final role = await AuthService.instance.getCurrentUserRole();
      final profile = await AuthService.instance.getCurrentUserProfile();
      if (!mounted) return;
      String name = 'Admin';
      if (profile != null) {
        final first = profile['first_name']?.toString() ?? '';
        final surname = profile['surname']?.toString() ?? '';
        if (first.isNotEmpty) name = '$first $surname'.trim();
        _photoUrl = profile['photo_url']?.toString();
      }
      setState(() {
        _adminName = name;
        _role = role;
      });
    } catch (_) {}
  }

  String get _initial =>
      _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A';

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[now.weekday - 1];
    final mo = months[now.month - 1];
    return '$wd, $mo ${now.day}, ${now.year}';
  }

  String _resolveTitle() {
    if (widget.pageTitle != null && widget.pageTitle!.isNotEmpty) {
      return widget.pageTitle!;
    }
    switch (widget.currentIndex) {
      case 0:
        return _role == UserRole.superAdmin
            ? 'Super Admin Dashboard'
            : 'Barangay ';
      case 1:
        return 'All Pets';
      case 2:
        return 'Lost Reports';
      case 3:
        return 'User Management';
      case 4:
        return 'News & Announcements';
      case 5:
        return 'Admin Settings';
      default:
        return 'Admin Portal';
    }
  }

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    await AuthService.instance.signOut();
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _onNavSelected(int index) {
    if (index == widget.currentIndex) return;

    switch (index) {
      case 0:
        final route = _role == UserRole.superAdmin
            ? AppRoutes.superAdminHome
            : AppRoutes.barangayAdminHome;
        Navigator.pushReplacementNamed(context, route);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.adminPets);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.adminReports);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.userManagement);
        break;
      case 4:
        Navigator.pushReplacementNamed(context, AppRoutes.adminSettings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // ── Collapsable sidebar with #1A1F36 dark background ────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _isSidebarCollapsed ? 76 : 240,
            color: const Color(0xFF1A1F36),
            child: Column(
              children: [
                // Top header (height 70) with orange background
                Container(
                  height: 70,
                  width: double.infinity,
                  color: AppColors.primary, // #FF6600
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSidebarCollapsed ? 12 : 16,
                  ),
                  alignment: Alignment.center,
                  child: _isSidebarCollapsed
                      ? Tooltip(
                          message: AppConstants.appName,
                          child: InkWell(
                            onTap: () => setState(() => _isSidebarCollapsed = false),
                            child: AppConstants.buildLogoBadge(
                              size: 10,
                              backgroundColor: Colors.white,
                              iconColor: AppColors.primary,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            AppConstants.buildLogoBadge(
                              size: 10,
                              backgroundColor: Colors.white,
                              iconColor: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppConstants.appName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.menu_open_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: 'Collapse Sidebar',
                              onPressed: () =>
                                  setState(() => _isSidebarCollapsed = true),
                            ),
                          ],
                        ),
                ),

                // Admin Info section below header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSidebarCollapsed ? 8 : 16,
                    vertical: 14,
                  ),
                  child: _isSidebarCollapsed
                      ? Tooltip(
                          message:
                              '$_adminName\n${_role == UserRole.superAdmin ? 'Super Admin' : 'Barangay Admin'}',
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary,
                            backgroundImage:
                                _photoUrl != null && _photoUrl!.isNotEmpty
                                    ? NetworkImage(_photoUrl!)
                                    : null,
                            child: (_photoUrl == null || _photoUrl!.isEmpty)
                                ? Text(
                                    _initial,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary,
                              backgroundImage:
                                  _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? NetworkImage(_photoUrl!)
                                      : null,
                              child: (_photoUrl == null || _photoUrl!.isEmpty)
                                  ? Text(
                                      _initial,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _adminName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _role == UserRole.superAdmin
                                        ? 'Super Admin'
                                        : 'Barangay Admin',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF8B93A7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x22FFFFFF),
                ),
                const SizedBox(height: 10),

                // ListView of NavigationItem widgets
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _NavigationItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isSelected: widget.currentIndex == 0,
                        isCollapsed: _isSidebarCollapsed,
                        onTap: () => _onNavSelected(0),
                      ),
                      _NavigationItem(
                        icon: Icons.pets_rounded,
                        label: 'Pets',
                        isSelected: widget.currentIndex == 1,
                        isCollapsed: _isSidebarCollapsed,
                        onTap: () => _onNavSelected(1),
                      ),
                      _NavigationItem(
                        icon: Icons.flag_rounded,
                        label: 'Reports',
                        isSelected: widget.currentIndex == 2,
                        isCollapsed: _isSidebarCollapsed,
                        onTap: () => _onNavSelected(2),
                      ),
                      _NavigationItem(
                        icon: Icons.group_rounded,
                        label: 'Users',
                        isSelected: widget.currentIndex == 3,
                        isCollapsed: _isSidebarCollapsed,
                        onTap: () => _onNavSelected(3),
                      ),
                      _NavigationItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isSelected: widget.currentIndex == 4,
                        isCollapsed: _isSidebarCollapsed,
                        onTap: () => _onNavSelected(4),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x22FFFFFF),
                ),

                // Bottom actions: Collapse toggle + Logout
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _isSidebarCollapsed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Expand Sidebar',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: Color(0xFF8B93A7),
                                  size: 22,
                                ),
                                onPressed: () =>
                                    setState(() => _isSidebarCollapsed = false),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Tooltip(
                              message: 'Logout',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFE57373),
                                  size: 22,
                                ),
                                onPressed: _logout,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 0),
                              leading: const Icon(
                                Icons.keyboard_double_arrow_left_rounded,
                                color: Color(0xFF8B93A7),
                                size: 22,
                              ),
                              title: Text(
                                'Collapse Sidebar',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8B93A7),
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hoverColor: Colors.white.withOpacity(0.06),
                              onTap: () =>
                                  setState(() => _isSidebarCollapsed = true),
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 0),
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFE57373),
                                size: 22,
                              ),
                              title: Text(
                                'Logout',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE57373),
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hoverColor: Colors.white.withOpacity(0.06),
                              onTap: _logout,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // ── Expanded main content area with #F5F5F5 light gray background ─
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: Column(
                children: [
                  // Top bar: Container height 64 white background soft bottom shadow
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Toggle sidebar button in top bar
                        IconButton(
                          icon: Icon(
                            _isSidebarCollapsed
                                ? Icons.menu_rounded
                                : Icons.menu_open_rounded,
                            color: AppColors.onSurface,
                            size: 24,
                          ),
                          tooltip: _isSidebarCollapsed
                              ? 'Expand Sidebar'
                              : 'Collapse Sidebar',
                          onPressed: () {
                            setState(() {
                              _isSidebarCollapsed = !_isSidebarCollapsed;
                            });
                          },
                        ),
                        const SizedBox(width: 8),

                        // Current page title in Montserrat bold 20sp
                        Text(
                          _resolveTitle(),
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Spacer(),

                        // Formatted date text gray
                        Text(
                          _formattedDate(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 18),

                        const NotificationBellButton(size: 22),
                        const SizedBox(width: 8),

                        // Admin name with CircleAvatar
                        // Admin name with CircleAvatar (clickable to navigate to settings)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _onNavSelected(5),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _adminName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  backgroundImage:
                                      _photoUrl != null && _photoUrl!.isNotEmpty
                                          ? NetworkImage(_photoUrl!)
                                          : null,
                                  child:
                                      (_photoUrl == null || _photoUrl!.isEmpty)
                                          ? Text(
                                              _initial,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body parameter with optimized compact desktop padding
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: widget.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation item widget used inside AdminWebLayout sidebar.
class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isCollapsed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary; // #FF6600 orange
    const inactiveColor = Color(0xFF8B93A7);

    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: Material(
            color: isSelected
                ? activeColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              hoverColor: Colors.white.withOpacity(0.06),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: activeColor.withOpacity(0.3), width: 1)
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? activeColor : inactiveColor,
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : Colors.white70,
          ),
        ),
        selected: isSelected,
        selectedColor: activeColor,
        selectedTileColor: activeColor.withOpacity(0.10), // 10 percent opacity
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onTap,
      ),
    );
  }
}
