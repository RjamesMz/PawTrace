import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_colors.dart';
import 'core/app_constants.dart';
import 'core/app_routes.dart';
import 'core/app_toast.dart';
import 'widgets/user/main_app_layout.dart';
import 'core/app_theme.dart';
import 'core/supabase_config.dart';

// Screens - Auth
import 'screens/auth/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/email_verified_screen.dart';

// Screens - User
import 'screens/user/locate_pet/locate_my_pet.dart';
import 'screens/user/my_pets/pet_profile_detail.dart';
import 'screens/user/lost_pet/report_lost_pet.dart';

// Screens - Admin
import 'screens/admin/user_management/user_management_screen.dart';
import 'screens/admin/pets/admin_pets_screen.dart';
import 'screens/admin/barangay_admin/barangay_admin_home_screen.dart';
import 'screens/admin/reports/admin_reports_screen.dart';
import 'screens/super_admin/super_admin_screen.dart';
import 'screens/admin/news/post_news_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase for pet database operations
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Clear image cache so updated logos/assets reload cleanly on hot restart
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();

  // Lock portrait orientation for mobile-first experience (not on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Set system UI overlay style to match PetTrace brand
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const PetTraceApp());
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Root application widget for PetTrace.
///
/// Configures [MaterialApp] with the PetTrace design system theme and
/// named routes for every screen in the application.
class PetTraceApp extends StatelessWidget {
  const PetTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: const [
              Breakpoint(start: 0, end: 599, name: MOBILE),
              Breakpoint(start: 600, end: 899, name: TABLET),
              Breakpoint(start: 900, end: double.infinity, name: DESKTOP),
            ],
          ),
        );
      },

      // AuthWrapper drives the entry point — it reads Firebase auth state
      // and Firestore role, then shows Login, Dashboard, or Admin screen.
      home: const AuthWrapper(),

      // Named routes for every screen (used by pushNamed throughout the app)
      routes: {
        // ─── Auth ─────────────────────────────────────────────────────────────
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),

        // ─── Main tabs (User & Admin via MainAppLayout) ──────────────────────
        AppRoutes.home: (_) => const MainAppLayout(initialIndex: 0),
        AppRoutes.lostPetScreen: (_) => const MainAppLayout(initialIndex: 0),
        AppRoutes.myPets: (_) => const MainAppLayout(initialIndex: 1),
        AppRoutes.aiScan: (_) => const MainAppLayout(initialIndex: 2),
        AppRoutes.profilePetRegistration: (_) => const MainAppLayout(initialIndex: 3),
        AppRoutes.settings: (_) => const MainAppLayout(initialIndex: 4),

        AppRoutes.barangayAdminHome: (_) => const BarangayAdminHomeScreen(),
        AppRoutes.superAdminHome: (_) => const SuperAdminScreen(),
        AppRoutes.adminPets: (_) => const AdminPetsScreen(),
        AppRoutes.adminReports: (_) => const AdminReportsScreen(),
        AppRoutes.userManagement: (_) => const UserManagementScreen(),

        // ─── Lost pet flow ────────────────────────────────────────────────────
        AppRoutes.reportLostPet: (_) => const ReportLostPetScreen(),
        '/report-lost': (_) => const ReportLostPetScreen(),

        // ─── Pet management ───────────────────────────────────────────────────
        AppRoutes.locateMyPet: (_) => const LocateMyPetScreen(),
        AppRoutes.petProfileDetail: (_) => const PetProfileDetailScreen(),

        // ─── Admin ────────────────────────────────────────────────────────────
        AppRoutes.postNews: (_) => const PostNewsScreen(),
        // ─── Verification & Deep Link Callbacks ──────────────────────────────
        AppRoutes.verified: (_) => const EmailVerifiedScreen(),
        AppRoutes.confirm: (_) => const EmailVerifiedScreen(),
        AppRoutes.authCallback: (_) => const EmailVerifiedScreen(),
        '/auth/v1/verify': (_) => const EmailVerifiedScreen(),
        '/verify': (_) => const EmailVerifiedScreen(),
      },

      // Handle dynamic paths, tokens, and verification deep links
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        final uri = Uri.tryParse(rawName);
        final path = uri?.path ?? '';

        if (path == '/verified' ||
            path == '/confirm' ||
            path.contains('verify') ||
            path.contains('callback') ||
            rawName.contains('access_token=') ||
            rawName.contains('type=signup') ||
            rawName.contains('type=recovery') ||
            rawName.contains('type=magiclink') ||
            rawName.contains('code=')) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const EmailVerifiedScreen(),
          );
        }
        return null;
      },

      // Fallback for unknown routes — safely redirects home or shows clean 404
      onUnknownRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) {
          if (Supabase.instance.client.auth.currentSession != null) {
            return const AuthWrapper();
          }
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        size: 38,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Page Not Found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The requested link or screen could not be found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => rootNavigatorKey.currentState
                          ?.pushNamedAndRemoveUntil('/', (route) => false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Return to Home / Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
