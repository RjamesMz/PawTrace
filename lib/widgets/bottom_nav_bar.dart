import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../services/auth_service.dart';

/// Reusable BottomNavBar shared across all main screens.
///
/// Items for User: Home (house), Lost (search), Scan (camera – centered elevated on
/// orange circle), Register (badge), Settings (gear).
///
/// Items for Admin: Home (house), Lost (search), Scan (camera – centered elevated on
/// orange circle), Register (badge), Admin (shield).
///
/// Active item color: #FF6600 / [AppColors.orange].
/// Inactive item color: gray [Colors.grey].
class BottomNavBar extends StatefulWidget {
  /// Index of the currently active tab (0–4).
  final int currentIndex;
  
  /// Optional callback for tab selection. If provided, BottomNavBar will NOT
  /// perform navigation, and will instead just call this function.
  final void Function(int)? onTabSelected;

  const BottomNavBar({super.key, required this.currentIndex, this.onTabSelected});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  // Role is fetched once and cached — prevents FutureBuilder from re-firing
  // on every rebuild which caused the nav bar to flicker/refresh on each tap.
  UserRole? _cachedRole;

  static const List<_NavItem> _userItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home', route: AppRoutes.home),
    _NavItem(
        icon: Icons.search_rounded,
        label: 'Lost',
        route: AppRoutes.lostPetDetails),
    _NavItem(
        icon: Icons.camera_alt_rounded, label: 'Scan', route: AppRoutes.aiScan),
    _NavItem(
        icon: Icons.app_registration_rounded,
        label: 'Register',
        route: AppRoutes.profilePetRegistration),
    _NavItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        route: AppRoutes.settings),
  ];

  static const List<_NavItem> _adminItems = [
    _NavItem(
        icon: Icons.home_rounded,
        label: 'Home',
        route: AppRoutes.barangayAdminHome),
    _NavItem(
        icon: Icons.pets_rounded, label: 'Pets', route: AppRoutes.adminPets),
    _NavItem(
        icon: Icons.description_rounded,
        label: 'Reports',
        route: AppRoutes.adminReports),
    _NavItem(
        icon: Icons.group_rounded,
        label: 'Users',
        route: AppRoutes.userManagement),
    _NavItem(
        icon: Icons.person_rounded,
        label: 'Account',
        route: AppRoutes.settings),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService.instance.getCurrentUserRole();
    if (mounted) {
      setState(() => _cachedRole = role);
    }
  }

  List<_NavItem> get _items {
    final role = _cachedRole ?? UserRole.user;
    if (role == UserRole.superAdmin) {
      return [
        const _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            route: AppRoutes.superAdminHome),
        ..._adminItems.sublist(1),
      ];
    } else if (role == UserRole.admin) {
      return _adminItems;
    } else {
      return _userItems;
    }
  }

  void _onTap(BuildContext context, int index, int activeIndex) {
    if (index == activeIndex) return;
    
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }

    final route = _items[index].route;
    if (route.isNotEmpty) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    int activeIndex = widget.currentIndex;
    if (currentRoute != null) {
      final foundIndex = items.indexWhere((item) => item.route == currentRoute);
      if (foundIndex != -1) activeIndex = foundIndex;
    }

    // While role is loading, render a sized placeholder so layout doesn't shift.
    if (_cachedRole == null) {
      return const SizedBox(height: 72);
    }

    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background bar
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.95),
                border: Border(
                    top: BorderSide(
                        color: AppColors.outlineVariant.withOpacity(0.3))),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: List.generate(
                items.length,
                (i) => Expanded(
                  child: Center(
                    child: _buildItem(context, i, items, activeIndex),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
      BuildContext context, int i, List<_NavItem> items, int activeIndex) {
    final item = items[i];
    final isActive = i == activeIndex;

    // Center Scan item: elevated orange circle (user nav only)
    if (i == 2 && items == _userItems) {
      return GestureDetector(
        onTap: () => _onTap(context, i, activeIndex),
        child: SizedBox(
          width: 64,
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Elevated circle — raised above the bar
              Positioned(
                bottom: 14,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.orange.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 26),
                ),
              ),
              // Label at the very bottom of the bar
              Positioned(
                bottom: 4,
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.orange : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Regular item
    return GestureDetector(
      onTap: () => _onTap(context, i, activeIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon,
                color: isActive ? AppColors.orange : Colors.grey, size: 24),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: isActive ? AppColors.orange : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon, required this.label, required this.route});
}
