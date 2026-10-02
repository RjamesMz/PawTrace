import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import '../../widgets/change_password_dialog.dart';
import 'web/admin_web_layout.dart';

/// Admin Settings Screen — allows barangay admins and super admins to view
/// and edit their profile details, contact information, profile picture,
/// and update account security/password.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  UserRole _role = UserRole.admin;
  String _email = '';
  String? _barangay;
  String? _photoUrl;

  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _suffixCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _initialFirstName = '';
  String _initialMiddleName = '';
  String _initialSurname = '';
  String _initialSuffix = '';
  String _initialPhone = '';
  String _initialAddress = '';

  bool get _hasChanges {
    return _firstNameCtrl.text.trim() != _initialFirstName.trim() ||
        _middleNameCtrl.text.trim() != _initialMiddleName.trim() ||
        _surnameCtrl.text.trim() != _initialSurname.trim() ||
        _suffixCtrl.text.trim() != _initialSuffix.trim() ||
        _phoneCtrl.text.trim() != _initialPhone.trim() ||
        _addressCtrl.text.trim() != _initialAddress.trim();
  }

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(_onFieldChanged);
    _middleNameCtrl.addListener(_onFieldChanged);
    _surnameCtrl.addListener(_onFieldChanged);
    _suffixCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);
    _addressCtrl.addListener(_onFieldChanged);
    _loadProfile();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameCtrl.removeListener(_onFieldChanged);
    _middleNameCtrl.removeListener(_onFieldChanged);
    _surnameCtrl.removeListener(_onFieldChanged);
    _suffixCtrl.removeListener(_onFieldChanged);
    _phoneCtrl.removeListener(_onFieldChanged);
    _addressCtrl.removeListener(_onFieldChanged);
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _surnameCtrl.dispose();
    _suffixCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final role = await AuthService.instance.getCurrentUserRole();
      final profile = await AuthService.instance.getCurrentUserProfile();
      final user = _supabase.auth.currentUser;

      if (!mounted) return;

      if (profile != null) {
        _firstNameCtrl.text = profile['first_name']?.toString() ?? '';
        _middleNameCtrl.text = profile['middle_name']?.toString() ?? '';
        _surnameCtrl.text = profile['surname']?.toString() ?? '';
        _suffixCtrl.text = profile['suffix']?.toString() ?? '';
        _phoneCtrl.text = profile['phone']?.toString() ?? '';
        _addressCtrl.text = profile['address']?.toString() ?? '';
        _barangay = (profile['barangay'] as String?)?.trim() ??
            (profile['baragay'] as String?)?.trim();
        _photoUrl = profile['photo_url']?.toString();
      }

      _initialFirstName = _firstNameCtrl.text;
      _initialMiddleName = _middleNameCtrl.text;
      _initialSurname = _surnameCtrl.text;
      _initialSuffix = _suffixCtrl.text;
      _initialPhone = _phoneCtrl.text;
      _initialAddress = _addressCtrl.text;

      setState(() {
        _role = role;
        _email = user?.email ?? profile?['email']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEditPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Profile Photo',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: Text('Take a photo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: Text('Choose from gallery',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      AppToast.error(context, 'You must be signed in to upload a photo.');
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath = 'avatars/$uid.$ext';

      String? uploadedPublicUrl;
      dynamic lastError;

      const candidateBuckets = [
        'avatars',
        'user-photos',
        'avatar',
        'pet-photos'
      ];
      for (final bucket in candidateBuckets) {
        try {
          await _supabase.storage.from(bucket).uploadBinary(
                storagePath,
                bytes,
                fileOptions:
                    const FileOptions(upsert: true, contentType: 'image/jpeg'),
              );
          uploadedPublicUrl =
              _supabase.storage.from(bucket).getPublicUrl(storagePath);
          break;
        } catch (err) {
          lastError = err;
          if (err.toString().toLowerCase().contains('bucket not found')) {
            continue;
          }
          rethrow;
        }
      }

      if (uploadedPublicUrl == null) {
        throw lastError ??
            Exception('No storage bucket found for profile photos.');
      }

      final publicUrl = uploadedPublicUrl;
      final bustUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('users')
          .update({'photo_url': publicUrl}).eq('user_id', uid);

      if (!mounted) return;
      setState(() => _photoUrl = bustUrl);
      AppToast.success(context, 'Profile photo updated successfully!');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
          context, AppErrors.format(e, fallback: 'Failed to update photo.'));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      AppToast.error(context, 'Not signed in.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final fn = _firstNameCtrl.text.trim();
      final mn = _middleNameCtrl.text.trim();
      final sn = _surnameCtrl.text.trim();
      final sfx = _suffixCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final address = _addressCtrl.text.trim();

      await _supabase.from('users').update({
        'first_name': fn,
        'middle_name': mn.isEmpty ? null : mn,
        'surname': sn,
        'suffix': sfx.isEmpty ? null : sfx,
        'phone': phone.isEmpty ? null : phone,
        'address': address.isEmpty ? null : address,
      }).eq('user_id', uid);

      if (!mounted) return;

      _initialFirstName = fn;
      _initialMiddleName = mn;
      _initialSurname = sn;
      _initialSuffix = sfx;
      _initialPhone = phone;
      _initialAddress = address;

      AppToast.success(context, 'Admin profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
          context, AppErrors.format(e, fallback: 'Failed to save changes.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _discardChanges() {
    FocusScope.of(context).unfocus();
    setState(() {
      _firstNameCtrl.text = _initialFirstName;
      _middleNameCtrl.text = _initialMiddleName;
      _surnameCtrl.text = _initialSurname;
      _suffixCtrl.text = _initialSuffix;
      _phoneCtrl.text = _initialPhone;
      _addressCtrl.text = _initialAddress;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of PetTrace Admin?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Log Out',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();
      try {
        await _supabase.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final email = _email.trim().isNotEmpty
        ? _email.trim()
        : (_supabase.auth.currentUser?.email ?? '');
    if (email.isEmpty) {
      AppToast.error(context, 'Unable to identify email for password reset.');
      return;
    }
    await ChangePasswordDialog.show(context, email: email);
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    if (_isLoading) {
      return const AdminWebLayout(
        currentIndex: 5,
        pageTitle: 'Admin Settings',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return AdminWebLayout(
      currentIndex: 5,
      pageTitle: 'Admin Settings',
      body: AdminContentWrapper(
        maxWidth: 900,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _buildFormContent(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdminLayout(
        currentIndex: 5,
        pageTitle: 'Admin Settings',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: _buildFormContent(),
              ),
      ),
    );
  }

  Widget _buildFormContent() {
    final initial = _firstNameCtrl.text.isNotEmpty
        ? _firstNameCtrl.text[0].toUpperCase()
        : 'A';
    final fullName = [
      _firstNameCtrl.text,
      _middleNameCtrl.text,
      _surnameCtrl.text,
      _suffixCtrl.text
    ].where((s) => s.isNotEmpty).join(' ');

    final isSuperAdmin = _role == UserRole.superAdmin;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile Banner Card ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with camera button overlay
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      backgroundImage:
                          _photoUrl != null && _photoUrl!.isNotEmpty
                              ? NetworkImage(_photoUrl!)
                              : null,
                      child: _photoUrl == null || _photoUrl!.isEmpty
                          ? Text(
                              initial,
                              style: GoogleFonts.montserrat(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    if (_isUploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _handleEditPhoto,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),

                // Name & Role Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'Administrator',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSuperAdmin
                                  ? const Color(0xFF6B46C1).withOpacity(0.12)
                                  : AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSuperAdmin
                                      ? Icons.security_rounded
                                      : Icons.admin_panel_settings_rounded,
                                  size: 14,
                                  color: isSuperAdmin
                                      ? const Color(0xFF6B46C1)
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isSuperAdmin
                                      ? 'SUPER ADMIN'
                                      : 'BARANGAY ADMIN',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSuperAdmin
                                        ? const Color(0xFF6B46C1)
                                        : AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Barangay Badge (if barangay admin)
                          if (!isSuperAdmin &&
                              _barangay != null &&
                              _barangay!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF1D6F42).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: Color(0xFF1D6F42),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Brgy. $_barangay',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1D6F42),
                                    ),
                                  ),
                                ],
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
          const SizedBox(height: 24),

          // ── Section 1: Personal Details ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Update personal information.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // First Name & Middle Name
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildTextField(
                        controller: _firstNameCtrl,
                        label: 'First Name',
                        hint: 'e.g. Juan',
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            AuthService.validateName(v, fieldName: 'First name'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: _buildTextField(
                        controller: _middleNameCtrl,
                        label: 'Middle Name',
                        hint: 'Optional',
                        icon: Icons.badge_outlined,
                        validator: (v) => v != null && v.trim().isNotEmpty
                            ? AuthService.validateName(v,
                                fieldName: 'Middle name', isRequired: false)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Surname & Suffix
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildTextField(
                        controller: _surnameCtrl,
                        label: 'Surname',
                        hint: 'e.g. Dela Cruz',
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            AuthService.validateName(v, fieldName: 'Surname'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: _buildTextField(
                        controller: _suffixCtrl,
                        label: 'Suffix',
                        hint: 'e.g. Jr., III',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Phone & Barangay / Role info
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    if (isNarrow) {
                      return Column(
                        children: [
                          _buildTextField(
                            controller: _phoneCtrl,
                            label: 'Contact Phone Number',
                            hint: '09xxxxxxxxx',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) => v != null && v.trim().isNotEmpty
                                ? AuthService.validatePhone(v, isRequired: false)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildReadOnlyField(
                            label: 'Email Address',
                            value: _email,
                            icon: Icons.email_outlined,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneCtrl,
                            label: 'Contact Phone Number',
                            hint: '09xxxxxxxxx',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) => v != null && v.trim().isNotEmpty
                                ? AuthService.validatePhone(v, isRequired: false)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildReadOnlyField(
                            label: 'Email Address',
                            value: _email,
                            icon: Icons.email_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Address
                _buildTextField(
                  controller: _addressCtrl,
                  label: 'Barangay Office / Home Address',
                  hint: 'Enter detailed address',
                  icon: Icons.home_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Account Security ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 550;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shield_outlined,
                                color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Password & Security',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ensure your admin account is protected with a secure password.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.key_rounded, size: 16),
                          label: Text('Change Password',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Password & Security',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ensure your admin account is protected with a secure password.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: Text('Change Password',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // ── Save Action Bar (Visible only when info is modified) ────────
          if (_hasChanges) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading || _isSaving ? null : _discardChanges,
                  child: Text(
                    'Discard Changes',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // ── Section 3: Session & Log Out ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 550;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: AppColors.error, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session & Log Out',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Securely sign out of your admin session on this device.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: Text('Log Out',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                                color: AppColors.error.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppColors.error, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session & Log Out',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Securely sign out of your admin session on this device.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: Text('Log Out',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side:
                            BorderSide(color: AppColors.error.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withOpacity(0.5),
            ),
            prefixIcon: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : '-',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }
}
