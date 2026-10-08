import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/common/change_password_dialog.dart';

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
  String? _flashMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_flashMessage == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args['flashMessage'] != null) {
          _flashMessage = args['flashMessage'].toString();
        }
        if (args['flashEmail'] != null && _emailCtrl.text.isEmpty) {
          _emailCtrl.text = args['flashEmail'].toString();
        }
      }
    }
  }

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

  void _handleForgotPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      ChangePasswordDialog.show(context, email: email);
    } else {
      final ctrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Reset Password',
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your registered email address to receive a password reset link.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final entered = ctrl.text.trim();
                if (entered.isEmpty || !entered.contains('@')) {
                  AppToast.error(
                      context, 'Please enter a valid email address.');
                  return;
                }
                Navigator.pop(ctx);
                ChangePasswordDialog.show(context, email: entered);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFlashMessageBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: Color(0xFF1D4ED8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify Your Email',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.4,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tip: Check your Spam or Junk folder if you do not see it in your inbox.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _flashMessage = null),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: isWide
                  ? _buildWebLayout()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      child: _buildFormContent(),
                    ),
            ),
          ),

          // Loading overlay — mobile only (web uses inline indicator on card)
          if (_isLoading && !isWide)
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

  // ─── Web Split-Card Layout ─────────────────────────────────────────────────

  Widget _buildWebLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 560),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 60,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ── Left decorative panel ─────────────────────────────
                  Expanded(
                    flex: 5,
                    child: _buildWebLeftPanel(),
                  ),
                  // ── Right form panel ──────────────────────────────────
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(40, 36, 40, 36),
                      child: _buildWebFormPanel(),
                    ),
                  ),
                ],
              ),
            ),
            // Slim loading bar at the top of the card
            if (_isLoading)
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: AppColors.primary,
                    minHeight: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLeftPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6600),
              Color(0xFFFF8C00),
              Color(0xFFE55A00),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand name top-left
                  Row(
                    children: [
                      Text(
                        AppConstants.appName,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'ADMIN',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Center illustration area
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App logo badge
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.20),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Image.asset(
                              AppConstants.logoAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Bottom caption
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Admin Dashboard',
                        style: GoogleFonts.montserrat(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage pets, reports & community\nsafety from one place.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.75),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFormPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading
        Text(
          'Welcome to ${AppConstants.appName} Admin',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your Admin Dashboard',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 28),

        // Flash message
        if (_flashMessage != null) ...[
          _buildFlashMessageBanner(_flashMessage!),
          const SizedBox(height: 20),
        ],

        // Email label + field
        Text(
          'Email Address',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        _webInputField(
          controller: _emailCtrl,
          hint: 'admin@pettrace.ph',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),

        // Password label + field
        Text(
          'Password',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        _webPasswordField(),
        const SizedBox(height: 10),

        // Forgot password row
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _handleForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Sign In button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.montserrat(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Sign In'),
          ),
        ),
        const SizedBox(height: 20),

        // Footer note
        Center(
          child: Text(
            'Admin accounts are managed by the Super Administrator.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _webInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: const Color(0xFFCBD5E1)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 19),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _webPasswordField() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: _obscurePwd,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: const Color(0xFFCBD5E1)),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF94A3B8), size: 19),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePwd
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFF94A3B8),
            size: 19,
          ),
          onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
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
        if (_flashMessage != null) ...[
          const SizedBox(height: 20),
          _buildFlashMessageBanner(_flashMessage!),
        ] else ...[
          const SizedBox(height: 28),
        ],

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
            onPressed: _handleForgotPassword,
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
                style:
                    GoogleFonts.inter(fontSize: 14, color: AppColors.secondary),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.register),
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
        AppConstants.buildLogoGraphic(
          size: 80,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConstants.appName,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          children: features.map((f) => _featureItem(f.$1, f.$2)).toList(),
        ),
        const SizedBox(height: 16),
        // ── Legal & Policies Links ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.privacyPolicy),
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '•',
                style: TextStyle(
                  color: AppColors.secondary.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.termsOfService),
              child: Text(
                'Terms & Conditions',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '© 2026 ${AppConstants.appName}. Community-driven pet protection.',
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
