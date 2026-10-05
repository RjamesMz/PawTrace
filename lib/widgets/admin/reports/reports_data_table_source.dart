import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../widgets/common/photo_placeholder.dart';

/// DataTableSource for AdminReportsScreen on desktop web.
class ReportsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> reports;
  final void Function(Map<String, dynamic> report)? onViewReport;

  ReportsDataTableSource(this.reports, {this.onViewReport});

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

    final location = report['last_seen_address']?.toString() ??
        report['barangay']?.toString() ??
        '-';
    final reportedAt = report['reported_at']?.toString() ?? '';
    final petStatus =
        pet is Map ? (pet['status']?.toString() ?? '').toLowerCase() : '';
    final reportStatus =
        (report['status']?.toString() ?? 'active').toLowerCase();

    // Determine Pet Condition: LOST or FOUND
    String petCondition = (report['outcome'] ??
            report['pet_status'] ??
            report['condition'] ??
            '')
        .toString()
        .toUpperCase();
    if (petCondition != 'FOUND' && petCondition != 'LOST') {
      final bool isFound = reportStatus == 'resolved' ||
          reportStatus == 'found' ||
          reportStatus == 'archived' ||
          report['is_found'] == true ||
          report['found_at'] != null ||
          (petStatus == 'active' && reportStatus == 'archived') ||
          petStatus == 'found';
      petCondition = isFound ? 'FOUND' : 'LOST';
    }

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
        // Pet Status Chip (LOST or FOUND)
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
        // Archive Status Chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: reportStatus == 'archived'
                  ? const Color(0xFF64748B).withOpacity(0.15)
                  : const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              reportStatus == 'archived' ? 'ARCHIVED' : 'ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: reportStatus == 'archived'
                    ? const Color(0xFF475569)
                    : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ),
        // Action
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility_outlined,
                size: 18, color: AppColors.primary),
            tooltip: 'View Details',
            onPressed: () => onViewReport?.call(report),
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
