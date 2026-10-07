import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../core/app_colors.dart';
import '../../../services/audit/pet_audit_service.dart';
import '../../../services/export/file_export_service.dart';

/// Helper to export filtered pets to an Excel (.xlsx) file.
class PetsExportService {
  static Future<void> exportPetsToExcel(
    BuildContext context,
    List<Map<String, dynamic>> pets,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Pets Registry'];
      excel.delete('Sheet1'); // Remove default sheet

      // ── Header row ──────────────────────────────────────────────
      const headers = [
        'Pet Name',
        'Species',
        'Breed',
        'Color',
        'Weight (kg)',
        'Owner Name',
        'Owner Phone',
        'Owner Email',
        'Barangay',
        'Collar ID',
        'Status',
        'Archive Reason',
        'Date Registered',
        'Last Modified',
      ];
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1D6F42'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidth(c, c == 11 ? 28 : (c == 0 ? 22 : 18));
      }

      // ── Data rows ────────────────────────────────────────────────
      for (var r = 0; r < pets.length; r++) {
        final p = pets[r];
        final petName = (p['name'] ?? '').toString();
        final species = (p['species'] ?? '').toString();
        final breed = (p['breed'] ?? '').toString();
        final color = (p['color'] ?? '').toString();
        final weight = (p['weight'] ?? '').toString();

        final u = p['users'];
        final ownerName = u is Map
            ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(' ')
            : 'Unknown';
        final phone = u is Map ? (u['phone']?.toString() ?? '') : '';
        final email = u is Map ? (u['email']?.toString() ?? '') : '';
        final barangay =
            (p['barangay'] ?? (u is Map ? u['barangay'] : '') ?? '')
                .toString();
        final collarId = (p['gps_id'] ?? '-').toString();

        final rawStatus = (p['status'] ?? 'active').toString().toLowerCase();
        final statusDisplay = rawStatus.toUpperCase();

        String archiveReason = 'N/A';
        if (rawStatus == 'archived') {
          final explicitReason = (p['archive_reason'] ??
                  p['archived_reason'] ??
                  p['reason'] ??
                  p['removal_reason'])
              ?.toString()
              .trim();
          if (explicitReason != null && explicitReason.isNotEmpty) {
            archiveReason = explicitReason;
          } else {
            archiveReason = 'Unspecified';
          }
        }

        String dateStr = '';
        final rawDate = p['created_at']?.toString() ?? '';
        if (rawDate.isNotEmpty) {
          try {
            final dt = DateTime.parse(rawDate).toLocal();
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
            dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
          } catch (_) {
            dateStr = rawDate;
          }
        }

        String modifiedStr = 'None yet';
        var rawModified = p['updated_at'] ?? p['modified_at'];
        final pid = (p['pet_id'] ?? p['id'] ?? '').toString();
        if (rawModified == null ||
            rawModified.toString().trim().isEmpty ||
            rawModified.toString() == rawDate) {
          final localAudit = PetAuditService.getLatestModificationForPet(pid);
          if (localAudit != null) {
            rawModified = localAudit.timestamp.toIso8601String();
          }
        }
        if (rawModified != null &&
            rawModified.toString().trim().isNotEmpty &&
            rawModified.toString() != rawDate) {
          try {
            final dt = DateTime.parse(rawModified.toString()).toLocal();
            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            modifiedStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
          } catch (_) {
            modifiedStr = rawModified.toString();
          }
        }

        final rowData = [
          petName,
          species,
          breed,
          color,
          weight,
          ownerName,
          phone,
          email,
          barangay,
          collarId,
          statusDisplay,
          archiveReason,
          dateStr,
          modifiedStr,
        ];

        final rowStyle = CellStyle(
          backgroundColorHex: r.isEven
              ? ExcelColor.fromHexString('#FFFFFF')
              : ExcelColor.fromHexString('#F0FDF4'),
        );

        for (var c = 0; c < rowData.length; c++) {
          final cell = sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          cell.value = TextCellValue(rowData[c]);
          cell.cellStyle = rowStyle;
        }
      }

      final bytes = excel.encode()!;
      final now = DateTime.now();
      final filename =
          'pets_registry_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';

      await saveAndShareFile(bytes, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported $filename successfully.',
              style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF1D6F42),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }
}
