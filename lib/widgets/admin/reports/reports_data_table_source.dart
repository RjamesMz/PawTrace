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
        // Date Reported
        DataCell(Text(
          formattedDate,
          style: GoogleFonts.inter(fontSize: 13),
        )),
        // Time Reported
        DataCell(Text(
          formattedTime,
          style: GoogleFonts.inter(fontSize: 13),
        )),
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

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => reports.length;

  @override
  int get selectedRowCount => 0;
}
