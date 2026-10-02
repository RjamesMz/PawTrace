import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../core/app_toast.dart';
import '../services/auth_service.dart';

enum _PasswordStep {
  requestLink,
  linkSent,
  setNewPassword,
  success,
}

/// A modern Change Password dialog utilizing Supabase Email verification link.
///
/// Flow:
/// 1. Request password reset email link.
/// 2. Display confirmation and waiting screen with resend timer.
/// 3. When link is clicked, enter and validate new password.
/// 4. Success confirmation.
class ChangePasswordDialog extends StatefulWidget {
  final String email;
  final bool startAtNewPassword;
  final VoidCallback? onSuccess;

  const ChangePasswordDialog({
    super.key,
    required this.email,
    this.startAtNewPassword = false,
    this.onSuccess,
  });

  /// Static helper to launch the dialog easily from any screen.
  static Future<bool?> show(
    BuildContext context, {
    required String email,
    bool startAtNewPassword = false,
    VoidCallback? onSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChangePasswordDialog(
        email: email,
        startAtNewPassword: startAtNewPassword,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _supabase = Supabase.instance.client;

  late _PasswordStep _step;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Cooldown State ────────────────────────────────────────────────────────
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  // ── Password State ────────────────────────────────────────────────────────
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _step = widget.startAtNewPassword
        ? _PasswordStep.setNewPassword
        : _PasswordStep.requestLink;

    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery ||
          (event == AuthChangeEvent.signedIn && _step == _PasswordStep.linkSent)) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
            _step = _PasswordStep.setNewPassword;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Helper: Mask Email for display ────────────────────────────────────────
  String _maskedEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '$name***@$domain';
    }
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  // ── Step 1: Send Reset Link ───────────────────────────────────────────────
  Future<void> _handleSendLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.resetPasswordForEmail(widget.email);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = _PasswordStep.linkSent;
        _startCooldownTimer();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppErrors.format(
          e,
          fallback: 'Failed to send reset link. Please try again.',
        );
      });
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown > 1) {
        setState(() => _resendCooldown--);
      } else {
        t.cancel();
        setState(() => _resendCooldown = 0);
      }
    });
  }

  // ── Step 3: Update Password ───────────────────────────────────────────────
  Future<void> _handleUpdatePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    final validationErr = AuthService.validatePassword(newPass);
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = _PasswordStep.success;
      });

      // Automatically close and show toast after success
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
        AppToast.success(context, 'Password changed successfully!');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppErrors.format(
          e,
          fallback: 'Failed to update password. Please try again.',
        );
      });
    }
  }

  // ─── UI BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 16),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCurrentStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header Widget ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    IconData icon;
    Color iconColor;
    Color bgColor;
    String title;

    switch (_step) {
      case _PasswordStep.requestLink:
        icon = Icons.lock_reset_rounded;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.12);
        title = 'Change Password';
        break;
      case _PasswordStep.linkSent:
        icon = Icons.mark_email_read_rounded;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.12);
        title = 'Check Your Email';
        break;
      case _PasswordStep.setNewPassword:
        icon = Icons.lock_outline_rounded;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.12);
        title = 'Set New Password';
        break;
      case _PasswordStep.success:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.secondary;
        bgColor = AppColors.secondaryContainer.withOpacity(0.4);
        title = 'Password Changed';
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            if (!_isLoading && _step != _PasswordStep.success)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
                color: AppColors.onSurfaceVariant,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Content Router ──────────────────────────────────────────────────

  Widget _buildCurrentStepContent() {
    switch (_step) {
      case _PasswordStep.requestLink:
        return _buildRequestLinkStep();
      case _PasswordStep.linkSent:
        return _buildLinkSentStep();
      case _PasswordStep.setNewPassword:
        return _buildSetNewPasswordStep();
      case _PasswordStep.success:
        return _buildSuccessStep();
    }
  }

  // ─── Step 1: Request Link Content ─────────────────────────────────────────

  Widget _buildRequestLinkStep() {
    return Column(
      key: const ValueKey('step_request_link'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Verification',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PetTrace will send a password reset link to your email to verify your identity before changing your password.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.email_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _maskedEmail(widget.email),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendLink,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Send Reset Link',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── Step 2: Link Sent Content ────────────────────────────────────────────

  Widget _buildLinkSentStep() {
    return Column(
      key: const ValueKey('step_link_sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We sent a password reset link to:',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Click the link in your email to open the password update screen.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Resend row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the email? ",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (_resendCooldown > 0)
              Text(
                'Resend in ${_resendCooldown}s',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _handleSendLink,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Resend Link',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),

        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurface,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Close',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Set New Password Content ─────────────────────────────────────

  Widget _buildSetNewPasswordStep() {
    final password = _newPassCtrl.text;
    final hasMinLength = password.length >= 8;
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    return Column(
      key: const ValueKey('step_set_new_password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your reset link has been verified. Enter your new password below:',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // New Password Field
        TextField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          style: GoogleFonts.inter(fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm Password Field
        TextField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          style: GoogleFonts.inter(fontSize: 14),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Live validation rules checklist
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              _buildChecklistRow(
                'At least 8 characters long',
                hasMinLength,
              ),
              const SizedBox(height: 6),
              _buildChecklistRow(
                'Contains letters & numbers',
                hasLetter && hasNumber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdatePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Update Password',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChecklistRow(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isMet ? AppColors.secondary : Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              color: isMet ? AppColors.onSurface : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Success Content ──────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('step_success'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.secondary,
            size: 36,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Password Changed!',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your account credentials have been updated securely.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
