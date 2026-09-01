import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../core/app_colors.dart';
import 'login_screen.dart';
import '../user/dashboard_home.dart';
import '../admin/barangay_admin_home_screen.dart';
import '../admin/super_admin_screen.dart';

/// Listens to Supabase auth state and redirects to the correct screen.
///
/// - Not signed in              → [LoginScreen]
/// - Signed in, role = "admin"  → [UserManagementScreen]
/// - Signed in, role = "user"   → [DashboardHomeScreen]
///
/// This widget is the [MaterialApp] home, replacing a static `initialRoute`.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.onAuthStateChange,
      builder: (context, snapshot) {
        // ── Still waiting for the first auth event ──────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }

        // ── Check current session ───────────────────────────────────────────
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }

        // ── Signed in – resolve role from users table ───────────────────────
        return FutureBuilder<UserRole>(
          future: AuthService.instance.getCurrentUserRole(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const _SplashLoader();
            }
            if (roleSnap.data == UserRole.superAdmin) {
              return const SuperAdminScreen();
            }
            if (roleSnap.data == UserRole.admin) {
              return const BarangayAdminHomeScreen();
            }
            return const DashboardHomeScreen();
          },
        );
      },
    );
  }
}

/// Full-screen loader shown while auth / role state is being resolved.
class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: AppColors.onPrimaryContainer, size: 40),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}
