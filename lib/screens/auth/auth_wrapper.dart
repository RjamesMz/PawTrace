import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../core/app_colors.dart';
import 'login_screen.dart';
import '../../widgets/main_app_layout.dart';
import '../admin/barangay_admin_home_screen.dart';
import '../admin/super_admin_screen.dart';

/// Listens to Supabase auth state and redirects to the correct screen.
///
/// - Not signed in                  → [LoginScreen]
/// - Signed in, role = "superAdmin" → [SuperAdminScreen]
/// - Signed in, role = "admin"      → [BarangayAdminHomeScreen]
/// - Signed in, role = "user":
///   - On Web                       → [_WebAccessDeniedScreen]
///   - On Mobile                    → [DashboardHomeScreen]
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

            final role = roleSnap.data ?? UserRole.user;

            if (role == UserRole.superAdmin) {
              return const SuperAdminScreen();
            }
            if (role == UserRole.admin) {
              return const BarangayAdminHomeScreen();
            }

            // Regular user (owner/finder) on Web platform is restricted
            if (kIsWeb) {
              return const _WebAccessDeniedScreen();
            }

            return const MainAppLayout(initialIndex: 0);
          },
        );
      },
    );
  }
}

/// Screen shown when a regular mobile user logs into the Web platform.
class _WebAccessDeniedScreen extends StatelessWidget {
  const _WebAccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: AppColors.error, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Administrator Portal Only',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The PawTrace Web Portal is restricted to Barangay Administrators and Super Administrators.\n\nPet owners and finders should use the PawTrace Mobile App.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService.instance.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out & Return to Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
