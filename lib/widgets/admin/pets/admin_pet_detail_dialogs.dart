import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Contact Owner Dialog
void showAdminContactOwnerDialog(
    BuildContext context, Map<String, dynamic> pet) {
  final owner = pet['users'];
  final ownerName = owner is Map
      ? [
          owner['first_name'],
          owner['middle_name'],
          owner['surname'],
          owner['suffix']
        ].where((s) => s != null && s.toString().isNotEmpty).join(' ')
      : 'Unknown Owner';
  final phone = owner is Map ? (owner['phone']?.toString() ?? '') : '';
  final email = owner is Map ? (owner['email']?.toString() ?? '') : '';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.contact_phone_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('Owner Contact',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name: ${ownerName.isNotEmpty ? ownerName : 'Not provided'}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Phone: ${phone.isNotEmpty ? phone : 'Not provided'}',
              style: GoogleFonts.inter()),
          const SizedBox(height: 4),
          Text('Email: ${email.isNotEmpty ? email : 'Not provided'}',
              style: GoogleFonts.inter()),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Edit Archive Reason Dialog
void showAdminEditArchiveReasonDialog(
  BuildContext context, {
  required String? initialReason,
  required Future<void> Function(String reason) onSave,
}) {
  String? selectedReason = initialReason;
  final customCtrl = TextEditingController(
    text: (selectedReason != null &&
            ![
              'Passed Away',
              'Rehomed / Adopted',
              'No longer in my care'
            ].contains(selectedReason))
        ? selectedReason
        : '',
  );
  if (selectedReason != null &&
      !['Passed Away', 'Rehomed / Adopted', 'No longer in my care']
          .contains(selectedReason)) {
    selectedReason = 'Other';
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) {
        final canSave = selectedReason != null &&
            (selectedReason != 'Other' || customCtrl.text.trim().isNotEmpty);

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Set Archive Reason',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the reason why this pet was archived:',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ...[
                  'Passed Away',
                  'Rehomed / Adopted',
                  'No longer in my care',
                  'Other'
                ].map((r) {
                  final isSel = selectedReason == r;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setDlgState(() => selectedReason = r),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isSel
                                  ? AppColors.primary
                                  : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: isSel
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              r,
                              style: GoogleFonts.inter(
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCtrl,
                    onChanged: (_) => setDlgState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter specific reason...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: !canSave
                  ? null
                  : () async {
                      final finalReason = selectedReason == 'Other'
                          ? customCtrl.text.trim()
                          : selectedReason!;
                      Navigator.pop(ctx);
                      await onSave(finalReason);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Reason'),
            ),
          ],
        );
      },
    ),
  );
}
