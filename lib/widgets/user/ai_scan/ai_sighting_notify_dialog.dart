import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/ai/pet_match_service.dart';
import '../../common/photo_placeholder.dart';

/// Configuration returned by [AiSightingNotifyDialog]
class SightingNotifyConfig {
  final bool shouldNotify;
  final String contactPreference; // 'phone', 'email', 'anonymous'
  final String? note;

  const SightingNotifyConfig({
    required this.shouldNotify,
    required this.contactPreference,
    this.note,
  });
}

/// A modal popup shown when AI detects a high visual match (>= 75%)
/// allowing the scanner to customize their contact sharing preferences and add a note for the owner.
class AiSightingNotifyDialog extends StatefulWidget {
  final PetMatchResult match;
  final String? userName;
  final String? userPhone;
  final String? userEmail;

  const AiSightingNotifyDialog({
    super.key,
    required this.match,
    this.userName,
    this.userPhone,
    this.userEmail,
  });

  /// Displays the sighting notification dialog as a modal bottom sheet.
  static Future<SightingNotifyConfig?> show(
    BuildContext context, {
    required PetMatchResult match,
    String? userName,
    String? userPhone,
    String? userEmail,
  }) {
    return showModalBottomSheet<SightingNotifyConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AiSightingNotifyDialog(
          match: match,
          userName: userName,
          userPhone: userPhone,
          userEmail: userEmail,
        ),
      ),
    );
  }

  @override
  State<AiSightingNotifyDialog> createState() => _AiSightingNotifyDialogState();
}

class _AiSightingNotifyDialogState extends State<AiSightingNotifyDialog> {
  late String _selectedPreference;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to phone if available, else email, else anonymous
    if (widget.userPhone != null && widget.userPhone!.trim().isNotEmpty) {
      _selectedPreference = 'phone';
    } else if (widget.userEmail != null &&
        widget.userEmail!.trim().isNotEmpty) {
      _selectedPreference = 'email';
    } else {
      _selectedPreference = 'anonymous';
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Widget _buildOptionTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedPreference == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : AppColors.outlineVariant.withOpacity(0.6),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedPreference,
        onChanged: (val) {
          if (val != null) setState(() => _selectedPreference = val);
        },
        activeColor: const Color(0xFF059669),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD1FAE5)
                : AppColors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? const Color(0xFF059669)
                : AppColors.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            if (isRecommended) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Recommended',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.match;
    final matchPercent = (pet.similarity * 100).round();
    final hasPhone =
        widget.userPhone != null && widget.userPhone!.trim().isNotEmpty;
    final hasEmail =
        widget.userEmail != null && widget.userEmail!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header: Match Badge & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$matchPercent% MATCH',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lost Pet Found!',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Notify ${pet.name}\'s Owner?',
                        style: GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pet Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: pet.photoUrl.isNotEmpty
                          ? Image.network(
                              pet.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const PhotoPlaceholder(width: 52, height: 52),
                            )
                          : const PhotoPlaceholder(width: 52, height: 52),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pet.species} · ${pet.breed}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        if (pet.barangay.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 13, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  'Missing near Brgy. ${pet.barangay}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Contact Sharing Section
            Text(
              'How would you like the owner to reach you?',
              style: GoogleFonts.montserrat(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what contact information is shared with the pet owner:',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            if (hasPhone)
              _buildOptionTile(
                value: 'phone',
                icon: Icons.phone_rounded,
                title: 'Share Phone Number',
                subtitle: widget.userPhone!,
                isRecommended: true,
              ),

            if (hasEmail)
              _buildOptionTile(
                value: 'email',
                icon: Icons.email_rounded,
                title: 'Share Email Address',
                subtitle: widget.userEmail!,
                isRecommended: !hasPhone,
              ),

            _buildOptionTile(
              value: 'anonymous',
              icon: Icons.visibility_off_rounded,
              title: 'Anonymous / Location Only',
              subtitle: 'Shares sighting photo & location without personal contact',
            ),
            const SizedBox(height: 12),

            // Optional Note / Message
            Text(
              'Optional message to owner',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLength: 140,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'e.g. Pet was seen resting near 7-Eleven, seems friendly...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.outline,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.outlineVariant.withOpacity(0.7),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF059669),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const SightingNotifyConfig(
                          shouldNotify: false,
                          contactPreference: 'skip',
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      side: BorderSide(
                        color: AppColors.outlineVariant.withOpacity(0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      'Don\'t Notify',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        SightingNotifyConfig(
                          shouldNotify: true,
                          contactPreference: _selectedPreference,
                          note: _noteCtrl.text.trim().isNotEmpty
                              ? _noteCtrl.text.trim()
                              : null,
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      'Send Alert to Owner',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
