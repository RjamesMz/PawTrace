import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../services/geo/pet_tracking_history_service.dart';

/// Bottom history sheet showing the pet's tracking timeline, daily summary, and date selector
class LocatePetHistoryPanel extends StatelessWidget {
  final String petName;
  final String collarId;
  final DateTime selectedDate;
  final PetDailyTrack? dailyTrack;
  final bool isLoading;
  final bool isMinimized;
  final double height;
  final VoidCallback onClose;
  final VoidCallback onToggleMinimize;
  final ValueChanged<double> onDragEnd;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<PetTrackSegment> onSelectSegment;
  final PetTrackSegment? selectedSegment;

  const LocatePetHistoryPanel({
    super.key,
    required this.petName,
    required this.collarId,
    required this.selectedDate,
    required this.dailyTrack,
    required this.isLoading,
    required this.isMinimized,
    required this.height,
    required this.onClose,
    required this.onToggleMinimize,
    required this.onDragEnd,
    required this.onSelectDate,
    required this.onSelectSegment,
    this.selectedSegment,
  });

  String _formatTimeRange(DateTime start, DateTime end) {
    final format = DateFormat('h:mma');
    final s = format.format(start).toLowerCase();
    final e = format.format(end).toLowerCase();
    return '$s – $e';
  }

  String _formatTimezoneOffset() {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return '(UTC$sign$hours:00) Local Time';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final dateDisplay = DateFormat('MMM d yyyy').format(selectedDate);
    final segments = dailyTrack?.segments ?? [];

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      bottom: 0,
      left: 0,
      right: 0,
      height: height,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            onDragEnd(details.primaryVelocity!);
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, -4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Clickable / Draggable Handle Bar ──
              InkWell(
                onTap: onToggleMinimize,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isMinimized) ...[
                // ── Minimized Summary Row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back, size: 20, color: AppColors.onSurface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: onToggleMinimize,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$petName's Collar",
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$dateDisplay • ${dailyTrack?.formattedTotalDistance ?? '0 m'} • ${segments.length} stops',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 28, color: Color(0xFF4F46E5)),
                        onPressed: onToggleMinimize,
                        tooltip: 'Expand history',
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ── Header (Back / Close button + Title + Minimize icon) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back, size: 20, color: AppColors.onSurface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$petName's Collar",
                          style: GoogleFonts.montserrat(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.route_rounded, size: 14, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              'History Mode',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: Color(0xFF64748B)),
                        onPressed: onToggleMinimize,
                        tooltip: 'Drag down or tap to minimize',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 10, color: Color(0xFFF1F5F9)),

                // ── Date Selector & Timezone Bar (matches screenshot) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // Date Picker Pill
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            onSelectDate(picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                isToday ? 'Today ($dateDisplay)' : dateDisplay,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Timezone Pill
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            _formatTimezoneOffset(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Summary Metrics Bar (Distance, Active, Rest) ──
                if (dailyTrack != null && !isLoading)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricItem(
                          label: 'DISTANCE',
                          value: dailyTrack!.formattedTotalDistance,
                          icon: Icons.straighten_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                        _metricItem(
                          label: 'ACTIVE TIME',
                          value: dailyTrack!.formattedActiveDuration,
                          icon: Icons.directions_walk_rounded,
                          color: const Color(0xFF16A34A),
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                        _metricItem(
                          label: 'STOPS / REST',
                          value: '${segments.where((s) => !s.isMoving).length} stops',
                          icon: Icons.hotel_rounded,
                          color: const Color(0xFFD97706),
                        ),
                      ],
                    ),
                  ),

                // ── Timeline List ──
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : segments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.route_outlined, size: 36, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No tracking points recorded on $dateDisplay',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              itemCount: segments.length,
                              itemBuilder: (context, index) {
                                final seg = segments[index];
                                final isSelected = selectedSegment == seg;
                                final isLast = index == segments.length - 1;

                                return InkWell(
                                  onTap: () => onSelectSegment(seg),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEEF2FF)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(color: const Color(0xFF6366F1).withOpacity(0.5))
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left indicator dot + connector line
                                        Column(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: seg.isMoving
                                                    ? const Color(0xFF22C55E)
                                                    : const Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (seg.isMoving
                                                            ? const Color(0xFF22C55E)
                                                            : const Color(0xFF10B981))
                                                        .withOpacity(0.4),
                                                    blurRadius: 4,
                                                  )
                                                ],
                                              ),
                                            ),
                                            if (!isLast)
                                              Container(
                                                width: 2,
                                                height: 48,
                                                color: const Color(0xFFCBD5E1),
                                                margin: const EdgeInsets.symmetric(vertical: 2),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),

                                        // Activity Icon
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: seg.isMoving
                                                ? const Color(0xFFE0E7FF)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            seg.isMoving
                                                ? Icons.pets_rounded
                                                : Icons.hotel_rounded,
                                            size: 15,
                                            color: seg.isMoving
                                                ? const Color(0xFF4F46E5)
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Details: Metrics & Address
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      seg.isMoving
                                                          ? '${seg.formattedDistance} • ${seg.formattedDuration}'
                                                          : '${seg.formattedDuration} • ${seg.stepCount} steps',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTimeRange(seg.startTime, seg.endTime),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 12,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      seg.address,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11.5,
                                                        color: const Color(0xFF475569),
                                                        height: 1.25,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
