import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Top floating navigation and status controls for Locate Pet Screen
class LocatePetTopControls extends StatelessWidget {
  final bool hasCollar;
  final bool isGpsActive;
  final bool isHistoryMode;
  final VoidCallback onBack;
  final VoidCallback onManageCollar;
  final VoidCallback? onToggleHistory;

  const LocatePetTopControls({
    super.key,
    required this.hasCollar,
    required this.isGpsActive,
    this.isHistoryMode = false,
    required this.onBack,
    required this.onManageCollar,
    this.onToggleHistory,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Stack(
      children: [
        // Back Button
        Positioned(
          top: topPadding,
          left: 12,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
        ),

        // Status or Toggle pill in center
        Positioned(
          top: topPadding,
          left: 58,
          right: 58,
          child: Center(
            child: onToggleHistory != null
                ? Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Live tab
                        GestureDetector(
                          onTap: isHistoryMode ? onToggleHistory : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: !isHistoryMode
                                  ? (!hasCollar
                                      ? const Color(0xFFF59E0B)
                                      : (isGpsActive
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFF475569)))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isHistoryMode)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(
                                  'Live',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: !isHistoryMode ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // History tab
                        GestureDetector(
                          onTap: !isHistoryMode ? onToggleHistory : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isHistoryMode ? const Color(0xFF6366F1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.route_rounded,
                                  size: 13,
                                  color: isHistoryMode ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'History',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isHistoryMode ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: !hasCollar
                          ? const Color(0xFFF59E0B)
                          : (isGpsActive
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF475569)),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!hasCollar)
                          const Icon(Icons.sensors_off_rounded,
                              color: Colors.white, size: 14)
                        else if (isGpsActive)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const Icon(Icons.location_off_rounded,
                              color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            !hasCollar
                                ? 'No Collar Paired'
                                : (isGpsActive
                                    ? 'Live Tracking'
                                    : 'GPS Offline • Last Known'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Manage Collar button
        Positioned(
          top: topPadding,
          right: 12,
          child: GestureDetector(
            onTap: onManageCollar,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(
                Icons.sensors_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating Re-center button on map
class LocatePetRecenterButton extends StatelessWidget {
  final double bottomOffset;
  final VoidCallback onRecenter;

  const LocatePetRecenterButton({
    super.key,
    required this.bottomOffset,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      bottom: bottomOffset,
      right: 14,
      child: GestureDetector(
        onTap: onRecenter,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: const Icon(
            Icons.my_location,
            size: 22,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Floating History Toggle button on map
class LocatePetHistoryToggleButton extends StatelessWidget {
  final double bottomOffset;
  final bool isHistoryMode;
  final VoidCallback onToggle;

  const LocatePetHistoryToggleButton({
    super.key,
    required this.bottomOffset,
    required this.isHistoryMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      bottom: bottomOffset,
      right: 14,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHistoryMode ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (isHistoryMode ? const Color(0xFF6366F1) : Colors.black)
                    .withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Icon(
            Icons.route_rounded,
            size: 22,
            color: isHistoryMode ? Colors.white : const Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }
}
