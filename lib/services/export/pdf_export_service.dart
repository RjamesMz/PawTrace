import 'package:flutter/material.dart' as material;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../audit/pet_audit_service.dart';
import '../audit/user_audit_service.dart';
import 'file_export_service.dart';

class PdfExportService {
  /// Primary theme color for PDF headers
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF1D6F42); // Forest Green
  static const PdfColor primaryDark = PdfColor.fromInt(0xFF14532D);
  static const PdfColor primaryTeal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor accentOrange = PdfColor.fromInt(0xFFEA580C);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor zebraBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor lostRed = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor foundGreen = PdfColor.fromInt(0xFF16A34A);

  static void _showToast(
    material.BuildContext context,
    String message, {
    bool isError = false,
    material.Color? color,
  }) {
    if (!context.mounted) return;
    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(
        content: material.Text(message, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? AppColors.error : (color ?? const material.Color(0xFF1D6F42)),
        behavior: material.SnackBarBehavior.floating,
        shape:
            material.RoundedRectangleBorder(borderRadius: material.BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. LOST PET REPORTS PDF EXPORT
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<void> exportReportsToPdf(
    material.BuildContext context,
    List<Map<String, dynamic>> reports, {
    String dateFilterLabel = 'All Dates',
  }) async {
    try {
      final doc = pw.Document();
      final now = DateTime.now();
      final formattedNow = DateFormat('MMM d, yyyy h:mm a').format(now);

      const headers = [
        '#',
        'Pet Name',
        'Species / Breed',
        'Owner & Contact',
        'Barangay',
        'Reported At',
        'Found At',
        'Condition',
        'Status',
        'Where Last Seen',
      ];

      final dataRows = <List<String>>[];

      for (var r = 0; r < reports.length; r++) {
        final report = reports[r];
        final pet = report['pets'];
        final owner = report['owner_id'];

        final petName = pet is Map ? (pet['name']?.toString() ?? '-') : '-';
        final breed = pet is Map ? (pet['breed']?.toString() ?? '') : '';
        final species = pet is Map ? (pet['species']?.toString() ?? '') : '';
        final speciesBreed = [species, breed].where((s) => s.isNotEmpty).join(' - ');

        final ownerName = owner is Map
            ? [
                owner['first_name'],
                owner['middle_name'],
                owner['surname'],
                owner['suffix']
              ].where((s) => s != null && s.toString().isNotEmpty).join(' ')
            : 'Unknown';
        final phone = owner is Map ? (owner['phone']?.toString() ?? '') : '';
        final ownerContact = phone.isNotEmpty ? '$ownerName\n$phone' : ownerName;

        final barangay = report['barangay']?.toString() ?? '-';
        final reportStatus = (report['status']?.toString() ?? 'active').toLowerCase();

        final bool isFound = report['is_found'] == true ||
            reportStatus == 'resolved' ||
            reportStatus == 'found';
        final String petCondition = isFound ? 'FOUND' : 'LOST';
        final archiveStatus = reportStatus == 'archived' ? 'DE-ACTIVE' : 'ACTIVE';

        final lastSeenRaw = report['last_seen_address']?.toString() ?? '';
        final cleanLastSeen = lastSeenRaw
            .replaceAll(
                RegExp(r'\s*\(?Lat:\s*[-\d.]+,\s*Lng:\s*[-\d.]+\)?',
                    caseSensitive: false),
                '')
            .trim();
        final whereLastSeen = cleanLastSeen.isNotEmpty
            ? cleanLastSeen
            : (barangay.isNotEmpty && barangay != '-' ? barangay : '-');

        // Formatted dates
        String dateStr = '-';
        final raw = report['reported_at']?.toString() ?? '';
        if (raw.isNotEmpty) {
          try {
            final dt = AppConstants.parseLocalTime(raw);
            dateStr = DateFormat('MMM d, yyyy\nh:mm a').format(dt);
          } catch (_) {
            dateStr = raw;
          }
        }

        String foundDateStr = '-';
        if (isFound) {
          String? rawFound = report['found_at']?.toString() ??
              report['resolved_at']?.toString() ??
              report['updated_at']?.toString();
          if (rawFound == null && pet is Map) {
            rawFound = pet['updated_at']?.toString() ?? pet['modified_at']?.toString();
          }
          if (rawFound != null && rawFound.isNotEmpty) {
            try {
              final dt = AppConstants.parseLocalTime(rawFound);
              foundDateStr = DateFormat('MMM d, yyyy\nh:mm a').format(dt);
            } catch (_) {
              foundDateStr = rawFound;
            }
          }
        }

        dataRows.add([
          '${r + 1}',
          petName,
          speciesBreed.isNotEmpty ? speciesBreed : '-',
          ownerContact,
          barangay,
          dateStr,
          foundDateStr,
          petCondition,
          archiveStatus,
          whereLastSeen,
        ]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          header: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderLight, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'PetTrace',
                            style: pw.TextStyle(
                              color: primaryColor,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            '| Lost & Found Reports',
                            style: pw.TextStyle(
                              color: textDark,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date Filter: $dateFilterLabel  •  Generated: $formattedNow',
                        style: const pw.TextStyle(
                          color: textMuted,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'Total: ${reports.length} Reports',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: borderLight, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PetTrace Community-Driven Pet Protection • Official Generated Report',
                    style: const pw.TextStyle(color: textMuted, fontSize: 7.5),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(color: textMuted, fontSize: 7.5),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              border: pw.TableBorder.all(color: borderLight, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              headerHeight: 24,
              cellStyle: const pw.TextStyle(color: textDark, fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.center,
                8: pw.Alignment.center,
              },
              oddRowDecoration: const pw.BoxDecoration(color: zebraBg),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),  // #
                1: pw.FixedColumnWidth(70),  // Pet Name
                2: pw.FixedColumnWidth(85),  // Species / Breed
                3: pw.FixedColumnWidth(95),  // Owner & Phone
                4: pw.FixedColumnWidth(70),  // Barangay
                5: pw.FixedColumnWidth(65),  // Reported At
                6: pw.FixedColumnWidth(65),  // Found At
                7: pw.FixedColumnWidth(55),  // Condition
                8: pw.FixedColumnWidth(55),  // Status
                9: pw.FlexColumnWidth(),     // Where Last Seen
              },
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final dateCode = DateFormat('yyyyMMdd').format(now);
      final filename = 'lost_reports_$dateCode.pdf';

      await saveAndShareFile(bytes, filename);
      if (context.mounted) {
        _showToast(context, 'Exported PDF: $filename successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Export failed: $e', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. PET REGISTRY PDF EXPORT
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<void> exportPetsToPdf(
    material.BuildContext context,
    List<Map<String, dynamic>> pets, {
    String categoryLabel = 'All Pets',
  }) async {
    try {
      final doc = pw.Document();
      final now = DateTime.now();
      final formattedNow = DateFormat('MMM d, yyyy h:mm a').format(now);

      const headers = [
        '#',
        'Pet Name',
        'Species',
        'Breed',
        'Color / Wt',
        'Owner & Contact',
        'Barangay',
        'Collar ID',
        'Status',
        'Date Registered',
      ];

      final dataRows = <List<String>>[];

      for (var r = 0; r < pets.length; r++) {
        final p = pets[r];
        final petName = (p['name'] ?? '-').toString();
        final species = (p['species'] ?? '-').toString();
        final breed = (p['breed'] ?? '-').toString();
        final color = (p['color'] ?? '').toString();
        final weight = (p['weight'] ?? '').toString();
        final colorWeight = [
          if (color.isNotEmpty) color,
          if (weight.isNotEmpty && weight != 'null') '$weight kg',
        ].join(' • ');

        final u = p['users'];
        final ownerName = u is Map
            ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(' ')
            : 'Unknown';
        final phone = u is Map ? (u['phone']?.toString() ?? '') : '';
        final ownerContact = phone.isNotEmpty ? '$ownerName\n$phone' : ownerName;

        final barangay =
            (p['barangay'] ?? (u is Map ? u['barangay'] : '') ?? '-').toString();
        final collarId = (p['gps_id'] ?? '-').toString();
        final rawStatus = (p['status'] ?? 'active').toString().toUpperCase();

        String dateStr = '-';
        final rawDate = p['created_at']?.toString() ?? '';
        if (rawDate.isNotEmpty) {
          try {
            final dt = DateTime.parse(rawDate).toLocal();
            dateStr = DateFormat('MMM d, yyyy').format(dt);
          } catch (_) {
            dateStr = rawDate.split('T').first;
          }
        }

        dataRows.add([
          '${r + 1}',
          petName,
          species,
          breed,
          colorWeight.isNotEmpty ? colorWeight : '-',
          ownerContact,
          barangay,
          collarId,
          rawStatus,
          dateStr,
        ]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          header: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderLight, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'PetTrace',
                            style: pw.TextStyle(
                              color: primaryColor,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            '| Pet Registry Directory',
                            style: pw.TextStyle(
                              color: textDark,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Category: $categoryLabel  •  Generated: $formattedNow',
                        style: const pw.TextStyle(
                          color: textMuted,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'Total: ${pets.length} Pets',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: borderLight, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PetTrace Community-Driven Pet Protection • Official Pet Registry Directory',
                    style: const pw.TextStyle(color: textMuted, fontSize: 7.5),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(color: textMuted, fontSize: 7.5),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              border: pw.TableBorder.all(color: borderLight, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              headerHeight: 24,
              cellStyle: const pw.TextStyle(color: textDark, fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                7: pw.Alignment.center,
                8: pw.Alignment.center,
                9: pw.Alignment.center,
              },
              oddRowDecoration: const pw.BoxDecoration(color: zebraBg),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),  // #
                1: pw.FixedColumnWidth(80),  // Pet Name
                2: pw.FixedColumnWidth(55),  // Species
                3: pw.FixedColumnWidth(75),  // Breed
                4: pw.FixedColumnWidth(80),  // Color / Wt
                5: pw.FlexColumnWidth(),     // Owner & Contact
                6: pw.FixedColumnWidth(85),  // Barangay
                7: pw.FixedColumnWidth(65),  // Collar ID
                8: pw.FixedColumnWidth(60),  // Status
                9: pw.FixedColumnWidth(70),  // Date Registered
              },
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final dateCode = DateFormat('yyyyMMdd').format(now);
      final filename = 'pets_registry_$dateCode.pdf';

      await saveAndShareFile(bytes, filename);
      if (context.mounted) {
        _showToast(context, 'Exported PDF: $filename successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Export failed: $e', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. PET AUDIT LOGS PDF EXPORT
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<void> exportPetAuditToPdf(
    material.BuildContext context, {
    required Map<String, dynamic> pet,
    required List<PetAuditLog> logs,
  }) async {
    try {
      final doc = pw.Document();
      final now = DateTime.now();
      final formattedNow = DateFormat('MMM d, yyyy h:mm a').format(now);
      final petName = pet['name']?.toString() ?? 'Pet';

      const headers = ['#', 'Date & Time', 'Action / Event', 'User', 'Role', 'Details'];
      final dataRows = <List<String>>[];

      for (var i = 0; i < logs.length; i++) {
        final log = logs[i];
        final dtStr = DateFormat('MMM d, yyyy\nh:mm a').format(log.timestamp.toLocal());
        final action = log.action.replaceAll('_', ' ').toUpperCase();
        final user = log.modifiedBy.isNotEmpty ? log.modifiedBy : 'System';
        final role = log.modifierRole.toUpperCase();
        final details = log.changesSummary;

        dataRows.add(['${i + 1}', dtStr, action, user, role, details]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          header: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderLight, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PetTrace Pet Profile Audit Trail',
                        style: pw.TextStyle(
                          color: primaryTeal,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Pet: $petName • Generated: $formattedNow',
                        style: const pw.TextStyle(color: textMuted, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Text(
                    '${logs.length} Log Entries',
                    style: pw.TextStyle(
                      color: primaryTeal,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              border: pw.TableBorder.all(color: borderLight, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: primaryTeal),
              headerHeight: 24,
              cellStyle: const pw.TextStyle(color: textDark, fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: zebraBg),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FixedColumnWidth(75),
                2: pw.FixedColumnWidth(85),
                3: pw.FixedColumnWidth(75),
                4: pw.FixedColumnWidth(60),
                5: pw.FlexColumnWidth(),
              },
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final filename = 'pet_${petName.replaceAll(RegExp(r'\s+'), '_')}_audit.pdf';

      await saveAndShareFile(bytes, filename);
      if (context.mounted) {
        _showToast(context, 'Exported $filename successfully.',
            color: const material.Color(0xFF0F766E));
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Export failed: $e', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. USER AUDIT LOGS PDF EXPORT
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<void> exportUserAuditToPdf(
    material.BuildContext context, {
    required Map<String, dynamic> user,
    required List<UserAuditLog> logs,
  }) async {
    try {
      final doc = pw.Document();
      final now = DateTime.now();
      final formattedNow = DateFormat('MMM d, yyyy h:mm a').format(now);
      final userName = [
        user['first_name'],
        user['surname']
      ].where((s) => s != null && s.toString().isNotEmpty).join(' ');

      const headers = ['#', 'Date & Time', 'Action / Event', 'User', 'Role', 'Details'];
      final dataRows = <List<String>>[];

      for (var i = 0; i < logs.length; i++) {
        final log = logs[i];
        final dtStr = DateFormat('MMM d, yyyy\nh:mm a').format(log.timestamp.toLocal());
        final action = log.action.replaceAll('_', ' ').toUpperCase();
        final changedBy = log.modifiedBy.isNotEmpty ? log.modifiedBy : 'System';
        final role = log.modifierRole.toUpperCase();
        final details = log.changesSummary;

        dataRows.add(['${i + 1}', dtStr, action, changedBy, role, details]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          header: (pw.Context ctx) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderLight, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PetTrace User Account Audit Trail',
                        style: pw.TextStyle(
                          color: accentOrange,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Account: $userName • Generated: $formattedNow',
                        style: const pw.TextStyle(color: textMuted, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Text(
                    '${logs.length} Log Entries',
                    style: pw.TextStyle(
                      color: accentOrange,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              border: pw.TableBorder.all(color: borderLight, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: accentOrange),
              headerHeight: 24,
              cellStyle: const pw.TextStyle(color: textDark, fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: zebraBg),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FixedColumnWidth(75),
                2: pw.FixedColumnWidth(85),
                3: pw.FixedColumnWidth(75),
                4: pw.FixedColumnWidth(60),
                5: pw.FlexColumnWidth(),
              },
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final filename = 'user_${userName.replaceAll(RegExp(r'\s+'), '_')}_audit.pdf';

      await saveAndShareFile(bytes, filename);
      if (context.mounted) {
        _showToast(context, 'Exported $filename successfully.',
            color: const material.Color(0xFFEA580C));
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Export failed: $e', isError: true);
      }
    }
  }
}
