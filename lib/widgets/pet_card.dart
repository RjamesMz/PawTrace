import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

/// Reusable PetCard widget displaying a pet's photo, name, breed,
/// last-seen location, and status badge (Lost / Found / Active).
class PetCard extends StatelessWidget {
  /// Network URL for the pet photo (orange placeholder shown on error).
  final String imageUrl;

  /// Pet name.
  final String name;

  /// Pet breed / species.
  final String breed;

  /// Status label – e.g. 'Lost', 'Found', 'Active'.
  final String status;

  /// Location / time label shown below the breed.
  final String location;

  /// Timestamp / relative time label (e.g. '2 hours ago').
  final String timeAgo;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const PetCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.breed,
    required this.status,
    required this.location,
    this.timeAgo = '',
    this.onTap,
  });

  Color get _badgeColor {
    switch (status.toLowerCase()) {
      case 'lost':
        return AppColors.primaryContainer;
      case 'found':
        return const Color(0xFF00796B);
      case 'active':
        return const Color(0xFF22C55E);
      default:
        return AppColors.secondaryContainer;
    }
  }

  Color get _badgeTextColor {
    switch (status.toLowerCase()) {
      case 'lost':
        return AppColors.onPrimaryContainer;
      case 'found':
        return Colors.white;
      case 'active':
        return Colors.white;
      default:
        return AppColors.onSecondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primaryContainer.withOpacity(0.2),
                      child: const Center(
                        child: Icon(Icons.pets, size: 48, color: AppColors.primaryContainer),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer, strokeWidth: 2)),
                      );
                    },
                  ),
                ),
                // Status badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _badgeTextColor, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      if (timeAgo.isNotEmpty)
                        Text(timeAgo, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(breed, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant),
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
    );
  }
}
