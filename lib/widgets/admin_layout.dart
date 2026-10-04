import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../core/app_routes.dart';
import '../services/auth_service.dart';
import 'admin_sidebar.dart';
import 'bottom_nav_bar.dart';
import 'notification_bell_button.dart';

/// Responsive layout wrapper for all admin screens.
///
/// **Mobile (< 800 px):** renders [child] directly above the existing
/// [BottomNavBar] — identical to the current mobile experience.
///
/// **Web (≥ 800 px):** renders a `Row` with [AdminSidebar] on the left
/// and an `Expanded` column on the right containing a 64-px top bar and
/// the scrollable [child].
///
/// Parameters:
/// - [currentIndex] — Active sidebar/bottom-nav index
/// - [child]        — The screen's main content widget
/// - [pageTitle]    — Title shown in the web top bar
class AdminLayout extends StatefulWidget {
  final int currentIndex;
  final Widget child;
  final String pageTitle;
  final UserRole? role;

  const AdminLayout({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.pageTitle,
    this.role,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  String _adminName = 'Admin';
  String? _photoUrl;
  UserRole _role = UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (widget.role != null) {
      _role = widget.role!;
    }
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        if (!isWide) {
          return _buildMobileLayout();
        }
        return _buildWebLayout();
      },
    );
  }

  // ─── Mobile Layout ────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return SafeArea(
      bottom: false, // BottomNavBar handles its own bottom insets
      child: Column(
        children: [
          Expanded(child: widget.child),
          BottomNavBar(currentIndex: widget.currentIndex),
        ],
      ),
    );
  }

  // ─── Web Layout ───────────────────────────────────────────────────────────

  Widget _buildWebLayout() {
    return Row(
      children: [
        // Sidebar
        AdminSidebar(
          currentIndex: widget.currentIndex,
          adminName: _adminName,
          role: _role,
          photoUrl: _photoUrl,
        ),
        // Main content area
        Expanded(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: widget.child,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AppConstants.buildLogoGraphic(size: 26),
          const SizedBox(width: 10),
          // Page title
          Text(
            widget.pageTitle,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const Spacer(),
          // Date
          Text(
            _formattedDate(),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          const NotificationBellButton(size: 22),
          const SizedBox(width: 8),
          // Admin avatar
          InkWell(
            onTap: () {
              if (widget.currentIndex != 5) {
                Navigator.pushReplacementNamed(context, AppRoutes.adminSettings);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? NetworkImage(_photoUrl!)
                  : null,
              child: (_photoUrl == null || _photoUrl!.isEmpty)
                  ? Text(
                      _initial,
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
}
