import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import '../export/file_export_service.dart';

/// Represents a single audit record of a pet's modification.
class PetAuditLog {
  final String id;
  final String petId;
  final String petName;
  final String action;
  final String changesSummary;
  final String modifiedBy;
  final String modifierRole;
  final DateTime timestamp;

  PetAuditLog({
    required this.id,
    required this.petId,
    required this.petName,
    required this.action,
    required this.changesSummary,
    required this.modifiedBy,
    required this.modifierRole,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'pet_id': int.tryParse(petId) ?? petId,
        'pet_name': petName,
        'action': action,
        'changes_summary': changesSummary,
        'modified_by': modifiedBy,
        'modifier_role': modifierRole,
        'created_at': timestamp.toIso8601String(),
      };

  factory PetAuditLog.fromMap(Map<String, dynamic> map) {
    return PetAuditLog(
      id: (map['id'] ?? map['log_id'] ?? '').toString(),
      petId: (map['pet_id'] ?? '').toString(),
      petName: (map['pet_name'] ?? '').toString(),
      action: (map['action'] ?? 'Profile Updated').toString(),
      changesSummary:
          (map['changes_summary'] ?? map['details'] ?? 'Details updated')
              .toString(),
      modifiedBy: (map['modified_by'] ?? map['modifier_name'] ?? 'User')
          .toString(),
      modifierRole: (map['modifier_role'] ?? 'owner').toString(),
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Service to record, retrieve, and export pet profile audit/modification logs.
class PetAuditService {
  PetAuditService._();
  static final PetAuditService instance = PetAuditService._();

  final SupabaseClient _client = Supabase.instance.client;

  // In-memory fallback cache so logs work immediately across the app
  static final List<PetAuditLog> _localAuditCache = [];

  /// Records an audit log entry when a pet profile is modified.
  Future<void> logPetModification({
    required String petId,
    required String petName,
    required String action,
    required String changesSummary,
    String? modifierName,
    String? modifierRole,
    String? modifiedByRole,
  }) async {
    final effectiveRole = modifierRole ?? modifiedByRole ?? 'Owner';
    final currentUserId = _client.auth.currentUser?.id;
    final now = DateTime.now();

    // Determine modifier name
    String actorName = modifierName ?? 'Owner';
    String actorRole = effectiveRole;

    try {
      if (currentUserId != null && modifierName == null) {
        final userRes = await _client
            .from('users')
            .select('first_name, surname, role')
            .eq('user_id', currentUserId)
            .maybeSingle();

        if (userRes != null) {
          final fName = (userRes['first_name'] ?? '').toString().trim();
          final lName = (userRes['surname'] ?? '').toString().trim();
          actorName = [fName, lName].where((s) => s.isNotEmpty).join(' ');
          if (actorName.isEmpty) actorName = 'Registered User';
          actorRole = (userRes['role'] ?? 'owner').toString();
        }
      }
    } catch (_) {}

    final logEntry = PetAuditLog(
      id: 'local_${now.millisecondsSinceEpoch}',
      petId: petId,
      petName: petName,
      action: action,
      changesSummary: changesSummary,
      modifiedBy: actorName,
      modifierRole: actorRole,
      timestamp: now,
    );

    // Save to in-memory local cache
    _localAuditCache.insert(0, logEntry);

    // Persist to Supabase 'pet_audit_logs' table (safe try-catch)
    try {
      await _client.from('pet_audit_logs').insert(logEntry.toMap());
      debugPrint('[PetAuditService] Log saved to Supabase: $action');
    } catch (e) {
      debugPrint('[PetAuditService] Notice saving to pet_audit_logs: $e');
    }
  }

  /// Fetches modification audit logs for a specific pet.
  Future<List<PetAuditLog>> fetchLogsForPet(
    String petId, {
    Map<String, dynamic>? petData,
  }) async {
    final List<PetAuditLog> results = [];

    // 1. Try fetching from Supabase table
    try {
      final data = await _client
          .from('pet_audit_logs')
          .select()
          .eq('pet_id', petId)
          .order('created_at', ascending: false);

      for (final item in data) {
        results.add(PetAuditLog.fromMap(Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('[PetAuditService] Notice fetching from Supabase: $e');
    }

    // 2. Merge local in-memory logs for this pet that are not already in results
    final localMatches = _localAuditCache.where((l) => l.petId == petId);
    for (final local in localMatches) {
      final exists = results.any(
        (r) =>
            r.action == local.action &&
            r.changesSummary == local.changesSummary &&
            r.timestamp.difference(local.timestamp).inSeconds.abs() < 5,
      );
      if (!exists) {
        results.add(local);
      }
    }

    // 3. Sort by timestamp descending
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 4. If petData has a created_at date, add the initial registration record as the baseline
    if (petData != null && petData['created_at'] != null) {
      final regDate = DateTime.tryParse(petData['created_at'].toString()) ??
          DateTime.now();
      final hasRegRecord = results.any((r) => r.action == 'Pet Registered');
      if (!hasRegRecord) {
        results.add(
          PetAuditLog(
            id: 'init_$petId',
            petId: petId,
            petName: petData['name'] ?? 'Pet',
            action: 'Pet Registered',
            changesSummary:
                'Initial registration of ${petData['name']} (${petData['species'] ?? 'Pet'}, ${petData['breed'] ?? 'Unknown Breed'}). Biometric profiles created.',
            modifiedBy: 'Owner / Initial Registration',
            modifierRole: 'owner',
            timestamp: regDate.toLocal(),
          ),
        );
      }
    }

    return results;
  }

  /// Exports the pet's audit log to an Excel (.xlsx) file and triggers native download/share.
  Future<void> exportAuditLogsToExcel(
    BuildContext context,
    String petName,
    List<PetAuditLog> logs,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheetName = 'Audit History';
      final sheet = excel[sheetName];
      excel.delete('Sheet1'); // Remove default sheet

      // ── Header Row ──────────────────────────────────────────────
      const headers = [
        'Timestamp',
        'Pet Name',
        'Action Performed',
        'Modifications / Summary',
        'Modified By',
        'User Role',
      ];

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'), // Dark teal
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      for (var c = 0; c < headers.length; c++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidth(
            c, c == 3 ? 45 : (c == 0 ? 22 : (c == 2 ? 24 : 18)));
      }

      // ── Data Rows ────────────────────────────────────────────────
      for (var r = 0; r < logs.length; r++) {
        final log = logs[r];
        final formattedDate =
            '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')} ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

        final rowData = [
          formattedDate,
          log.petName,
          log.action,
          log.changesSummary,
          log.modifiedBy,
          log.modifierRole.toUpperCase(),
        ];

        final rowStyle = CellStyle(
          backgroundColorHex: r.isEven
              ? ExcelColor.fromHexString('#FFFFFF')
              : ExcelColor.fromHexString('#F0FDFA'),
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
      final cleanPetName =
          petName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final filename =
          'audit_log_${cleanPetName}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';

      await saveAndShareFile(bytes, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported audit log: $filename',
              style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export audit log: $e',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
