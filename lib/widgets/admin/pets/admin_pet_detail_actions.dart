import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Action buttons for Pet Detail (Contact Owner, View Map, Repost/Broadcast button, Archived banner)
class AdminPetDetailActions extends StatelessWidget {
  final Map<String, dynamic> pet;
  final bool isUpdating;
  final VoidCallback onContactOwner;
  final VoidCallback onViewMap;
  final VoidCallback onBroadcastLostPet;
  final VoidCallback onEditArchiveReason;
  final VoidCallback? onViewAuditLogs;

  const AdminPetDetailActions({
    super.key,
    required this.pet,
    required this.isUpdating,
    required this.onContactOwner,
    required this.onViewMap,
    required this.onBroadcastLostPet,
    required this.onEditArchiveReason,
    this.onViewAuditLogs,
  });

  @override
  Widget build(BuildContext context) {
    final rawStatus = (pet['status'] ?? 'active').toString().toLowerCase().trim();
    final isArchived = rawStatus == 'archived';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onContactOwner,
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      size: 19, color: AppColors.primary),
                  label: Text(
                    'Contact Owner',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.06),
                    side: BorderSide(
                      color: AppColors.primary.withOpacity(0.22),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onViewMap,
                  icon: const Icon(Icons.location_on_rounded,
                      size: 19, color: Colors.white),
                  label: Text(
                    'View Map',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.primary.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (onViewAuditLogs != null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onViewAuditLogs,
              icon: const Icon(Icons.history_rounded,
                  size: 20, color: Color(0xFF0F766E)),
              label: Text(
                'View Modification Audit Logs',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F766E),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF0FDFA),
                side: const BorderSide(color: Color(0xFF99F6E4), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (isArchived) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.archive_outlined,
                    color: Color(0xFF475569),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Archived Pet Record',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ARCHIVED',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This pet has been removed by the owner and archived. Historical reports, telemetry, and biometrics remain safely preserved.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      if ((pet['archive_reason'] ?? pet['reason'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Reason: ${(pet['archive_reason'] ?? pet['reason'] ?? '').toString().trim()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onEditArchiveReason,
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          (pet['archive_reason'] ?? pet['reason'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty
                              ? 'Change Archive Reason'
                              : 'Set Archive Reason',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(
                              color: Color(0xFFCBD5E1), width: 1.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
