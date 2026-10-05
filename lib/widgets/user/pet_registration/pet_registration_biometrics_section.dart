import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import 'pet_photo_slot_card.dart';

/// Section showing instructions and multi-angle photo slots for biometric AI recognition
class PetRegistrationBiometricsSection extends StatelessWidget {
  final File? faceImage;
  final File? leftBodyImage;
  final File? rightBodyImage;
  final File? uniqueFeatureImage;
  final Function(PetPhotoSlot slot) onPickImage;
  final Function(PetPhotoSlot slot) onRemoveImage;

  const PetRegistrationBiometricsSection({
    super.key,
    required this.faceImage,
    required this.leftBodyImage,
    required this.rightBodyImage,
    required this.uniqueFeatureImage,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Biometric Photos (Multi-Angle)',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Upload a clear face photo (required). Side angles and distinctive markings are optional but recommended to boost AI recognition accuracy.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Slot 1: Face / Front View (Required - Primary)
        PetPhotoSlotCard(
          title: 'Face / Front View',
          subtitle: 'Clear, front-facing photo of face, eyes, and snout',
          badgeText: 'REQUIRED • PRIMARY',
          isRequired: true,
          icon: Icons.face_retouching_natural_rounded,
          imageFile: faceImage,
          isWide: true,
          onTap: () => onPickImage(PetPhotoSlot.face),
          onRemove: () => onRemoveImage(PetPhotoSlot.face),
        ),
        const SizedBox(height: 12),

        // Slots 2 & 3: Left Body and Right Body (Optional)
        Row(
          children: [
            Expanded(
              child: PetPhotoSlotCard(
                title: 'Left Side Profile',
                subtitle: 'Optional side angle',
                badgeText: 'OPTIONAL • AI BOOST',
                isRequired: false,
                icon: Icons.pets_rounded,
                imageFile: leftBodyImage,
                onTap: () => onPickImage(PetPhotoSlot.leftBody),
                onRemove: () => onRemoveImage(PetPhotoSlot.leftBody),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PetPhotoSlotCard(
                title: 'Right Side Profile',
                subtitle: 'Optional side angle',
                badgeText: 'OPTIONAL • AI BOOST',
                isRequired: false,
                icon: Icons.pets_rounded,
                imageFile: rightBodyImage,
                onTap: () => onPickImage(PetPhotoSlot.rightBody),
                onRemove: () => onRemoveImage(PetPhotoSlot.rightBody),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Slot 4: Unique Identification / Distinctive Mark (Optional)
        PetPhotoSlotCard(
          title: 'Unique Mark / Distinctive Feature',
          subtitle:
              'Optional: Unique spot, chest patch, tail color, ear notch, or scar for AI boost',
          badgeText: 'OPTIONAL • AI BOOST',
          isRequired: false,
          icon: Icons.stars_rounded,
          imageFile: uniqueFeatureImage,
          isWide: true,
          onTap: () => onPickImage(PetPhotoSlot.uniqueFeature),
          onRemove: () => onRemoveImage(PetPhotoSlot.uniqueFeature),
        ),
      ],
    );
  }
}
