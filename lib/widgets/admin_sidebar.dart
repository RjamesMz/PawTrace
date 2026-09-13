import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../services/auth_service.dart';

/// Reusable sidebar navigation widget for Flutter Web (≥800 px).
///
/// Renders a 260 px wide dark panel (`#1A1F36`) with:
/// - PawTrace branding logo at the top
/// - Admin avatar + name / role label
/// - Role-aware navigation links
/// - Logout button pinned to the bottom
///
/// Parameters:
/// - [currentIndex] — 0-based index of the active nav item (sidebar-relative)
/// - [adminName]    — Full name of the signed-in admin
/// - [role]         — `UserRole` used to conditionally show "Barangay Admins"
class AdminSidebar extends StatefulWidget {
  final int currentIndex;
  final String adminName;
  final UserRole role;

  const AdminSidebar({
    super.key,
    required this.currentIndex,
    required this.adminName,
    required this.role,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  // Track hover state per item index
  final Map<int, bool> _hovered = {};

  static const Color _sidebarBg = Color(0xFF1A1F36);
  static const Color _activeColor = AppColors.primary; // #FF6600
  static const Color _inactiveColor = Color(0xFF8B93A7);
  static const Color _hoverBg = Color(0x0FFFFFFF); // white 6%
  static const Color _activeBorderColor = AppColors.primary;

  /// Returns the list of visible nav items based on the admin's role.
  List<_SidebarItem> _buildItems() {
    final dashboardRoute = widget.role == UserRole.superAdmin
        ? AppRoutes.superAdminHome
        : AppRoutes.barangayAdminHome;

    final items = <_SidebarItem>[
      _SidebarItem(
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
        route: dashboardRoute,
      ),
      const _SidebarItem(
        icon: Icons.pets_rounded,
        label: 'Pets',
        route: AppRoutes.adminPets,
      ),
      const _SidebarItem(
        icon: Icons.flag_rounded,
        label: 'Reports',
        route: AppRoutes.adminReports,
      ),
      const _SidebarItem(
        icon: Icons.group_rounded,
        label: 'Users',
        route: AppRoutes.userManagement,
      ),
      const _SidebarItem(
        icon: Icons.campaign_rounded,
        label: 'News',
        route: AppRoutes.postNews,
      ),
    ];
    return items;
  }

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    await AuthService.instance.signOut();
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final roleLabel = widget.role == UserRole.superAdmin
        ? 'Super Admin'
        : 'Barangay Admin';
    final initial =
        widget.adminName.isNotEmpty ? widget.adminName[0].toUpperCase() : 'A';

    return Container(
      width: 260,
      color: _sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets, color: Colors.white, size: 22),
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
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Admin Avatar + Role ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.85),
                    child: Text(
                      initial,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.adminName,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _inactiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Divider ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Colors.white.withOpacity(0.08),
              height: 1,
            ),
          ),

          const SizedBox(height: 12),

          // ── Nav Label ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'NAVIGATION',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: _inactiveColor.withOpacity(0.6),
              ),
            ),
          ),

          // ── Nav Items ─────────────────────────────────────────────────────
          ...List.generate(items.length, (i) => _buildNavItem(items, i)),

          const Spacer(),

          // ── Divider ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: Colors.white.withOpacity(0.08),
              height: 1,
            ),
          ),

          // ── Logout ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: _buildLogoutButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(List<_SidebarItem> items, int i) {
    final item = items[i];
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isActive = (currentRoute != null && currentRoute.isNotEmpty)
        ? (currentRoute == item.route)
        : (i == widget.currentIndex);
    final isHovered = _hovered[i] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered[i] = true),
        onExit: (_) => setState(() => _hovered[i] = false),
        child: GestureDetector(
          onTap: () {
            if (!isActive) {
              Navigator.pushReplacementNamed(context, item.route);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.12)
                  : isHovered
                      ? _hoverBg
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? const Border(
                      left: BorderSide(
                        color: _activeBorderColor,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(isActive ? 13 : 16, 10, 16, 10),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 20,
                    color: isActive ? _activeColor : _inactiveColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? _activeColor : _inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    final isHovered = _hovered[-1] == true;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered[-1] = true),
      onExit: (_) => setState(() => _hovered[-1] = false),
      child: GestureDetector(
        onTap: _logout,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isHovered
                ? AppColors.error.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 20,
                color: Color(0xFFE57373),
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE57373),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
