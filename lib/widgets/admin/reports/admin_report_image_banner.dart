import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hero image banner for an incident report, supporting both side-by-side and stacked modes.
/// If a verification photo of the found pet exists, allows the admin to toggle between
/// the original lost report photo and the newly captured found verification photo.
class AdminReportImageBanner extends StatefulWidget {
  final String imageUrl;
  final String? foundPhotoUrl;
  final String petCondition;
  final String status;
  final bool isArchived;
  final bool isFound;
  final VoidCallback? onClose;
  final bool isSideBySide;
  final double? height;

  const AdminReportImageBanner({
    super.key,
    required this.imageUrl,
    this.foundPhotoUrl,
    required this.petCondition,
    this.status = '',
    this.isArchived = false,
    required this.isFound,
    this.onClose,
    this.isSideBySide = false,
    this.height,
  });

  @override
  State<AdminReportImageBanner> createState() => _AdminReportImageBannerState();
}

class _AdminReportImageBannerState extends State<AdminReportImageBanner> {
  bool _showFoundPhoto = false;

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 44,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No photo available',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerHeight =
        widget.height ?? (widget.isSideBySide ? double.infinity : 220.0);
    final hasFoundPhoto = widget.isFound &&
        widget.foundPhotoUrl != null &&
        widget.foundPhotoUrl!.isNotEmpty;
    final currentImage =
        (_showFoundPhoto && hasFoundPhoto) ? widget.foundPhotoUrl! : widget.imageUrl;

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full height/width image or placeholder
          currentImage.isNotEmpty
              ? Image.network(
                  currentImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),

          // Gradient scrim overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.black.withOpacity(0.75),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Top-Left Badge
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_showFoundPhoto && hasFoundPhoto)
                    ? const Color(0xFF16A34A).withOpacity(0.85)
                    : Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (_showFoundPhoto && hasFoundPhoto)
                        ? Icons.verified_rounded
                        : Icons.pets,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (_showFoundPhoto && hasFoundPhoto)
                        ? 'FOUND VERIFICATION PHOTO'
                        : 'LOST PET REPORT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top-Right Close Button
          if (widget.onClose != null)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),

          // Photo Switcher Chips (when both photos exist)
          if (hasFoundPhoto)
            Positioned(
              top: 50,
              left: 14,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showFoundPhoto = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_showFoundPhoto
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Lost Photo',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: !_showFoundPhoto
                                ? Colors.black
                                : Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showFoundPhoto = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showFoundPhoto
                              ? const Color(0xFF22C55E)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              size: 11,
                              color: _showFoundPhoto
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.85),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Found Pic',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Badges (Condition + Status)
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                // Pet Condition Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isFound
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isFound
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isFound
                            ? Icons.check_circle_rounded
                            : Icons.campaign_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.petCondition,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
