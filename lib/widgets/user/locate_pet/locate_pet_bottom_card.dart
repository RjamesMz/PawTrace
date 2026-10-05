import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Bottom info card on Locate Pet screen that can be expanded or minimized
class LocatePetBottomCard extends StatelessWidget {
  final Map<String, dynamic> pet;
  final String? currentCollarId;
  final bool hasCollar;
  final bool isGpsActive;
  final int battery;
  final String lastUpdated;
  final double? lat;
  final double? lon;
  final bool isCardMinimized;
  final double cardHeight;
  final String Function(String timestamp) formatTimeAgo;
  final VoidCallback onToggleMinimize;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onManageCollar;
  final VoidCallback onReportLost;
  final VoidCallback onShare;

  const LocatePetBottomCard({
    super.key,
    required this.pet,
    required this.currentCollarId,
    required this.hasCollar,
    required this.isGpsActive,
    required this.battery,
    required this.lastUpdated,
    required this.lat,
    required this.lon,
    required this.isCardMinimized,
    required this.cardHeight,
    required this.formatTimeAgo,
    required this.onToggleMinimize,
    required this.onDragEnd,
    required this.onManageCollar,
    required this.onReportLost,
    required this.onShare,
  });

  Widget _infoPill(IconData icon, String text, {IconData? trailingIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 12, color: AppColors.primary),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petName = pet['name'] ?? 'Your Pet';
    final photoUrl = pet['photo_url'] as String?;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      bottom: 0,
      left: 0,
      right: 0,
      height: cardHeight,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            onDragEnd(details.primaryVelocity!);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: Column(
            children: [
              // Header / Handle bar with toggle
              InkWell(
                onTap: onToggleMinimize,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Mini summary row when minimized, or minimize prompt when expanded
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isCardMinimized) ...[
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    backgroundColor:
                                        AppColors.primaryContainer,
                                    child: photoUrl == null
                                        ? const Icon(Icons.pets,
                                            size: 14,
                                            color: AppColors.primary)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      petName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: !hasCollar
                                          ? const Color(0xFFFEF3C7)
                                          : (isGpsActive
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFFEE2E2)),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      !hasCollar
                                          ? 'Unpaired'
                                          : (isGpsActive
                                              ? 'Active'
                                              : 'Offline'),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: !hasCollar
                                            ? const Color(0xFF92400E)
                                            : (isGpsActive
                                                ? const Color(0xFF065F46)
                                                : const Color(
                                                    0xFFB91C1C)),
                                      ),
                                    ),
                                  ),
                                  if (hasCollar && battery > 0) ...[
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.battery_full,
                                            size: 13,
                                            color: Color(0xFF22C55E)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$battery%',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Pet & Location Details',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              Text(
                                isCardMinimized
                                    ? 'Show Details'
                                    : 'Minimize',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Icon(
                                isCardMinimized
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Detailed Content (Only rendered when expanded)
              if (!isCardMinimized)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pet name and status
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              backgroundColor: AppColors.primaryContainer,
                              child: photoUrl == null
                                  ? const Icon(Icons.pets,
                                      color: AppColors.primary)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                petName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: !hasCollar
                                    ? const Color(0xFFFEF3C7)
                                    : (isGpsActive
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFFEE2E2)),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                !hasCollar
                                    ? 'Unpaired'
                                    : (isGpsActive
                                        ? 'Active'
                                        : 'Offline'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: !hasCollar
                                      ? const Color(0xFF92400E)
                                      : (isGpsActive
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFFB91C1C)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // GPS Offline Warning Notice
                        if (hasCollar && !isGpsActive) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_off_rounded,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'GPS Collar Offline',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'The collar is powered off or disconnected. Displaying the last known location recorded ${formatTimeAgo(lastUpdated)}.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Unpaired Prompt or Info Pills
                        if (!hasCollar) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.outlineVariant
                                    .withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.sensors_off_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No GPS Collar Attached',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Pair a collar (1 collar for 1 pet) to start tracking.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color:
                                              AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: onManageCollar,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Pair Collar'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          // Info pills
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _infoPill(
                                Icons.location_on,
                                pet['barangay'] ?? 'Unknown',
                              ),
                              _infoPill(
                                isGpsActive
                                    ? Icons.access_time
                                    : Icons.history_rounded,
                                isGpsActive
                                    ? formatTimeAgo(lastUpdated)
                                    : 'Seen ${formatTimeAgo(lastUpdated)}',
                              ),
                              _infoPill(
                                isGpsActive
                                    ? Icons.sensors_rounded
                                    : Icons.sensors_off_rounded,
                                isGpsActive
                                    ? 'Signal Live'
                                    : 'Signal Lost',
                              ),
                              if (battery > 0)
                                _infoPill(
                                  Icons.battery_full,
                                  '$battery%',
                                ),
                              InkWell(
                                onTap: onManageCollar,
                                borderRadius: BorderRadius.circular(999),
                                child: _infoPill(
                                  Icons.tag_rounded,
                                  currentCollarId!,
                                  trailingIcon: Icons.edit,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Coordinates
                          Text(
                            isGpsActive
                                ? 'Live Location Coordinates'
                                : 'Last Known Location Coordinates',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lat != null && lon != null
                                ? 'Lat: ${lat!.toStringAsFixed(6)}, Lon: ${lon!.toStringAsFixed(6)}'
                                : 'Waiting for GPS signal…',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: onReportLost,
                                icon: const Icon(
                                    Icons.warning_amber_rounded),
                                label: const Text('Report as Lost'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onShare,
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
