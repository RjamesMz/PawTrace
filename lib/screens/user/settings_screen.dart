import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBottomNav;
  const SettingsScreen({super.key, this.showBottomNav = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  bool _isSavingAddress = false;
  bool _isUploadingPhoto = false;
  String _displayName = '';
  String _firstName = '';
  String _middleName = '';
  String _surname = '';
  String _suffix = '';
  String _email = '';
  String _roleText = 'PET OWNER';
  String? _photoUrl;
  String? _address;
  String? _barangay;
  String _userRole = 'owner';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AuthService.instance.getCurrentUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _firstName = profile['first_name'] as String? ?? '';
          _middleName = profile['middle_name'] as String? ?? '';
          _surname = profile['surname'] as String? ?? '';
          _suffix = profile['suffix'] as String? ?? '';
          _displayName = [_firstName, _middleName, _surname, _suffix]
              .where((s) => s.isNotEmpty)
              .join(' ');
          _email = profile['email'] ?? '';
          _photoUrl = profile['photo_url'];
          _address = (profile['address'] as String?)?.trim();
          _barangay = (profile['barangay'] as String?)?.trim() ??
              (profile['baragay'] as String?)?.trim();
          final String role = profile['role'] ?? 'owner';
          _userRole = role;
          if (role == 'admin') {
            _roleText = 'ADMIN';
          } else {
            _roleText = 'PET OWNER';
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ── Edit Profile Photo ──────────────────────────────────────────────────
  Future<void> _handleEditPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text('Update Profile Photo',
                style: GoogleFonts.montserrat(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
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

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      AppToast.error(context, 'Not signed in.');
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final file = File(picked.path);
      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath = 'avatars/$uid.$ext';

      // Upload to Supabase Storage (upsert so re-uploads work)
      await Supabase.instance.client.storage
          .from('user-photos')
          .upload(storagePath, file,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final publicUrl = Supabase.instance.client.storage
          .from('user-photos')
          .getPublicUrl(storagePath);

      // Cache-bust the URL so the widget re-fetches the new image
      final bustUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client
          .from('users')
          .update({'photo_url': publicUrl}).eq('user_id', uid);

      if (!mounted) return;
      setState(() => _photoUrl = bustUrl);
      AppToast.success(context, 'Profile photo updated!');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to upload photo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Edit Profile Info ────────────────────────────────────────────────────
  Future<void> _showEditProfileDialog() async {
    final firstCtrl = TextEditingController(text: _firstName);
    final middleCtrl = TextEditingController(text: _middleName);
    final surnameCtrl = TextEditingController(text: _surname);
    final suffixCtrl = TextEditingController(text: _suffix);
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Edit Profile',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(firstCtrl, 'First Name', Icons.badge_outlined,
                    onChanged: (_) {
                  if (errorText != null) setDlg(() => errorText = null);
                }),
                const SizedBox(height: 12),
                _dialogField(
                    middleCtrl, 'Middle Name (optional)', Icons.badge_outlined),
                const SizedBox(height: 12),
                _dialogField(surnameCtrl, 'Surname', Icons.badge_outlined,
                    onChanged: (_) {
                  if (errorText != null) setDlg(() => errorText = null);
                }),
                const SizedBox(height: 12),
                _dialogField(
                    suffixCtrl, 'Suffix (e.g. Jr.)', Icons.badge_outlined),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(errorText!,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.error))),
                    ],
                  ),
                ],
              ],
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (firstCtrl.text.trim().isEmpty ||
                          surnameCtrl.text.trim().isEmpty) {
                        setDlg(() => errorText =
                            'First name and surname are required.');
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Save',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final fn = firstCtrl.text.trim();
      final mn = middleCtrl.text.trim();
      final sn = surnameCtrl.text.trim();
      final sfx = suffixCtrl.text.trim();

      await Supabase.instance.client.from('users').update({
        'first_name': fn,
        'middle_name': mn.isEmpty ? null : mn,
        'surname': sn,
        'suffix': sfx.isEmpty ? null : sfx,
      }).eq('user_id', uid);

      if (!mounted) return;
      setState(() {
        _firstName = fn;
        _middleName = mn;
        _surname = sn;
        _suffix = sfx;
        _displayName =
            [fn, mn, sn, sfx].where((s) => s.isNotEmpty).join(' ');
      });
      AppToast.success(context, 'Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to update profile: $e');
    }
  }

  // ── Change Password ──────────────────────────────────────────────────────
  Future<void> _showChangePasswordDialog() async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Change Password',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon:
                        const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          size: 20),
                      onPressed: () => setDlg(() => obscureNew = !obscureNew),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color:
                                AppColors.outlineVariant.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                  onChanged: (_) {
                    if (errorText != null) setDlg(() => errorText = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon:
                        const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          size: 20),
                      onPressed: () =>
                          setDlg(() => obscureConfirm = !obscureConfirm),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color:
                                AppColors.outlineVariant.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                  onChanged: (_) {
                    if (errorText != null) setDlg(() => errorText = null);
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(errorText!,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.error))),
                    ],
                  ),
                ],
              ],
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final pw = newCtrl.text;
                      if (pw.length < 6) {
                        setDlg(() => errorText =
                            'Password must be at least 6 characters.');
                        return;
                      }
                      if (pw != confirmCtrl.text) {
                        setDlg(() => errorText = 'Passwords do not match.');
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Update',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newCtrl.text));
      if (!mounted) return;
      AppToast.success(context, 'Password changed successfully!');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to change password: $e');
    }
  }

  // ── Shared dialog text field helper ─────────────────────────────────────
  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      onChanged: onChanged,
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        content: Text(
          'Are you sure you want to sign out of PawTrace?',
          style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                  color: AppColors.secondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  String _addressSummary() {
    final parts = <String>[];
    final addr = (_address ?? '').trim();
    final barangay = (_barangay ?? '').trim();
    if (addr.isNotEmpty) parts.add(addr);
    if (barangay.isNotEmpty) parts.add(barangay);
    return parts.isEmpty ? 'Not set' : parts.join(', ');
  }

  Future<void> _showAddAddressDialog() async {
    final addressCtrl = TextEditingController(text: (_address ?? '').trim());
    String selectedBarangay =
        AppConstants.barangays.contains((_barangay ?? '').trim())
            ? (_barangay ?? '').trim()
            : AppConstants.barangays.first;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Address',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Calatagan Prototype',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ensure your address and barangay details are correct to receive notifications about lost pets nearby.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: addressCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'House Number / Street',
                      hintText: 'e.g. 123 Rizal St.',
                      prefixIcon: const Icon(Icons.home_outlined, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                   DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedBarangay,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.onSurface),
                    items: AppConstants.barangays
                        .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(b,
                                style: GoogleFonts.inter(fontSize: 14),
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _userRole == 'admin'
                        ? null
                        : (v) {
                            setDialogState(() {
                              selectedBarangay = v!;
                              if (errorText != null) errorText = null;
                            });
                          },
                    decoration: InputDecoration(
                      labelText: 'Barangay',
                      helperText: _userRole == 'admin'
                          ? 'Assigned official barangay (read-only)'
                          : null,
                      helperStyle: _userRole == 'admin'
                          ? GoogleFonts.inter(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)
                          : null,
                      prefixIcon:
                          const Icon(Icons.location_city_outlined, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(
                            color: AppColors.outlineVariant.withOpacity(0.5)),
                        foregroundColor: AppColors.onSurfaceVariant,
                      ),
                      child: Text('Cancel',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final addr = addressCtrl.text.trim();
                        if (addr.isEmpty) {
                          setDialogState(() => errorText =
                              'Please provide street/house details.');
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Save',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved != true || !mounted) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      AppToast.error(context, 'Unable to update address. Please sign in again.');
      return;
    }

    setState(() => _isSavingAddress = true);
    try {
      final addr = addressCtrl.text.trim();
      final baranga = selectedBarangay;

      await Supabase.instance.client.from('users').update({
        'address': addr.isEmpty ? null : addr,
        'barangay': baranga.isEmpty ? null : baranga,
      }).eq('user_id', uid);

      AuthService.instance
          .updateCachedBarangay(baranga.isEmpty ? null : baranga);

      if (!mounted) return;
      setState(() {
        _address = addr.isEmpty ? null : addr;
        _barangay = baranga.isEmpty ? null : baranga;
      });
      AppToast.success(context, 'Address updated successfully.');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to update address: $e');
    } finally {
      if (mounted) setState(() => _isSavingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Custom App Bar
            _buildAppBar(context),
            // Scrollable Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      children: [
                        // Profile Header Section
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        // Settings Card
                        _buildSettingsCard(),
                        const SizedBox(height: 24),
                        // Version Label
                        _buildVersionLabel(),
                        const SizedBox(
                            height: 80), // spacer for bottom nav bar stability
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav ? const BottomNavBar(currentIndex: 4) : null,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final titleColor =
        const Color(0xFF6E3900); // Warm brown/orange color from visual palette
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'My Profile',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Avatar + camera button — fixed size so Positioned anchors correctly
        SizedBox(
          width: 136,
          height: 136,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar fills the SizedBox
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _photoUrl != null && _photoUrl!.isNotEmpty
                      ? CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surfaceContainerHighest,
                          backgroundImage: NetworkImage(_photoUrl!),
                          onBackgroundImageError: (_, __) {
                            debugPrint('Failed to load profile image');
                          },
                        )
                      : CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surfaceContainerHighest,
                          child: Icon(Icons.person,
                              size: 60,
                              color:
                                  AppColors.onSurfaceVariant.withOpacity(0.5)),
                        ),
                ),
              ),
              // Camera button — bottom-right corner
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _handleEditPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          _displayName,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        // Role Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _roleText,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Email
        Text(
          _email,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }


  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ACCOUNT SECTION
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'ACCOUNT',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryContainer,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            onTap: _showEditProfileDialog,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: _showChangePasswordDialog,
          ),
          _buildDivider(),
          _buildSettingsTile(
            icon: Icons.location_on_outlined,
            title: _isSavingAddress ? 'Saving address...' : 'Add Address',
            subtitle: _addressSummary(),
            onTap: _isSavingAddress ? () {} : _showAddAddressDialog,
          ),
          if (_roleText == 'PET OWNER') ...[
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.pets_outlined,
              title: 'My Registered Pets',
              onTap: () => Navigator.pushNamed(context, AppRoutes.myPets),
            ),
          ],
          const SizedBox(height: 8),

          // PREFERENCES SECTION
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'PREFERENCES',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryContainer,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildSwitchTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Preferences',
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() {
                _notificationsEnabled = val;
              });
            },
          ),

          const SizedBox(height: 8),

          // DANGER ZONE SECTION
          Container(
            color: AppColors.error.withOpacity(0.05),
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'DANGER ZONE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  titleColor: AppColors.primary,
                  iconColor: AppColors.primary,
                  onTap: _handleLogout,
                  isDangerZone: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    bool isDangerZone = false,
  }) {
    final finalIconColor =
        iconColor ?? AppColors.onSurfaceVariant.withOpacity(0.7);
    final finalTitleColor = titleColor ?? AppColors.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: finalIconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight:
                          isDangerZone ? FontWeight.w600 : FontWeight.w400,
                      color: finalTitleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isSavingAddress && title == 'Saving address...')
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isDangerZone
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant.withOpacity(0.3),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              color: AppColors.onSurfaceVariant.withOpacity(0.7), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primaryContainer,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.secondaryContainer,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: AppColors.outlineVariant.withOpacity(0.2),
        height: 1,
        thickness: 1,
      ),
    );
  }

  Widget _buildVersionLabel() {
    return Center(
      child: Text(
        'PawTrace v2.4.0 (Build 892)',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: AppColors.onSurfaceVariant.withOpacity(0.4),
        ),
      ),
    );
  }
}
