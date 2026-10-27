import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/audit/user_audit_service.dart';

/// Displays a modal dialog with the chronological audit and modification history for a user account.
Future<void> showUserAuditLogDialog(
  BuildContext context,
  Map<String, dynamic> user,
) async {
  final userId = (user['user_id'] ?? user['id'] ?? '').toString();
  final fName = (user['first_name'] ?? '').toString().trim();
  final lName = (user['surname'] ?? '').toString().trim();
  final fullName = [fName, lName].where((s) => s.isNotEmpty).join(' ');
  final userName = fullName.isNotEmpty ? fullName : (user['email'] ?? 'User').toString();

  await showDialog<void>(
    context: context,
    builder: (ctx) => _UserAuditLogDialog(user: user, userId: userId, userName: userName),
  );
}

class _UserAuditLogDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final String userId;
  final String userName;

  const _UserAuditLogDialog({
    required this.user,
    required this.userId,
    required this.userName,
  });

  @override
  State<_UserAuditLogDialog> createState() => _UserAuditLogDialogState();
}

class _UserAuditLogDialogState extends State<_UserAuditLogDialog> {
  late Future<List<UserAuditLog>> _logsFuture;
  List<UserAuditLog> _cachedLogs = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    _logsFuture = UserAuditService.instance
        .fetchLogsForUser(widget.userId, userData: widget.user)
        .then((logs) {
      _cachedLogs = logs;
      return logs;
    });
  }

  Future<void> _export() async {
    if (_cachedLogs.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      await UserAuditService.instance.exportAuditLogsToExcel(
        context,
        widget.userName,
        _cachedLogs,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $period';
  }

  IconData _iconForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('created') || lower.contains('register')) return Icons.how_to_reg_rounded;
    if (lower.contains('photo')) return Icons.camera_alt_rounded;
    if (lower.contains('email')) return Icons.alternate_email_rounded;
    if (lower.contains('password')) return Icons.lock_reset_rounded;
    if (lower.contains('address')) return Icons.location_on_rounded;
    if (lower.contains('status') || lower.contains('deactivate')) return Icons.verified_user_rounded;
    if (lower.contains('role')) return Icons.admin_panel_settings_rounded;
    return Icons.manage_accounts_rounded;
  }

  Color _colorForAction(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('deactivate')) return const Color(0xFFDC2626);
    if (lower.contains('password')) return const Color(0xFFD97706);
    if (lower.contains('created') || lower.contains('register')) return const Color(0xFF2563EB);
    if (lower.contains('photo') || lower.contains('email')) return const Color(0xFF0F766E);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photoUrl = user['photo_url']?.toString() ?? '';
    final email = user['email']?.toString() ?? 'No email';
    final role = (user['role'] ?? 'user').toString().toUpperCase();

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
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
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
                                widget.userName,
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
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Dialog Content: Audit Trail ────────────────────────────
            Expanded(
              child: FutureBuilder<List<UserAuditLog>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No modification logs recorded yet.',
                            style: GoogleFonts.inter(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final actionColor = _colorForAction(log.action);
                      final actionIcon = _iconForAction(log.action);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: actionColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(actionIcon, size: 16, color: actionColor),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log.action,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTimestamp(log.timestamp),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              log.changesSummary,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF374151),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Modified by: ${log.modifiedBy} (${log.modifierRole})',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
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

            // ── Dialog Footer ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isExporting ? null : _export,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
