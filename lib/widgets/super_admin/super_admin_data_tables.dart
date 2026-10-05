import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../widgets/common/photo_placeholder.dart';

/// DataTableSource for Recent Lost Reports in SuperAdmin web dashboard.
class RecentReportsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> reports;

  RecentReportsDataTableSource(this.reports);

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

    final location = report['barangay']?.toString() ??
        report['municipality']?.toString() ??
        'Catanduanes';
    final reportedAt = report['reported_at']?.toString() ?? '';
    final reportStatus =
        (report['status']?.toString() ?? 'active').toLowerCase();
    final petStatus =
        pet is Map ? (pet['status']?.toString() ?? '').toLowerCase() : '';

    final bool isFound = reportStatus == 'resolved' ||
        reportStatus == 'found' ||
        report['is_found'] == true ||
        (petStatus == 'active' && reportStatus == 'archived') ||
        petStatus == 'found';
    final String petCondition = isFound ? 'FOUND' : 'LOST';

    String formattedDate = '';
    String formattedTime = '';
    if (reportedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(reportedAt).toLocal();
        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
        final hour =
            dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
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
        DataCell(Text(
          petName,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        )),
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

/// DataTableSource for Barangay Admins in SuperAdmin web dashboard.
class AdminsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> admins;
  final Function(String userId, String email, bool isDeactivated) onToggleStatus;

  AdminsDataTableSource(this.admins, {required this.onToggleStatus});

  @override
  DataRow? getRow(int index) {
    if (index >= admins.length) return null;
    final admin = admins[index];

    final fName = admin['first_name'] as String? ?? '';
    final sName = admin['surname'] as String? ?? '';
    final email = admin['email'] as String? ?? '';
    final phone = admin['phone'] as String? ?? '';
    final barangay = admin['barangay'] as String? ?? '';
    final userId = admin['user_id'] as String? ?? '';
    final initial = fName.isNotEmpty ? fName[0].toUpperCase() : 'A';
    final rawStatus = (admin['status'] ?? 'active').toString().toLowerCase();
    final isDeactivated =
        rawStatus == 'deactivated' || rawStatus == 'de_activated';

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              initial,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        DataCell(Text(
          '$fName $sName',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        )),
        DataCell(Text(email.isNotEmpty ? email : '-')),
        DataCell(Text(phone.isNotEmpty ? phone : '-')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              barangay.isNotEmpty ? barangay : '-',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Status Column
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDeactivated
                  ? const Color(0xFFEF4444).withOpacity(0.15)
                  : const Color(0xFF22C55E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isDeactivated ? 'DEACTIVATED' : 'ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDeactivated
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
              ),
            ),
          ),
        ),
        // Actions Column
        DataCell(
          IconButton(
            tooltip: isDeactivated ? 'Reactivate Admin' : 'Deactivate Admin',
            icon: Icon(
              isDeactivated
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              color: isDeactivated
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
              size: 20,
            ),
            onPressed: () => onToggleStatus(userId, email, isDeactivated),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => admins.length;

  @override
  int get selectedRowCount => 0;
}
