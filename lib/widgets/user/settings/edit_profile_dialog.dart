import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/auth/auth_service.dart';

class EditProfileDialog extends StatefulWidget {
  final String firstName;
  final String middleName;
  final String surname;
  final String suffix;
  final String email;
  final VoidCallback onChangeEmail;

  const EditProfileDialog({
    super.key,
    required this.firstName,
    required this.middleName,
    required this.surname,
    required this.suffix,
    required this.email,
    required this.onChangeEmail,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _middleCtrl;
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _suffixCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.firstName);
    _middleCtrl = TextEditingController(text: widget.middleName);
    _surnameCtrl = TextEditingController(text: widget.surname);
    _suffixCtrl = TextEditingController(text: widget.suffix);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _middleCtrl.dispose();
    _surnameCtrl.dispose();
    _suffixCtrl.dispose();
    super.dispose();
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }

  void _onSave() {
    final fnErr =
        AuthService.validateName(_firstCtrl.text, fieldName: 'First name');
    if (fnErr != null) {
      setState(() => _errorText = fnErr);
      return;
    }
    final snErr =
        AuthService.validateName(_surnameCtrl.text, fieldName: 'Surname');
    if (snErr != null) {
      setState(() => _errorText = snErr);
      return;
    }
    if (_middleCtrl.text.trim().isNotEmpty) {
      final mnErr = AuthService.validateName(_middleCtrl.text,
          fieldName: 'Middle name', isRequired: false);
      if (mnErr != null) {
        setState(() => _errorText = mnErr);
        return;
      }
    }

    Navigator.pop(context, <String, String>{
      'first_name': _firstCtrl.text.trim(),
      'middle_name': _middleCtrl.text.trim(),
      'surname': _surnameCtrl.text.trim(),
      'suffix': _suffixCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(width: 12),
          Text(
            'Edit Profile',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Update your personal profile information.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _dialogField(
              _firstCtrl,
              'First Name',
              Icons.badge_outlined,
              hint: 'e.g. Juan',
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: 12),
            _dialogField(
              _middleCtrl,
              'Middle Name (optional)',
              Icons.badge_outlined,
              hint: 'e.g. Santos',
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: 12),
            _dialogField(
              _surnameCtrl,
              'Surname',
              Icons.badge_outlined,
              hint: 'e.g. Dela Cruz',
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: 12),
            _dialogField(
              _suffixCtrl,
              'Suffix (optional)',
              Icons.badge_outlined,
              hint: 'e.g. Jr., III',
            ),
            const SizedBox(height: 14),
            // ── Email Display & Change Email Button ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.email.trim().isNotEmpty
                              ? widget.email.trim()
                              : 'No email set',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onChangeEmail,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(
                      'Change',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 15, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorText!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: AppColors.outlineVariant.withOpacity(0.5),
                  ),
                  foregroundColor: AppColors.onSurfaceVariant,
                ),
                child: Text('Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('Save Changes',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
