import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../services/auth/auth_service.dart';

class EditAddressDialog extends StatefulWidget {
  final String? address;
  final String? barangay;
  final String userRole;

  const EditAddressDialog({
    super.key,
    required this.address,
    required this.barangay,
    required this.userRole,
  });

  @override
  State<EditAddressDialog> createState() => _EditAddressDialogState();
}

class _EditAddressDialogState extends State<EditAddressDialog> {
  late final TextEditingController _addressCtrl;
  late String _selectedBarangay;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: (widget.address ?? '').trim());
    _selectedBarangay =
        AppConstants.barangays.contains((widget.barangay ?? '').trim())
            ? (widget.barangay ?? '').trim()
            : AppConstants.barangays.first;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final addr = _addressCtrl.text.trim();
    final validationErr = AuthService.validateAddress(addr);
    if (validationErr != null) {
      setState(() => _errorText = validationErr);
      return;
    }
    Navigator.pop(context, <String, String>{
      'address': addr,
      'barangay': _selectedBarangay,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.address == null || widget.address!.trim().isEmpty;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
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
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            isNew ? 'Add Address' : 'Update Address',
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
            const SizedBox(height: 6),
            TextField(
              controller: _addressCtrl,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'House No. / Street',
                hintText: 'e.g. 123 Rizal St.',
                prefixIcon: const Icon(Icons.home_outlined, size: 20),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedBarangay,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
              items: AppConstants.barangays
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(
                          b,
                          style: GoogleFonts.inter(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: widget.userRole == 'admin'
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() {
                          _selectedBarangay = v;
                          if (_errorText != null) _errorText = null;
                        });
                      }
                    },
              decoration: InputDecoration(
                labelText: 'Barangay',
                helperText: widget.userRole == 'admin'
                    ? 'Assigned official barangay'
                    : null,
                prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
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
            const SizedBox(height: 6),
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
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
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
                child: Text(
                  'Save',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
