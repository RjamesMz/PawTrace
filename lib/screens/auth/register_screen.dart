import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/auth_service.dart';

/// Standalone Register / Sign-up screen for PawTrace.
///
/// Matches the uploaded `singup.png` stitch design:
///   - PawTrace brand header (paw icon + wordmark)
///   - Role selector: Pet Owner / Finder
///   - Form: Full Name, Email, Password × 2, Phone
///   - Orange "Create Account →" primary button
///   - "Already have an account? Login" link + terms footer
///
/// Auth is delegated to [AuthService] (Firebase Auth + Firestore).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;

  // ── Register controllers ───────────────────────────────────────────────────
  final _regFirstNameCtrl = TextEditingController();
  final _regMiddleNameCtrl = TextEditingController();
  final _regSurnameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  String? _selectedSuffix;
  String? _selectedBarangay;
  
  bool _obscureRegPwd = true;
  bool _obscureRegConfirm = true;

  // ── Form key ───────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _regFirstNameCtrl.dispose();
    _regMiddleNameCtrl.dispose();
    _regSurnameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    _regPhoneCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final firstName = _regFirstNameCtrl.text.trim();
    final middleName = _regMiddleNameCtrl.text.trim();
    final surname = _regSurnameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final password = _regPasswordCtrl.text;
    final confirm = _regConfirmCtrl.text;
    final phone = _regPhoneCtrl.text.trim();

    final pwError = AuthService.validatePassword(password);
    if (pwError != null) {
      _showError(pwError);
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
      _showError('Please select your barangay.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.register(
        firstName: firstName,
        middleName: middleName.isEmpty ? null : middleName,
        surname: surname,
        suffix: _selectedSuffix,
        email: email,
        password: password,
        phone: phone,
        barangay: _selectedBarangay,
      );
      // Ensure the user signs out so they must verify their email before accessing
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
        arguments: {
          'flashMessage':
              'Registration successful! Please check your email and verify your account first before signing in.',
          'flashEmail': email,
        },
      );
      AppToast.show(
        null,
        'Please check your email and verify your account first before signing in.',
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF1E293B),
        icon: Icons.mark_email_unread_rounded,
      );
    } on AuthException catch (e) {
      _showError(AuthService.friendlyError(e));
    } catch (e) {
      _showError('Unexpected error: $e');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // ── Brand header ─────────────────────────────────────────
                    _buildBrandHeader(),
                    const SizedBox(height: 24),

                    // ── Headline ─────────────────────────────────────────────
                    Text(
                      'Create Account',
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join ${AppConstants.appName} and help find lost pets in Calatagan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.secondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Form fields ──────────────────────────────────────────
                    _formField(
                      controller: _regFirstNameCtrl,
                      hint: 'First Name',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          AuthService.validateName(v, fieldName: 'First name'),
                    ),
                    const SizedBox(height: 12),
                    _formField(
                      controller: _regMiddleNameCtrl,
                      hint: 'Middle Name (optional)',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v != null && v.trim().isNotEmpty
                          ? AuthService.validateName(v,
                              fieldName: 'Middle name', isRequired: false)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _formField(
                            controller: _regSurnameCtrl,
                            hint: 'Surname',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                AuthService.validateName(v, fieldName: 'Surname'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildSuffixDropdown(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _formField(
                      controller: _regEmailCtrl,
                      hint: 'Email Address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: AuthService.validateEmail,
                    ),
                    const SizedBox(height: 12),
                    _passwordField(
                      controller: _regPasswordCtrl,
                      hint: 'Password',
                      helperText: 'At least 8 characters with letters & numbers',
                      obscure: _obscureRegPwd,
                      onToggle: () =>
                          setState(() => _obscureRegPwd = !_obscureRegPwd),
                      validator: AuthService.validatePassword,
                    ),
                    const SizedBox(height: 12),
                    _passwordField(
                      controller: _regConfirmCtrl,
                      hint: 'Confirm Password',
                      obscure: _obscureRegConfirm,
                      onToggle: () => setState(
                          () => _obscureRegConfirm = !_obscureRegConfirm),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm password';
                        }
                        if (v != _regPasswordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _formField(
                      controller: _regPhoneCtrl,
                      hint: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v != null && v.trim().isNotEmpty
                          ? AuthService.validatePhone(v, isRequired: false)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildBarangayDropdown(),
                    const SizedBox(height: 24),

                    // ── Create Account button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 6,
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
                                  Text('Create Account'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Login link ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.secondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                          child: Text(
                            'Login',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Terms footer ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'By clicking "Create Account", you agree to PetTrace\'s Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.secondary.withOpacity(0.55),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
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
        Text(
          AppConstants.appName,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── Suffix dropdown ────────────────────────────────────────────────────────

  Widget _buildBarangayDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedBarangay,
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Please select your barangay' : null,
      decoration: InputDecoration(
        hintText: 'Select Barangay',
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.secondary.withOpacity(0.55),
        ),
        prefixIcon: const Icon(
          Icons.location_on_outlined,
          color: AppColors.secondary,
          size: 20,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      icon: const Icon(Icons.expand_more_rounded, color: AppColors.secondary),
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      dropdownColor: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      items: AppConstants.barangays
          .map((b) => DropdownMenuItem(
                value: b,
                child: Text('Brgy. $b'),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedBarangay = v),
    );
  }

  Widget _buildSuffixDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedSuffix,
      decoration: InputDecoration(
        hintText: 'Suffix',
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.secondary.withOpacity(0.55),
        ),
        prefixIcon: const Icon(
          Icons.badge_outlined,
          color: AppColors.secondary,
          size: 20,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      icon: const Icon(Icons.expand_more_rounded, color: AppColors.secondary),
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      dropdownColor: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      items: const [
        DropdownMenuItem(value: null, child: Text('None')),
        DropdownMenuItem(value: 'Jr.', child: Text('Jr.')),
        DropdownMenuItem(value: 'Sr.', child: Text('Sr.')),
        DropdownMenuItem(value: 'II', child: Text('II')),
        DropdownMenuItem(value: 'III', child: Text('III')),
        DropdownMenuItem(value: 'IV', child: Text('IV')),
        DropdownMenuItem(value: 'V', child: Text('V')),
      ],
      onChanged: (v) => setState(() => _selectedSuffix = v),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
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
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helperText,
        helperStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.secondary.withOpacity(0.8),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.secondary.withOpacity(0.55),
        ),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.secondary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
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
}
