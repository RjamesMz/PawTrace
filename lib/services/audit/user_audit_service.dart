import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import '../export/file_export_service.dart';

/// Represents a single audit record of an account modification.
class UserAuditLog {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String action;
  final String changesSummary;
  final String modifiedBy;
  final String modifierRole;
  final DateTime timestamp;

  UserAuditLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.action,
    required this.changesSummary,
    required this.modifiedBy,
    required this.modifierRole,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'user_email': userEmail,
        'user_name': userName,
        'action': action,
        'changes_summary': changesSummary,
        'modified_by': modifiedBy,
        'modifier_role': modifierRole,
        'created_at': timestamp.toUtc().toIso8601String(),
      };

  factory UserAuditLog.fromMap(Map<String, dynamic> map) {
    return UserAuditLog(
      id: (map['id'] ?? map['log_id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      userEmail: (map['user_email'] ?? '').toString(),
      userName: (map['user_name'] ?? 'User').toString(),
      action: (map['action'] ?? 'Account Modified').toString(),
      changesSummary: (map['changes_summary'] ?? map['details'] ?? 'Account details updated').toString(),
      modifiedBy: (map['modified_by'] ?? map['modifier_name'] ?? 'Self').toString(),
      modifierRole: (map['modifier_role'] ?? 'user').toString(),
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ?? DateTime.now()
          : (map['timestamp'] != null
              ? DateTime.tryParse(map['timestamp'].toString())?.toLocal() ?? DateTime.now()
              : DateTime.now()),
    );
  }
}

/// Service to record, retrieve, and export account profile modification logs.
class UserAuditService {
  UserAuditService._();
  static final UserAuditService instance = UserAuditService._();

  final SupabaseClient _client = Supabase.instance.client;

  // In-memory fallback cache so logs work immediately across the app
  static final List<UserAuditLog> _localAuditCache = [];

  static List<UserAuditLog> get localAuditCache => List.unmodifiable(_localAuditCache);

  /// Records an audit log entry when a user account is modified.
  Future<void> logUserModification({
    required String userId,
    required String action,
    required String changesSummary,
    String? userEmail,
    String? userName,
    String? modifiedBy,
    String? modifierRole,
  }) async {
    final now = DateTime.now();
    final currentUserId = _client.auth.currentUser?.id;

    String actorName = modifiedBy ?? '';
    String actorRole = modifierRole ?? 'user';
    String targetUserName = userName ?? '';
    String targetUserEmail = userEmail ?? '';

    // If target name or email is missing, lookup from database or current session
    try {
      if (targetUserName.isEmpty || targetUserEmail.isEmpty) {
        final targetRes = await _client
            .from('users')
            .select('first_name, surname, email')
            .eq('user_id', userId)
            .maybeSingle();

        if (targetRes != null) {
          if (targetUserName.isEmpty) {
            final fName = (targetRes['first_name'] ?? '').toString().trim();
            final lName = (targetRes['surname'] ?? '').toString().trim();
            targetUserName = [fName, lName].where((s) => s.isNotEmpty).join(' ');
          }
          if (targetUserEmail.isEmpty) {
            targetUserEmail = (targetRes['email'] ?? '').toString().trim();
          }
        }
      }
    } catch (_) {}

    if (targetUserName.isEmpty) {
      targetUserName = 'User';
    }
    if (targetUserEmail.isEmpty && userId == currentUserId) {
      targetUserEmail = _client.auth.currentUser?.email ?? '';
    }

    // Resolve actor name & role if not provided
    if (actorName.isEmpty) {
      if (currentUserId != null && currentUserId == userId) {
        actorName = targetUserName;
      } else if (currentUserId != null) {
        try {
          final actorRes = await _client
              .from('users')
              .select('first_name, surname, role')
              .eq('user_id', currentUserId)
              .maybeSingle();

          if (actorRes != null) {
            final fName = (actorRes['first_name'] ?? '').toString().trim();
            final lName = (actorRes['surname'] ?? '').toString().trim();
            actorName = [fName, lName].where((s) => s.isNotEmpty).join(' ');
            actorRole = (actorRes['role'] ?? 'admin').toString();
          }
        } catch (_) {}
      }
      if (actorName.isEmpty) {
        actorName = currentUserId == userId ? 'Self' : 'Admin';
      }
    }

    final logEntry = UserAuditLog(
      id: 'local_${now.millisecondsSinceEpoch}',
      userId: userId,
      userEmail: targetUserEmail,
      userName: targetUserName,
      action: action,
      changesSummary: changesSummary,
      modifiedBy: actorName,
      modifierRole: actorRole,
      timestamp: now,
    );

    // Save to in-memory local cache
    _localAuditCache.insert(0, logEntry);

    // Persist to Supabase 'user_audit_logs' table (safe try-catch)
    try {
      await _client.from('user_audit_logs').insert(logEntry.toMap());
      debugPrint('[UserAuditService] Log saved to Supabase: $action');
    } catch (e) {
      debugPrint('[UserAuditService] Notice saving to user_audit_logs: $e');
    }

    // Update users table's updated_at timestamp so last modified displays accurately
    try {
      await _client
          .from('users')
          .update({'updated_at': now.toUtc().toIso8601String()})
          .eq('user_id', userId);
    } catch (_) {}
  }

  /// Fetches modification audit logs for a specific user.
  Future<List<UserAuditLog>> fetchLogsForUser(
    String userId, {
    Map<String, dynamic>? userData,
  }) async {
    final List<UserAuditLog> results = [];

    try {
      final query = _client.from('user_audit_logs').select();
      final data = await query
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      for (final item in data) {
        results.add(UserAuditLog.fromMap(Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('[UserAuditService] Notice fetching from Supabase: $e');
    }

    // Merge in-memory local logs that might not yet be in the database
    final localMatches = _localAuditCache.where((l) => l.userId == userId);
    for (final loc in localMatches) {
      if (!results.any((r) =>
          r.action == loc.action &&
          r.changesSummary == loc.changesSummary &&
          (r.timestamp.difference(loc.timestamp).inSeconds).abs() < 5)) {
        results.insert(0, loc);
      }
    }

    // Sort chronologically descending (newest first)
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // If no initial registration record, synthesize one based on created_at
    if (userData != null) {
      final regDate = DateTime.tryParse(userData['created_at']?.toString() ?? '') ?? DateTime.now();
      final hasRegRecord = results.any((r) => r.action == 'Account Created' || r.action == 'Registered');
      if (!hasRegRecord) {
        final fName = (userData['first_name'] ?? '').toString().trim();
        final lName = (userData['surname'] ?? '').toString().trim();
        final fullName = [fName, lName].where((s) => s.isNotEmpty).join(' ');
        final role = (userData['role'] ?? 'user').toString();

        results.add(
          UserAuditLog(
            id: 'init_$userId',
            userId: userId,
            userEmail: (userData['email'] ?? '').toString(),
            userName: fullName.isEmpty ? 'User' : fullName,
            action: 'Account Created',
            changesSummary: 'Initial account registration ($role role created).',
            modifiedBy: 'System / Registration',
            modifierRole: role,
            timestamp: regDate.toLocal(),
          ),
        );
      }
    }

    return results;
  }

  /// Exports the user's audit log to an Excel (.xlsx) file and triggers native download/share.
  Future<void> exportAuditLogsToExcel(
    BuildContext context,
    String userName,
    List<UserAuditLog> logs,
  ) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Account Audit History';
      final sheet = excel[sheetName];
      excel.delete('Sheet1'); // Remove default sheet

      // ── Header Row ──────────────────────────────────────────────
      const headers = [
        'Timestamp',
        'User Name',
        'Email',
        'Action Performed',
        'Modifications / Summary',
        'Modified By',
        'Modifier Role',
      ];

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#EA580C'), // Vibrant orange
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidth(
            c, c == 4 ? 45 : (c == 0 ? 22 : (c == 3 ? 24 : (c == 2 ? 26 : 18))));
      }

      // ── Data Rows ────────────────────────────────────────────────
      for (var r = 0; r < logs.length; r++) {
        final log = logs[r];
        final formattedDate =
            '${log.timestamp.year}-${log.timestamp.month.toString().padLeft(2, '0')}-${log.timestamp.day.toString().padLeft(2, '0')} ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

        final rowData = [
          formattedDate,
          log.userName,
          log.userEmail,
          log.action,
          log.changesSummary,
          log.modifiedBy,
          log.modifierRole.toUpperCase(),
        ];

        final rowStyle = CellStyle(
          backgroundColorHex: r.isEven
              ? ExcelColor.fromHexString('#FFFFFF')
              : ExcelColor.fromHexString('#FFF7ED'),
        );

        for (var c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          cell.value = TextCellValue(rowData[c]);
          cell.cellStyle = rowStyle;
        }
      }

      final bytes = excel.encode()!;
      final now = DateTime.now();
      final cleanName = userName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final filename =
          'user_audit_${cleanName}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';

      await saveAndShareFile(bytes, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported account audit log: $filename', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export audit log: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
