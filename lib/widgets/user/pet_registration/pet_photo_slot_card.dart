import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Pet photo capture slot enum
enum PetPhotoSlot {
  face,
  leftBody,
  rightBody,
  uniqueFeature,
}

/// Image source selection modal option (Camera / Gallery)
class ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ImageSourceOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo slot card supporting empty dashed-like state and loaded image with remove button
class PetPhotoSlotCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final bool isRequired;
  final IconData icon;
  final File? imageFile;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isWide;

  const PetPhotoSlotCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.isRequired,
    required this.icon,
    required this.imageFile,
    required this.onTap,
    required this.onRemove,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null;
    final cardHeight =
        hasImage ? (isWide ? 140.0 : 130.0) : (isWide ? 88.0 : 120.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
                ? Colors.transparent
                : AppColors.outlineVariant.withOpacity(0.45),
            width: 1,
          ),
          image: hasImage
              ? DecorationImage(
                  image: FileImage(imageFile!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.08),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            // Empty state content
            if (!hasImage)
              Center(
                child: isWide
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 22,
                            color: AppColors.onSurfaceVariant.withOpacity(0.45),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                isRequired ? 'Required' : 'Optional',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 24,
                            color: AppColors.onSurfaceVariant.withOpacity(0.40),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface.withOpacity(0.65),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRequired ? 'Required' : 'Optional',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color:
                                  AppColors.onSurfaceVariant.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
              ),

            // Filled state: small "✓ title" label bottom-left
            if (hasImage)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Remove button top-right
            if (hasImage)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
