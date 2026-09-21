import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/notification_bell_button.dart';

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

  String _adminName = 'Admin';
  UserRole _role = UserRole.admin;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
            : 'Barangay Dashboard';
      case 1:
        return 'All Pets';
      case 2:
        return 'Lost Reports';
      case 3:
        return 'User Management';
      case 4:
        return 'News & Announcements';
      case 5:
        return 'Barangay Admins';
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
        Navigator.pushReplacementNamed(context, AppRoutes.postNews);
        break;
      case 5:
        Navigator.pushReplacementNamed(context, AppRoutes.userManagement);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // ── Fixed width 240px sidebar with #1A1F36 dark background ────────
          Container(
            width: 240,
            color: const Color(0xFF1A1F36),
            child: Column(
              children: [
                // Top header (height 70) with orange background
                Container(
                  height: 70,
                  width: double.infinity,
                  color: AppColors.primary, // #FF6600
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pets_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PawTrace',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Admin Info section below header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          _initial,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
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
                        onTap: () => _onNavSelected(0),
                      ),
                      _NavigationItem(
                        icon: Icons.pets_rounded,
                        label: 'Pets',
                        isSelected: widget.currentIndex == 1,
                        onTap: () => _onNavSelected(1),
                      ),
                      _NavigationItem(
                        icon: Icons.flag_rounded,
                        label: 'Reports',
                        isSelected: widget.currentIndex == 2,
                        onTap: () => _onNavSelected(2),
                      ),
                      _NavigationItem(
                        icon: Icons.group_rounded,
                        label: 'Users',
                        isSelected: widget.currentIndex == 3,
                        onTap: () => _onNavSelected(3),
                      ),
                      _NavigationItem(
                        icon: Icons.campaign_rounded,
                        label: 'News Posts',
                        isSelected: widget.currentIndex == 4,
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

                // Bottom Logout ListTile
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                        Row(
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
                              child: Text(
                                _initial,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Body parameter wrapped in SingleChildScrollView with padding 24
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
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
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary; // #FF6600 orange
    final inactiveColor = const Color(0xFF8B93A7);

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
