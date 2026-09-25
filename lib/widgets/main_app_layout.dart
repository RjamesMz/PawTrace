import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../services/pet_embedding_service.dart';
import 'bottom_nav_bar.dart';

// User Screens
import '../screens/user/dashboard_home.dart';
import '../screens/user/lost_pet_details.dart';
import '../screens/user/ai_scan.dart';
import '../screens/user/profile_pet_registration.dart';
import '../screens/user/settings_screen.dart';

/// Single-page wrapper for the User app. (User and Admin).
/// Keeps screens alive in an IndexedStack so navigating 
/// between them via the BottomNavBar is instant.
class MainAppLayout extends StatefulWidget {
  final int initialIndex;
  
  const MainAppLayout({super.key, this.initialIndex = 0});

  @override
  State<MainAppLayout> createState() => _MainAppLayoutState();
}

class _MainAppLayoutState extends State<MainAppLayout> {
  late int _currentIndex;

  /// Guards the silent background re-embed so it runs at most once per
  /// app session (not every time MainAppLayout rebuilds or a user switches
  /// tabs). Set to true after the first successful schedule.
  static bool _reEmbedScheduled = false;

  final List<Widget> _userScreens = [
    const DashboardHomeScreen(),
    const LostPetDetailsScreen(),
    const AiScanScreen(),
    const ProfilePetRegistrationScreen(),
    const SettingsScreen(showBottomNav: false),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _scheduleBackgroundReEmbed();
  }

  /// Silently re-embeds all pets in the background using the improved
  /// temperature-softmax embedding method.
  ///
  /// - Runs **at most once per app session** (guarded by [_reEmbedScheduled]).
  /// - Web is skipped automatically (TFLite unavailable on web).
  /// - All errors are swallowed — this must never crash the app.
  void _scheduleBackgroundReEmbed() {
    if (_reEmbedScheduled) return;          // already scheduled this session
    if (kIsWeb) return;                     // TFLite not available on web

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;             // not logged in

    _reEmbedScheduled = true;

    // Fire-and-forget: runs entirely in the background.
    // unawaited so the UI is never blocked.
    Future(() async {
      try {
        debugPrint('[PawTrace] Background re-embed: starting...');
        final count = await PetEmbeddingService.instance.reEmbedAllPets(
          onProgress: (done, total) {
            debugPrint('[PawTrace] Re-embed progress: $done/$total');
          },
        );
        debugPrint('[PawTrace] Background re-embed complete: $count pets updated.');
      } catch (e) {
        // Swallow all errors — this is a best-effort background task.
        debugPrint('[PawTrace] Background re-embed error (non-fatal): $e');
      }
    });
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _userScreens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

