import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/audit/pet_audit_service.dart';

/// Shows the administrative modal dialog displaying the modification history and audit log for a pet.
Future<void> showPetAuditLogDialog(
  BuildContext context,
  Map<String, dynamic> pet,
) async {
  final petId = (pet['pet_id'] ?? pet['id'] ?? '').toString();
  final petName = (pet['name'] ?? 'Pet').toString();

  await showDialog<void>(
    context: context,
    builder: (ctx) => _PetAuditLogDialog(pet: pet, petId: petId, petName: petName),
  );
}

class _PetAuditLogDialog extends StatefulWidget {
  final Map<String, dynamic> pet;
  final String petId;
  final String petName;

  const _PetAuditLogDialog({
    required this.pet,
    required this.petId,
    required this.petName,
  });

  @override
  State<_PetAuditLogDialog> createState() => _PetAuditLogDialogState();
}

class _PetAuditLogDialogState extends State<_PetAuditLogDialog> {
  late Future<List<PetAuditLog>> _logsFuture;
  List<PetAuditLog> _cachedLogs = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    _logsFuture = PetAuditService.instance
        .fetchLogsForPet(widget.petId, petData: widget.pet)
        .then((logs) {
      _cachedLogs = logs;
      return logs;
    });
  }

  Future<void> _export() async {
    if (_cachedLogs.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      await PetAuditService.instance.exportAuditLogsToExcel(
        context,
        widget.petName,
        _cachedLogs,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $period';
  }

  IconData _iconForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('register')) return Icons.app_registration_rounded;
    if (lower.contains('lost')) return Icons.warning_amber_rounded;
    if (lower.contains('active') || lower.contains('found')) {
      return Icons.check_circle_rounded;
    }
    if (lower.contains('archive')) return Icons.archive_outlined;
    if (lower.contains('collar')) return Icons.sensors_rounded;
    if (lower.contains('photo')) return Icons.camera_alt_rounded;
    return Icons.edit_note_rounded;
  }

  Color _colorForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('lost')) return const Color(0xFFDC2626);
    if (lower.contains('active') || lower.contains('found')) {
      return const Color(0xFF16A34A);
    }
    if (lower.contains('archive')) return const Color(0xFF475569);
    if (lower.contains('register')) return const Color(0xFF2563EB);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final photoUrl = pet['photo_url']?.toString() ?? '';
    final breed = pet['breed']?.toString() ?? 'Breed';
    final species = pet['species']?.toString() ?? 'Pet';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: AppColors.surfaceContainerHigh,
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.pets,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            )
                          : const Icon(Icons.pets,
                              color: AppColors.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.petName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$species • $breed',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Modification History & Audit Log',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Sub-header Actions (Export Button) ─────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.history_toggle_off_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Audit Trail Records',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _export,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.file_download_outlined, size: 16),
                    label: Text(
                      _isExporting ? 'Exporting...' : 'Export Log (.xlsx)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── Logs List Body ─────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<PetAuditLog>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load modification logs: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.onSurfaceVariant.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No modification logs recorded yet',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Any edits made by the owner or admin will be logged here.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final actionColor = _colorForAction(log.action);
                      final actionIcon = _iconForAction(log.action);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: actionColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(actionIcon,
                                      size: 18, color: actionColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.action,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTimestamp(log.timestamp),
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    log.modifierRole.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF475569),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFF1F5F9)),
                              ),
                              child: Text(
                                log.changesSummary,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 13, color: AppColors.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  'By: ${log.modifiedBy}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
