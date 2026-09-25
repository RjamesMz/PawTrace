import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/auth_service.dart';

/// Standalone Login screen for PawTrace.
///
/// On Web: Tailored for Super Admins and Barangay Admins accessing the admin portal.
/// Regular users attempting to sign in on Web are rejected and prompted to use mobile.
///
/// On Mobile: Used by pet owners, finders, and admins alike.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePwd = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final role = await AuthService.instance.signIn(email, password);
      if (!mounted) return;

      // Restrict Web portal to Administrators only
      if (kIsWeb && role == UserRole.user) {
        await AuthService.instance.signOut();
        _showError(
          'Access Denied: The web portal is restricted to Barangay Administrators and Super Administrators. Pet owners should use the mobile app.',
        );
        return;
      }

      // Clear stack and let AuthWrapper route to the correct screen
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } on AuthException catch (e) {
      _showError(AuthService.friendlyError(e));
    } catch (_) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 20,
                  vertical: isWide ? 40 : 20,
                ),
                child: isWide
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 36),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.outlineVariant.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _buildFormContent(),
                        ),
                      )
                    : _buildFormContent(),
              ),
            ),
          ),

          // Full-screen loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!kIsWeb) const SizedBox(height: 24),

        // ── Brand header ─────────────────────────────────────────
        _buildBrandHeader(),
        const SizedBox(height: 24),

        // ── Welcome headline ─────────────────────────────────────
        Text(
          kIsWeb ? 'Admin Portal' : 'Welcome Back',
          style: GoogleFonts.montserrat(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          kIsWeb
              ? 'Sign in with your administrative credentials'
              : 'Sign in to continue protecting your pets',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.secondary),
        ),
        const SizedBox(height: 28),

        // ── Email field ──────────────────────────────────────────
        _formField(
          controller: _emailCtrl,
          hint: 'Email Address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // ── Password field ───────────────────────────────────────
        _passwordField(
          controller: _passwordCtrl,
          hint: 'Password',
          obscure: _obscurePwd,
          onToggle: () => setState(() => _obscurePwd = !_obscurePwd),
        ),
        const SizedBox(height: 10),

        // ── Forgot password ──────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: Text(
              'Forgot password?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Login button ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: GoogleFonts.montserrat(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Login'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Register link (Only on mobile) ────────────────────────
        if (!kIsWeb)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.secondary),
              ),
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.register),
                child: Text(
                  'Register',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            'Admin accounts are managed by the Super Administrator.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        const SizedBox(height: 32),

        // ── Feature icons footer ─────────────────────────────────
        _buildFeatureFooter(),
        const SizedBox(height: 16),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PawTrace',
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'WEB',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.secondary.withOpacity(0.55),
        ),
        prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.secondary.withOpacity(0.55),
        ),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.secondary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.secondary,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildFeatureFooter() {
    const features = [
      (Icons.speed_rounded, 'FAST SEARCH'),
      (Icons.groups_rounded, 'COMMUNITY'),
      (Icons.share_location_rounded, 'LIVE GPS'),
    ];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              features.map((f) => _featureItem(f.$1, f.$2)).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          '© 2024 PawTrace Inc. Community-driven pet protection.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.secondary.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
              color: AppColors.surfaceContainer, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary.withOpacity(0.7),
          ),
        ),
      ]),
    );
  }
}
