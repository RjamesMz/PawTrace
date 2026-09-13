import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'core/supabase_config.dart';

// Screens - Auth
import 'screens/auth/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

// Screens - User
import 'screens/user/dashboard_home.dart';
import 'screens/user/lost_pet_details.dart';
import 'screens/user/ai_scan.dart';
import 'screens/user/locate_my_pet.dart';
import 'screens/user/pet_profile_detail.dart';
import 'screens/user/profile_pet_registration.dart';
import 'screens/user/report_lost_pet.dart';
import 'screens/user/settings_screen.dart';
import 'screens/user/my_pets_screen.dart';

// Screens - Admin
import 'screens/admin/user_management.dart';
import 'screens/admin/admin_pets_screen.dart';
import 'screens/admin/post_news_screen.dart';
import 'screens/admin/barangay_admin_home_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/super_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase for pet database operations
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Lock portrait orientation for mobile-first experience (not on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Set system UI overlay style to match PawTrace brand
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const PawTraceApp());
}

/// Root application widget for PawTrace.
///
/// Configures [MaterialApp] with the PawTrace design system theme and
/// named routes for every screen in the application.
class PawTraceApp extends StatelessWidget {
  const PawTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawTrace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 599, name: MOBILE),
          Breakpoint(start: 600, end: 899, name: TABLET),
          Breakpoint(start: 900, end: double.infinity, name: DESKTOP),
        ],
      ),

      // AuthWrapper drives the entry point — it reads Firebase auth state
      // and Firestore role, then shows Login, Dashboard, or Admin screen.
      home: const AuthWrapper(),

      // Named routes for every screen (used by pushNamed throughout the app)
      routes: {
        // ─── Auth ─────────────────────────────────────────────────────────────
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),

        // ─── Main tabs ────────────────────────────────────────────────────────
        AppRoutes.home: (_) => const DashboardHomeScreen(),
        AppRoutes.aiScan: (_) => const AiScanScreen(),

        // ─── Lost pet flow ────────────────────────────────────────────────────
        AppRoutes.lostPetDetails: (_) => const LostPetDetailsScreen(),
        AppRoutes.reportLostPet: (_) => const ReportLostPetScreen(),

        // ─── Pet management ───────────────────────────────────────────────────
        AppRoutes.locateMyPet: (_) => const LocateMyPetScreen(),
        AppRoutes.petProfileDetail: (_) => const PetProfileDetailScreen(),
        AppRoutes.profilePetRegistration: (_) => const ProfilePetRegistrationScreen(),

        // ─── Admin ────────────────────────────────────────────────────────────
        AppRoutes.userManagement: (_) => const UserManagementScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.myPets: (_) => const MyPetsScreen(),
        AppRoutes.adminPets: (_) => const AdminPetsScreen(),
        AppRoutes.postNews: (_) => const PostNewsScreen(),
        AppRoutes.barangayAdminHome: (_) => const BarangayAdminHomeScreen(),
        AppRoutes.adminReports: (_) => const AdminReportsScreen(),
        AppRoutes.superAdminHome: (_) => const SuperAdminScreen(),
      },

      // Fallback for unknown routes
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Page not found', style: TextStyle(fontSize: 18))),
        ),
      ),
    );
  }
}
