import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../services/alerts/alert_service.dart';
import '../../services/auth/auth_service.dart';

/// Bottom sheet / modal dialog displaying notifications from the Supabase `alerts` table.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  /// Displays the notifications sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    if (isWide) {
      return showDialog(
        context: context,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SizedBox(
            width: 480,
            height: 600,
            child: NotificationsSheet(),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final alerts = await AlertService.instance.fetchUserAlerts();
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final success = await AlertService.instance.markAllAsRead();
    if (success && mounted) {
      setState(() {
        for (var a in _alerts) {
          a['is_read'] = true;
        }
      });
    }
  }

  Future<void> _onAlertTap(Map<String, dynamic> alert) async {
    final alertId = alert['alert_id'];
    final isRead = alert['is_read'] == true;

    if (!isRead) {
      await AlertService.instance.markAsRead(alertId);
      if (mounted) {
        setState(() {
          alert['is_read'] = true;
        });
      }
    }

    final lostReportId = alert['lost_report_id'];
    final rawMessage = alert['message']?.toString() ?? '';
    final isLostPet = lostReportId != null ||
        rawMessage.toLowerCase().contains('lost') ||
        rawMessage.toLowerCase().contains('missing');

    if (isLostPet && mounted) {
      final role = await AuthService.instance.getCurrentUserRole();
      if (!mounted) return;

      // Close sheet and navigate to lost pet details
      Navigator.pop(context);

      final isAdmin = role == UserRole.admin || role == UserRole.superAdmin;
      if (isAdmin) {
        // Extract pet name if available to filter the report list
        final lostReport = alert['lost_reports'] as Map<String, dynamic>?;
        final petMap = lostReport?['pets'] as Map<String, dynamic>?;
        final petName = petMap?['name']?.toString() ?? '';

        Navigator.pushNamed(
          context,
          AppRoutes.adminReports,
          arguments: {
            'reportId': lostReportId?.toString() ?? '',
            'searchQuery': petName,
          },
        );
      } else {
        Navigator.pushNamed(context, AppRoutes.lostPetScreen);
      }
    }
  }

  String _cleanMessage(String raw) {
    String cleaned = raw;
    if (cleaned.startsWith('URGENT: ')) {
      cleaned = cleaned.substring('URGENT: '.length);
    } else if (cleaned.startsWith('🚨 MISSING PET ALERT: ')) {
      cleaned = cleaned.substring('🚨 MISSING PET ALERT: '.length);
    }
    return cleaned.trim();
  }

  String _formatSentAt(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => a['is_read'] != true).length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Mark all as read',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.surfaceContainer),

          // Alerts List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _alerts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAlerts,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _alerts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final alert = _alerts[index];
                            final isRead = alert['is_read'] == true;
                            final rawMessage = alert['message']?.toString() ??
                                'Notification message';
                            final message = _cleanMessage(rawMessage);
                            final timeStr =
                                _formatSentAt(alert['sent_at']?.toString());
                            final isLostPet = alert['lost_report_id'] != null ||
                                rawMessage.toLowerCase().contains('lost') ||
                                rawMessage.toLowerCase().contains('missing');
                            final isNews = !isLostPet &&
                                (rawMessage.toLowerCase().contains('news') ||
                                    rawMessage
                                        .toLowerCase()
                                        .contains('bulletin') ||
                                    rawMessage
                                        .toLowerCase()
                                        .contains('community'));

                            return Container(
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.white
                                    : const Color(0xFFFFFBF5),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isRead
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFFFFD8B3),
                                  width: isRead ? 1 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isRead
                                        ? Colors.black.withOpacity(0.02)
                                        : const Color(0xFFFF6600)
                                            .withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _onAlertTap(alert),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Aesthetic Gradient Avatar
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isLostPet
                                                  ? const [
                                                      Color(0xFFFF7A00),
                                                      Color(0xFFFF9E44)
                                                    ]
                                                  : isNews
                                                      ? const [
                                                          Color(0xFF6366F1),
                                                          Color(0xFF8B5CF6)
                                                        ]
                                                      : const [
                                                          Color(0xFF0EA5E9),
                                                          Color(0xFF38BDF8)
                                                        ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isLostPet
                                                        ? const Color(
                                                            0xFFFF6600)
                                                        : isNews
                                                            ? const Color(
                                                                0xFF6366F1)
                                                            : const Color(
                                                                0xFF0EA5E9))
                                                    .withOpacity(0.28),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            isLostPet
                                                ? Icons.pets_rounded
                                                : isNews
                                                    ? Icons.campaign_rounded
                                                    : Icons
                                                        .notifications_active_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Top Row: Category micro-pill + Timestamp + Unread dot
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isLostPet
                                                          ? const Color(
                                                              0xFFFFF0E6)
                                                          : isNews
                                                              ? const Color(
                                                                  0xFFEEF2FF)
                                                              : const Color(
                                                                  0xFFF1F5F9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      isLostPet
                                                          ? 'LOST PET ALERT'
                                                          : isNews
                                                              ? 'COMMUNITY NEWS'
                                                              : 'NOTIFICATION',
                                                      style:
                                                          GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                        color: isLostPet
                                                            ? const Color(
                                                                0xFFFF6600)
                                                            : isNews
                                                                ? const Color(
                                                                    0xFF4F46E5)
                                                                : const Color(
                                                                    0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .access_time_rounded,
                                                        size: 12,
                                                        color: Colors
                                                            .grey.shade400,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        timeStr,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors
                                                              .grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (!isRead) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Color(0xFFFF6600),
                                                        shape:
                                                            BoxShape.circle,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              // Message Body
                                              Text(
                                                message,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: isRead
                                                      ? FontWeight.w400
                                                      : FontWeight.w600,
                                                  color:
                                                      const Color(0xFF1E293B),
                                                  height: 1.4,
                                                ),
                                              ),

                                              // Footer action for lost reports
                                              if (alert['lost_report_id'] !=
                                                  null) ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFFFF6600)
                                                            .withOpacity(0.08),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'View Pet Report',
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: const Color(
                                                                  0xFFFF6600),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          const Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: 12,
                                                            color: Color(
                                                                0xFFFF6600),
                                                          ),
                                                        ],
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
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 40,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Notifications',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You are all caught up! When new alerts or lost pet notices are posted, they will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
