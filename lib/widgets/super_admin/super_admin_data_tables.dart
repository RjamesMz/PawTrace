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
