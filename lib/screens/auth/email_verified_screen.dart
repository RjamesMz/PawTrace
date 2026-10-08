import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../widgets/common/change_password_dialog.dart';

/// Screen displayed when an email confirmation or password reset link redirects to the app.
class EmailVerifiedScreen extends StatefulWidget {
  const EmailVerifiedScreen({super.key});

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  bool _isRecovery = false;
  String? _userEmail;
  Timer? _autoRedirectTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _autoRedirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    // Check if recovery in web URI or deep link
    final uri = Uri.base;
    final fragment = uri.fragment;
    final query = uri.query;
    final fullUrl = '$query&$fragment';

    if (fullUrl.contains('type=recovery')) {
      if (mounted) {
        setState(() {
          _isRecovery = true;
        });
      }
      return;
    }

    // Wait a brief moment for Supabase Auth to establish the session from tokens
    await Future.delayed(const Duration(milliseconds: 500));

    final user = Supabase.instance.client.auth.currentUser;
    if (mounted) {
      setState(() {
        _userEmail = user?.email;
      });

      // If user is already authenticated, automatically continue after 2.5s
      if (user != null) {
        _autoRedirectTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) _goToApp();
        });
      }
    }
  }

  void _goToApp() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _goToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
      arguments: _userEmail != null ? {'flashEmail': _userEmail} : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecovery) {
      final userEmail =
          _userEmail ?? Supabase.instance.client.auth.currentUser?.email ?? '';
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ChangePasswordDialog(
              email: userEmail,
              startAtNewPassword: true,
              onSuccess: () {
                _goToApp();
              },
            ),
          ),
        ),
      );
    }

    final hasUser = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Community Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      '🐾 PETTRACE COMMUNITY',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Success Animated Check Icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFA7F3D0),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Headline
                  Text(
                    'Email Verified!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    _userEmail != null && _userEmail!.isNotEmpty
                        ? 'Your email ($_userEmail) has been successfully verified. Your PetTrace account is now active.'
                        : 'Your email has been successfully verified! Your PetTrace account is now active and ready to keep pets safe.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.55,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: hasUser ? _goToApp : _goToLogin,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        hasUser ? 'Continue to App' : 'Sign In Now',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Footer Note
                  Text(
                    hasUser
                        ? 'Redirecting automatically in a moment...'
                        : 'You can now sign in using your verified email and password.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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
}
