import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/admin/admin_analytics_service.dart';
import '../../../widgets/common/photo_placeholder.dart';

/// DataTableSource for AdminReportsScreen on desktop web.
class ReportsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> reports;
  final void Function(Map<String, dynamic> report)? onViewReport;
  final void Function(Map<String, dynamic> report)? onViewMap;

  ReportsDataTableSource(this.reports, {this.onViewReport, this.onViewMap});

  @override
  DataRow? getRow(int index) {
    if (index >= reports.length) return null;
    final report = reports[index];

    final pet = report['pets'];
    final petName = pet is Map
        ? (pet['name']?.toString() ?? 'Unknown Pet')
        : 'Unknown Pet';
    final petPhoto = pet is Map ? (pet['photo_url']?.toString() ?? '') : '';

    final owner = report['owner_id'];
    final ownerName = owner is Map
        ? '${owner['first_name'] ?? ''} ${owner['surname'] ?? ''}'.trim()
        : 'Unknown Owner';

    final rawLocation = report['last_seen_address']?.toString() ??
        report['barangay']?.toString() ??
        '-';
    final cleanLocation = rawLocation
        .replaceAll(RegExp(r'\s*\(?Lat:\s*[-\d.]+,\s*Lng:\s*[-\d.]+\)?', caseSensitive: false), '')
        .trim();
    final location = cleanLocation.isNotEmpty
        ? cleanLocation
        : (report['barangay']?.toString() ?? '-');
    final reportedAt = report['reported_at']?.toString() ?? '';

    // Determine Pet Condition: LOST or FOUND
    final bool isFound = AdminAnalyticsService.isReportFound(report);
    final String petCondition = isFound ? 'FOUND' : 'LOST';

    String formattedDate = '';
    String formattedTime = '';
    if (reportedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(reportedAt).toLocal();
        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
        final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour < 12 ? 'AM' : 'PM';
        formattedTime = '$hour:$minute $period';
      } catch (_) {
        formattedDate = reportedAt;
      }
    }

    // Found Date & Time resolution
    String formattedFoundDate = '';
    String formattedFoundTime = '';
    if (isFound) {
      String? rawFound = report['found_at']?.toString() ??
          report['resolved_at']?.toString() ??
          report['updated_at']?.toString() ??
          report['archived_at']?.toString();
      if (rawFound == null && pet is Map) {
        rawFound = pet['updated_at']?.toString() ??
            pet['modified_at']?.toString() ??
            pet['found_at']?.toString();
      }
      // If no explicit resolution timestamp, fallback to reported_at / created_at
      rawFound ??= report['reported_at']?.toString() ??
          report['created_at']?.toString();

      if (rawFound != null && rawFound.isNotEmpty) {
        try {
          final dt = DateTime.parse(rawFound).toLocal();
          formattedFoundDate = '${dt.month}/${dt.day}/${dt.year}';
          final hour =
              dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
          final minute = dt.minute.toString().padLeft(2, '0');
          final period = dt.hour < 12 ? 'AM' : 'PM';
          formattedFoundTime = '$hour:$minute $period';
        } catch (_) {
          formattedFoundDate = rawFound;
        }
      }
    }

    String? foundPhotoUrl = isFound
        ? (report['found_photo_url']?.toString() ??
            (pet is Map ? pet['found_photo_url']?.toString() : null))
        : null;
    if (isFound && (foundPhotoUrl == null || foundPhotoUrl.isEmpty)) {
      final desc = (report['description'] ?? '').toString();
      final m = RegExp(r'\[Found Verification Photo\]:\s*(https?://[^\s]+)').firstMatch(desc);
      if (m != null) foundPhotoUrl = m.group(1);
    }

    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      onSelectChanged: (_) => onViewReport?.call(report),
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Photo 40x40
        DataCell(
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: petPhoto.isNotEmpty
                ? Image.network(
                    petPhoto,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const PhotoPlaceholder(
                      width: 40,
                      height: 40,
                      iconSize: 20,
                    ),
                  )
                : const PhotoPlaceholder(
                    width: 40,
                    height: 40,
                    iconSize: 20,
                  ),
          ),
        ),
        // Pet Name
        DataCell(
          InkWell(
            onTap: () => onViewReport?.call(report),
            borderRadius: BorderRadius.circular(4),
            child: Text(
              petName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Owner
        DataCell(Text(
          ownerName.isNotEmpty ? ownerName : '-',
          style: GoogleFonts.inter(fontSize: 13),
        )),
        // Location
        DataCell(Text(
          location,
          style: GoogleFonts.inter(fontSize: 13),
        )),
        // Date & Time Reported (Compressed)
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedDate.isNotEmpty ? formattedDate : '-',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (formattedTime.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Found Date & Time (New Column)
        DataCell(
          isFound
              ? Builder(
                  builder: (context) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedFoundDate.isNotEmpty ? formattedFoundDate : '-',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (formattedFoundTime.isNotEmpty)
                            Text(
                              formattedFoundTime,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          if (foundPhotoUrl != null && foundPhotoUrl.isNotEmpty) ...[
                            if (formattedFoundTime.isNotEmpty) const SizedBox(width: 5),
                            InkWell(
                              onTap: () => _showPhotoLightbox(context, foundPhotoUrl!, petName),
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFF16A34A).withOpacity(0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_rounded, size: 10, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Pic',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                )
              : Text(
                  '—',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
        // Status Chip (LOST or FOUND)
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: petCondition == 'FOUND'
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              petCondition,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: petCondition == 'FOUND'
                    ? const Color(0xFF16A34A)
                    : AppColors.error,
              ),
            ),
          ),
        ),
        // Action
        DataCell(
          Builder(
            builder: (context) {
              final collarId =
                  (pet is Map ? pet['gps_id'] : report['gps_id'])?.toString().trim() ?? '';
              final bool hasCollar = collarId.isNotEmpty &&
                  collarId.toUpperCase() != 'N/A' &&
                  collarId.toUpperCase() != 'NONE';
              final double? rLat = (report['last_seen_lat'] as num?)?.toDouble() ??
                  (pet is Map ? (pet['last_seen_lat'] as num?)?.toDouble() : null);
              final double? rLon = (report['last_seen_lon'] as num?)?.toDouble() ??
                  (pet is Map ? (pet['last_seen_lon'] as num?)?.toDouble() : null);
              final bool hasRegexCoords = RegExp(
                      r'Lat:\s*([-\d.]+),\s*Lng:\s*([-\d.]+)',
                      caseSensitive: false)
                  .hasMatch(rawLocation);
              final bool hasGps =
                  hasCollar || (rLat != null && rLon != null) || hasRegexCoords;

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 20, color: Color(0xFF64748B)),
                tooltip: 'Actions',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (action) {
                  if (action == 'view') {
                    onViewReport?.call(report);
                  } else if (action == 'map') {
                    onViewMap?.call(report);
                  } else if (action == 'found_photo' && foundPhotoUrl != null) {
                    _showPhotoLightbox(context, foundPhotoUrl, petName);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (foundPhotoUrl != null && foundPhotoUrl.isNotEmpty)
                    PopupMenuItem(
                      value: 'found_photo',
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Text(
                            'View Found Photo',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasGps && onViewMap != null)
                    PopupMenuItem(
                      value: 'map',
                      child: Row(
                        children: [
                          const Icon(Icons.map_outlined,
                              size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            'View Map',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static void _showPhotoLightbox(
      BuildContext context, String url, String petName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded,
                            size: 18, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Found Verification Photo',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Proof captured upon recovery of $petName',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Image
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            size: 40, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => reports.length;

  @override
  int get selectedRowCount => 0;
}
