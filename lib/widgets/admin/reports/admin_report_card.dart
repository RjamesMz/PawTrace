import 'package:flutter/material.dart';
import 'admin_report_image_banner.dart';
import 'admin_report_details_content.dart';

export 'admin_report_image_banner.dart';
export 'admin_report_details_content.dart';

/// Card widget for displaying an incident report in AdminReportsScreen.
/// Supports both side-by-side layout (desktop / dialog) and stacked layout (mobile).
class AdminReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isDialog;
  final VoidCallback? onClose;

  const AdminReportCard({
    super.key,
    required this.report,
    this.isDialog = false,
    this.onClose,
  });

  static String formatDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '-';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '-';
    }
  }

  static String formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '-';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '$hour:$minute $period';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final petData = report['pets'] as Map<String, dynamic>?;
    final userData = report['owner_id'] is Map<String, dynamic>
        ? report['owner_id'] as Map<String, dynamic>
        : null;

    final petName = petData?['name'] as String? ?? 'Unknown Pet';
    final breed = petData?['breed'] as String? ?? 'Unknown Breed';
    final species = petData?['species'] as String? ?? '';
    final gender = petData?['gender'] as String? ?? '';
    final imageUrl =
        report['photo_url'] as String? ?? petData?['photo_url'] as String? ?? '';
    final location = report['last_seen_address'] as String? ??
        report['barangay'] as String? ??
        'Calatagan';
    final status = (report['status'] ?? 'active').toString().toLowerCase();
    final isArchived = status == 'archived' || status == 'resolved';
    final petStatus = petData?['status']?.toString().toLowerCase() ?? '';

    String petCondition = (report['outcome'] ??
            report['pet_status'] ??
            report['condition'] ??
            '')
        .toString()
        .toUpperCase();
    if (petCondition != 'FOUND' && petCondition != 'LOST') {
      final bool isFound = status == 'resolved' ||
          status == 'found' ||
          status == 'archived' ||
          report['is_found'] == true ||
          report['found_at'] != null ||
          (petStatus == 'active' && status == 'archived') ||
          petStatus == 'found';
      petCondition = isFound ? 'FOUND' : 'LOST';
    }
    final note = report['description'] as String? ?? '';

    final ownerName = userData != null
        ? [
            userData['first_name'],
            userData['middle_name'],
            userData['surname'],
            userData['suffix']
          ]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(' ')
        : 'Unknown Owner';

    final ownerPhone = userData?['phone']?.toString() ?? '';
    final ownerEmail = userData?['email']?.toString() ?? '';
    final isFound = petCondition == 'FOUND';

    final petSubtitles = [
      if (breed.isNotEmpty) breed,
      if (species.isNotEmpty) species,
      if (gender.isNotEmpty) gender,
    ].join(' • ');

    return LayoutBuilder(
      builder: (context, constraints) {
        // If width >= 580 or isDialog on wide screen, render side-by-side
        final useSideBySide = constraints.maxWidth >= 580 ||
            (isDialog && MediaQuery.of(context).size.width >= 650);

        final detailsContent = AdminReportDetailsContent(
          petName: petName,
          petSubtitles: petSubtitles,
          location: location,
          reportedAt: report['reported_at']?.toString(),
          ownerName: ownerName,
          ownerPhone: ownerPhone,
          ownerEmail: ownerEmail,
          note: note,
          isDialog: isDialog,
          onClose: onClose,
          formatDate: formatDate,
          formatTime: formatTime,
        );

        final imageBanner = AdminReportImageBanner(
          imageUrl: imageUrl,
          petCondition: petCondition,
          status: status,
          isArchived: isArchived,
          isFound: isFound,
          onClose: onClose,
          isSideBySide: useSideBySide,
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: useSideBySide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: detailsContent,
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: imageBanner,
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imageBanner,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: detailsContent,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
