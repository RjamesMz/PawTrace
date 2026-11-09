import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';

/// Custom map marker showing the pet's registered photo inside a circular avatar
/// perfectly dead-centered at the GPS coordinate with a floating name chip above.
class LostPetMarkerWidget extends StatelessWidget {
  final String petName;
  final String? photoUrl;
  final bool isSelected;
  final VoidCallback? onTap;

  const LostPetMarkerWidget({
    super.key,
    required this.petName,
    this.photoUrl,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor =
        isSelected ? AppColors.error : const Color(0xFFD97706);
    final avatarSize = isSelected ? 48.0 : 38.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 140,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // ── 1. Circular Pet Photo (DEAD CENTER AT GPS POINT) ────────────
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: ringColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withOpacity(isSelected ? 0.45 : 0.25),
                    blurRadius: isSelected ? 8 : 5,
                    spreadRadius: isSelected ? 2 : 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl!.trim().isNotEmpty
                    ? Image.network(
                        photoUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.pets_rounded,
                          color: Colors.white,
                          size: isSelected ? 24 : 18,
                        ),
                      )
                    : Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                        size: isSelected ? 24 : 18,
                      ),
              ),
            ),

            // ── 2. Pet Name Chip (Positioned Directly Above the Avatar) ──────
            Positioned(
              top: isSelected ? 0 : 3,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 8 : 6,
                  vertical: isSelected ? 2.5 : 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.error : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: isSelected
                      ? null
                      : Border.all(color: ringColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.error.withOpacity(0.35)
                          : Colors.black.withOpacity(0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSelected) ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ringColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isSelected ? 11 : 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
