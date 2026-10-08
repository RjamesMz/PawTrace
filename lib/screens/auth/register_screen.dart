import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/id_validation_service.dart';
import '../../services/auth/id_upload_edge_service.dart';
import '../../services/auth/user_id_service.dart';

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
  bool _agreeToTerms = false;
  bool _hasViewedTerms = false;

  // ── Valid ID uploads ───────────────────────────────────────────────────────
  Uint8List? _idFrontBytes;
  String _idFrontExt = 'jpg';
  Uint8List? _idBackBytes;
  String _idBackExt = 'jpg';
  String? _selectedIdType;
  bool _idUploadError = false;
  IdValidationResult? _idValidationResult;
  User? _registrationUser;

  // ── Form key ───────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  Future<void> _openLegal(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) {
      setState(() {
        _hasViewedTerms = true;
        _agreeToTerms = true;
      });
    }
  }

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

    if (_idFrontBytes == null || _idBackBytes == null) {
      setState(() => _idUploadError = true);
      _showError('Please upload both the front and back of your valid ID.');
      return;
    }

    if (_selectedIdType == null) {
      _showError('Please select the type of valid ID you are uploading.');
      return;
    }

    if (!_agreeToTerms) {
      _showError(
          'Please check and agree to the Terms & Conditions and Privacy Policy.');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final validation = await IdValidationService.validate(
        frontBytes: _idFrontBytes!,
        backBytes: _idBackBytes!,
        firstName: firstName,
        surname: surname,
      );
      if (!validation.isUsableForRegistration) {
        _idValidationResult = validation;
        _showError(validation.message ?? 'Please review your ID photos.');
        return;
      }

      // Create the authenticated account before touching private Storage.
      final registrationUser = _registrationUser ??
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
      _registrationUser = registrationUser;

      // Upload ID images via Edge Function (bypasses RLS — no session required).
      try {
        await IdUploadEdgeService.uploadViaEdgeFunction(
          userId: registrationUser.id,
          frontBytes: _idFrontBytes!,
          frontExt: _idFrontExt,
          backBytes: _idBackBytes!,
          backExt: _idBackExt,
          idType: _selectedIdType,
          ocrExtractedText: validation.ocrExtractedText,
          nameMatchScore: validation.nameMatchScore,
          imageQuality:
              'front:${validation.frontQuality};back:${validation.backQuality}',
        );
      } catch (e) {
        throw StateError(
          'Your account was created, but the ID submission was not completed. '
          'Please retry the ID upload. Details: $e',
        );
      }

      // Ensure the user signs out so they must verify their email before accessing
      await AuthService.instance.signOut();
      _registrationUser = null;
      if (!mounted) return;

      // Show confirmation popup with spam folder warning
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    color: AppColors.primary,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            color: Color(0xFF2563EB),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Verify Your Email',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We sent a confirmation link to:\n$email',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Spam folder reminder banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Important: If you do not see the confirmation email in your inbox, please make sure to check your Spam or Junk folder.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Got It, Proceed to Login',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
        arguments: {
          'flashMessage':
              'Registration successful! Please check your email (and Spam folder) to verify your account before logging in.',
          'flashEmail': email,
        },
      );
      AppToast.show(
        null,
        'Please check your email (or Spam folder) to verify your account.',
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF1E293B),
        icon: Icons.mark_email_unread_rounded,
      );
    } on AuthException catch (e) {
      _showError(AuthService.friendlyError(e));
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                            hint: 'Last name',
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => AuthService.validateName(v,
                                fieldName: 'Last name'),
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
                      helperText:
                          'At least 8 characters with letters & numbers',
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
                    const SizedBox(height: 20),

                    // ── Valid ID Upload Section (Required) ───────────────────
                    _buildIdTypeDropdown(),
                    const SizedBox(height: 12),
                    _buildValidIdSection(),
                    const SizedBox(height: 18),

                    // ── Terms & Conditions Checkbox ───────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: _agreeToTerms
                            ? AppColors.primaryContainer.withOpacity(0.12)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _agreeToTerms
                              ? AppColors.primary.withOpacity(0.4)
                              : AppColors.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              if (!_hasViewedTerms) {
                                AppToast.show(
                                  context,
                                  'Please review the Terms & Conditions and Privacy Policy first.',
                                  icon: Icons.info_outline_rounded,
                                );
                                _openLegal(AppRoutes.termsOfService);
                                return;
                              }
                              setState(() => _agreeToTerms = val ?? false);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'I have read and agree to the ',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _openLegal(AppRoutes.termsOfService),
                                    child: Text(
                                      'Terms & Conditions',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ' and ',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _openLegal(AppRoutes.privacyPolicy),
                                    child: Text(
                                      'Privacy Policy',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Create Account button ─────────────────────────────────
                    Builder(builder: (context) {
                      final hasBothIds =
                          _idFrontBytes != null && _idBackBytes != null;
                      final canSubmit =
                          !_isLoading && _agreeToTerms && hasBothIds;

                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: canSubmit ? _handleRegister : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            elevation: canSubmit ? 6 : 0,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Create Account',
                                      style: TextStyle(
                                        color: _agreeToTerms
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 20,
                                      color: _agreeToTerms
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }),
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
                          onTap: () => Navigator.pushReplacementNamed(
                              context, AppRoutes.login),
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

  Widget _buildIdTypeDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedIdType,
      validator: (value) => value == null ? 'Please select your ID type' : null,
      decoration: InputDecoration(
        hintText: 'Select ID Type',
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.secondary.withOpacity(0.55),
        ),
        prefixIcon: const Icon(Icons.badge_outlined,
            color: AppColors.secondary, size: 20),
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
        DropdownMenuItem(value: 'PhilSys ID', child: Text('PhilSys ID')),
        DropdownMenuItem(
            value: 'Driver License', child: Text('Driver License')),
        DropdownMenuItem(value: 'Passport', child: Text('Passport')),
        DropdownMenuItem(value: 'UMID', child: Text('UMID')),
        DropdownMenuItem(value: 'PRC ID', child: Text('PRC ID')),
        DropdownMenuItem(
            value: 'Other Government ID', child: Text('Other Government ID')),
      ],
      onChanged: (value) => setState(() => _selectedIdType = value),
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

  // ══════════════════════════════════════════════════════════════════════════
  //  VALID ID SECTION & IMAGE PICKER
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickIdImage({required bool isFront}) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Upload ${isFront ? "ID Front" : "ID Back"}',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose image source for valid ID verification',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: Text('Take Photo',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Capture with device camera',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.secondary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Upload from files or photos',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.secondary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.contains('.')
            ? picked.name.split('.').last.toLowerCase()
            : 'jpg';
        setState(() {
          if (isFront) {
            _idFrontBytes = bytes;
            _idFrontExt = ext;
          } else {
            _idBackBytes = bytes;
            _idBackExt = ext;
          }
          _idUploadError = false;
        });
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not select image: $e');
    }
  }

  Widget _buildValidIdSection() {
    final hasFront = _idFrontBytes != null;
    final hasBack = _idBackBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Valid Identification',
              style: GoogleFonts.montserrat(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Required',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Upload clear photos of both sides of your valid government ID.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        if (_idValidationResult != null) ...[
          _buildValidationFeedback(_idValidationResult!),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;
            final cardFront = _buildIdUploadCard(
              label: 'ID Front',
              bytes: _idFrontBytes,
              isFront: true,
            );
            final cardBack = _buildIdUploadCard(
              label: 'ID Back',
              bytes: _idBackBytes,
              isFront: false,
            );

            if (isNarrow) {
              return Column(
                children: [
                  cardFront,
                  const SizedBox(height: 12),
                  cardBack,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cardFront),
                const SizedBox(width: 12),
                Expanded(child: cardBack),
              ],
            );
          },
        ),
        if (_idUploadError && (!hasFront || !hasBack)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Text(
                'Both ID Front and ID Back images are required.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildValidationFeedback(IdValidationResult result) {
    final isPassed = result.validationStatus == 'passed';
    final color = isPassed ? const Color(0xFF15803D) : const Color(0xFFB45309);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isPassed ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message ?? 'ID validation complete.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdUploadCard({
    required String label,
    required Uint8List? bytes,
    required bool isFront,
  }) {
    final bool hasImage = bytes != null;

    return Container(
      decoration: BoxDecoration(
        color: hasImage ? Colors.white : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImage
              ? AppColors.primary.withOpacity(0.5)
              : (_idUploadError
                  ? AppColors.error.withOpacity(0.6)
                  : AppColors.outlineVariant.withOpacity(0.6)),
          width: hasImage ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pickIdImage(isFront: isFront),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasImage
                        ? Icons.check_circle_rounded
                        : Icons.credit_card_rounded,
                    size: 16,
                    color:
                        hasImage ? const Color(0xFF16A34A) : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (hasImage)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isFront) {
                            _idFrontBytes = null;
                          } else {
                            _idBackBytes = null;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bytes, fit: BoxFit.cover),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_rounded,
                                    color: Colors.white, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 26,
                        color: AppColors.secondary.withOpacity(0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload $label',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'JPG / PNG accepted',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.secondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
