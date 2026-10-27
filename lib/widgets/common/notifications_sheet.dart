import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/time_utils.dart';
import '../../services/alerts/alert_service.dart';
import '../../services/auth/auth_service.dart';
import 'photo_placeholder.dart';

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
    final isAiSighting = rawMessage.contains('AI Sighting Match') ||
        rawMessage.contains('AI SIGHTING MATCH');

    // For AI sighting alerts, display rich side-by-side comparison modal
    if (isAiSighting && mounted) {
      _showAiSightingModal(context, alert);
      return;
    }

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

  String? _extractSightingPhotoUrl(String raw) {
    final match = RegExp(r'\[Sighting Photo\]:\s*([^\s\]]+)').firstMatch(raw);
    return match?.group(1);
  }

  String? _extractFinderNote(String raw) {
    final match =
        RegExp(r'\[Finder Note(?::|\]:)\s*([^\]]+)').firstMatch(raw);
    return match?.group(1)?.trim();
  }

  String? _extractScannerContact(String raw) {
    final match =
        RegExp(r'\[Scanner Contact(?::|\]:)\s*([^\]]+)').firstMatch(raw);
    return match?.group(1)?.trim();
  }

  int? _extractSimilarityPercent(String raw) {
    final match = RegExp(r'\((\d+)%\)').firstMatch(raw);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  Future<void> _makeCall(BuildContext context, String contact) async {
    final phoneDigits = contact.replaceAll(RegExp(r'[^\d+]'), '');
    if (phoneDigits.length >= 7) {
      final uri = Uri.parse('tel:$phoneDigits');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }
    final emailMatch = RegExp(r'[\w\.-]+@[\w\.-]+\.\w+').firstMatch(contact);
    if (emailMatch != null) {
      final uri = Uri.parse('mailto:${emailMatch.group(0)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }
  }

  String _cleanMessage(String raw) {
    String cleaned = raw;
    cleaned = cleaned.replaceAll('🎯', '').replaceAll('🐾', '').trim();
    if (cleaned.startsWith('URGENT: ')) {
      cleaned = cleaned.substring('URGENT: '.length);
    } else if (cleaned.startsWith('🚨 MISSING PET ALERT: ')) {
      cleaned = cleaned.substring('🚨 MISSING PET ALERT: '.length);
    }
    if (cleaned.contains('[Sighting Photo]:')) {
      cleaned = cleaned.split('[Sighting Photo]:').first.trim();
    }
    if (cleaned.contains('[Scanner Contact:')) {
      cleaned = cleaned.split('[Scanner Contact:').first.trim();
    }
    if (cleaned.contains('[Scanner Contact]:')) {
      cleaned = cleaned.split('[Scanner Contact]:').first.trim();
    }
    if (cleaned.contains('[Finder Note:')) {
      cleaned = cleaned.split('[Finder Note:').first.trim();
    }
    if (cleaned.contains('[Finder Note]:')) {
      cleaned = cleaned.split('[Finder Note]:').first.trim();
    }
    return cleaned.trim();
  }

  String _formatSentAt(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = TimeUtils.parseTimestamp(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
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
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  color: AppColors.onSurfaceVariant,
                  onPressed: _loadAlerts,
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
                            final isAiSighting =
                                rawMessage.contains('AI Sighting Match') ||
                                    rawMessage.contains('AI SIGHTING MATCH');
                            final sightingPhotoUrl = isAiSighting
                                ? _extractSightingPhotoUrl(rawMessage)
                                : null;
                            final scannerContact = isAiSighting
                                ? _extractScannerContact(rawMessage)
                                : null;
                            final finderNote = isAiSighting
                                ? _extractFinderNote(rawMessage)
                                : null;
                            final simPercent = isAiSighting
                                ? _extractSimilarityPercent(rawMessage)
                                : null;
                            final isLostPet = !isAiSighting &&
                                (alert['lost_report_id'] != null ||
                                    rawMessage.toLowerCase().contains('lost') ||
                                    rawMessage
                                        .toLowerCase()
                                        .contains('missing'));
                            final isNews = !isAiSighting &&
                                !isLostPet &&
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
                                    : isAiSighting
                                        ? const Color(0xFFF0FDF4)
                                        : const Color(0xFFFFFBF5),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isRead
                                      ? const Color(0xFFE2E8F0)
                                      : isAiSighting
                                          ? const Color(0xFF86EFAC)
                                          : const Color(0xFFFFD8B3),
                                  width: isRead ? 1 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isRead
                                        ? Colors.black.withOpacity(0.02)
                                        : isAiSighting
                                            ? const Color(0xFF10B981)
                                                .withOpacity(0.08)
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
                                              colors: isAiSighting
                                                  ? const [
                                                      Color(0xFF059669),
                                                      Color(0xFF10B981)
                                                    ]
                                                  : isLostPet
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
                                                color: (isAiSighting
                                                        ? const Color(
                                                            0xFF10B981)
                                                        : isLostPet
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
                                            isNews
                                                ? Icons.campaign_rounded
                                                : Icons.notifications_active_rounded,
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
                                                      color: isAiSighting
                                                          ? const Color(
                                                              0xFFECFDF5)
                                                          : isLostPet
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
                                                      isAiSighting
                                                          ? (simPercent != null
                                                              ? 'AI SIGHTING · $simPercent%'
                                                              : 'AI SIGHTING MATCH')
                                                          : isLostPet
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
                                                        color: isAiSighting
                                                            ? const Color(
                                                                0xFF059669)
                                                            : isLostPet
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
                                                          BoxDecoration(
                                                        color: isAiSighting
                                                            ? const Color(
                                                                0xFF10B981)
                                                            : const Color(
                                                                0xFFFF6600),
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

                                              // Sighting Photo Preview Card
                                              if (isAiSighting &&
                                                  sightingPhotoUrl != null &&
                                                  sightingPhotoUrl.isNotEmpty) ...[
                                                const SizedBox(height: 10),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    color: const Color(0xFFF1F5F9),
                                                    child: Row(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                          child: SizedBox(
                                                            width: 48,
                                                            height: 48,
                                                            child: Image.network(
                                                              sightingPhotoUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (_, __, ___) =>
                                                                  const PhotoPlaceholder(
                                                                width: 48,
                                                                height: 48,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Sighting Snapshot Captured',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 11.5,
                                                                  fontWeight:
                                                                      FontWeight.w700,
                                                                  color: const Color(
                                                                      0xFF0F172A),
                                                                ),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                'Tap to view visual comparison',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 10.5,
                                                                  fontWeight:
                                                                      FontWeight.w600,
                                                                  color: const Color(
                                                                      0xFF059669),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const Icon(
                                                          Icons.chevron_right_rounded,
                                                          color: Color(0xFF64748B),
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],

                                              // Finder / Scanner Contact badge
                                              if (isAiSighting &&
                                                  scannerContact != null &&
                                                  scannerContact.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    border: Border.all(
                                                        color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.person_pin_circle_rounded,
                                                        size: 16,
                                                        color: Color(0xFF1D4ED8),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          'Finder: $scannerContact',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: const Color(
                                                                0xFF1E3A8A),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              // Finder Note Quote
                                              if (isAiSighting &&
                                                  finderNote != null &&
                                                  finderNote.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 7),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF8FAFC),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    border: Border.all(
                                                        color: const Color(0xFFE2E8F0)),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      const Icon(
                                                        Icons.chat_bubble_outline_rounded,
                                                        size: 14,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          '"$finderNote"',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11.5,
                                                            fontStyle: FontStyle.italic,
                                                            color: const Color(0xFF334155),
                                                            height: 1.35,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              // Footer action for lost reports & AI sightings
                                              if (alert['lost_report_id'] !=
                                                      null ||
                                                  isAiSighting) ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: (isAiSighting
                                                                ? const Color(
                                                                    0xFF10B981)
                                                                : const Color(
                                                                    0xFFFF6600))
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
                                                            isAiSighting
                                                                ? 'Inspect Sighting Match'
                                                                : 'View Pet Report',
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: isAiSighting
                                                                  ? const Color(
                                                                      0xFF059669)
                                                                  : const Color(
                                                                      0xFFFF6600),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: 12,
                                                            color: isAiSighting
                                                                ? const Color(
                                                                    0xFF059669)
                                                                : const Color(
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

  void _showAiSightingModal(BuildContext context, Map<String, dynamic> alert) {
    final rawMessage = alert['message']?.toString() ?? '';
    final sightingPhotoUrl = _extractSightingPhotoUrl(rawMessage);
    final scannerContact = _extractScannerContact(rawMessage);
    final finderNote = _extractFinderNote(rawMessage);
    final simPercent = _extractSimilarityPercent(rawMessage);
    final cleanMsg = _cleanMessage(rawMessage);
    final lostReport = alert['lost_reports'] as Map<String, dynamic>?;
    final petMap = lostReport?['pets'] as Map<String, dynamic>?;
    final registeredPhotoUrl = petMap?['photo_url']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Glowing Header with AI Chip
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Sighting Match',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '${simPercent ?? 75}% Visual Match',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatSentAt(alert['sent_at']?.toString()),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Visual Photo Comparison (Registered vs Scanned Sighting)
              if (sightingPhotoUrl != null && sightingPhotoUrl.isNotEmpty) ...[
                Text(
                  'Visual Comparison',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Registered Photo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.surfaceContainerHigh,
                              border: Border.all(
                                  color: AppColors.surfaceContainerHigh),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: registeredPhotoUrl.isNotEmpty
                                ? Image.network(
                                    registeredPhotoUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) =>
                                        const PhotoPlaceholder(
                                      iconColor: AppColors.outline,
                                    ),
                                  )
                                : const PhotoPlaceholder(
                                    iconColor: AppColors.outline,
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Registered Photo',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Scanned Sighting Photo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFECFDF5),
                              border: Border.all(
                                  color: const Color(0xFF34D399), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF10B981).withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              sightingPhotoUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  const PhotoPlaceholder(
                                iconColor: Color(0xFF059669),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Scanned Sighting',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Alert Message Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  cleanMsg,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Finder Note Card if available
              if (finderNote != null && finderNote.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Note from Finder',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '"$finderNote"',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF78350F),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Scanner Contact Card if available
              if (scannerContact != null && scannerContact.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDBEAFE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.contact_phone_rounded,
                          color: Color(0xFF1D4ED8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scanner Contact',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                            Text(
                              scannerContact,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _makeCall(context, scannerContact),
                        icon: Icon(
                            scannerContact.contains('@') &&
                                    !scannerContact.contains(RegExp(r'\d{7}'))
                                ? Icons.email_rounded
                                : Icons.phone_rounded,
                            color: const Color(0xFF1D4ED8)),
                        tooltip: scannerContact.contains('@') &&
                                !scannerContact.contains(RegExp(r'\d{7}'))
                            ? 'Email Scanner'
                            : 'Call Scanner',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions: Close & View Lost Report
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (alert['lost_report_id'] != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(
                              context); // Close parent notifications sheet
                          Navigator.pushNamed(context, AppRoutes.lostPetScreen);
                        },
                        icon: const Icon(Icons.pets_rounded, size: 17),
                        label: Text(
                          'View Lost Report',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await AlertService.instance
                    .sendTestNotificationToCurrentUser();
                if (ok && mounted) {
                  _loadAlerts();
                }
              },
              icon: const Icon(Icons.notification_add_outlined, size: 16),
              label: const Text('Send Test Alert'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
