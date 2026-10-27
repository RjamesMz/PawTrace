import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ScanQuotaResult {
  final bool isAllowed;
  final int remainingScans;
  final int waitMinutes;

  const ScanQuotaResult({
    required this.isAllowed,
    required this.remainingScans,
    this.waitMinutes = 0,
  });
}

/// Service managing rate limiting for AI Scans (20 scans per 1-hour window).
class ScanRateLimitService {
  ScanRateLimitService._();
  static final ScanRateLimitService instance = ScanRateLimitService._();

  static const int maxScansPerHour = 20;
  static const Duration quotaWindow = Duration(hours: 1);

  final ValueNotifier<int> remainingScansNotifier =
      ValueNotifier<int>(maxScansPerHour);

  List<int> _timestamps = [];
  bool _initialized = false;

  Future<File?> _getStorageFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/pawtrace_scan_quota.json');
    } catch (e) {
      debugPrint('[ScanRateLimitService] Storage file error: $e');
      return null;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final file = await _getStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> raw = jsonDecode(content);
        _timestamps = raw.map((e) => (e as num).toInt()).toList();
      }
    } catch (e) {
      debugPrint('[ScanRateLimitService] Error reading quota storage: $e');
      _timestamps = [];
    }

    _pruneExpired();
  }

  void _pruneExpired() {
    final cutoff = DateTime.now().subtract(quotaWindow).millisecondsSinceEpoch;
    _timestamps.removeWhere((ts) => ts < cutoff);
    _timestamps.sort();
    remainingScansNotifier.value = max(0, maxScansPerHour - _timestamps.length);
  }

  Future<void> _save() async {
    try {
      final file = await _getStorageFile();
      if (file != null) {
        await file.writeAsString(jsonEncode(_timestamps));
      }
    } catch (e) {
      debugPrint('[ScanRateLimitService] Error saving quota: $e');
    }
  }

  /// Checks if the user is allowed to scan and consumes 1 quota if allowed.
  Future<ScanQuotaResult> checkAndConsumeQuota() async {
    await init();
    _pruneExpired();

    final now = DateTime.now().millisecondsSinceEpoch;

    if (_timestamps.length >= maxScansPerHour) {
      // Calculate how many minutes until the earliest scan in the window expires
      final earliest = _timestamps.first;
      final expiryTime = earliest + quotaWindow.inMilliseconds;
      final diffMs = expiryTime - now;
      final waitMins = max(1, (diffMs / (60 * 1000)).ceil());

      return ScanQuotaResult(
        isAllowed: false,
        remainingScans: 0,
        waitMinutes: waitMins,
      );
    }

    // Consume 1 scan
    _timestamps.add(now);
    await _save();
    _pruneExpired();

    return ScanQuotaResult(
      isAllowed: true,
      remainingScans: remainingScansNotifier.value,
      waitMinutes: 0,
    );
  }

  /// Returns the current remaining scans in this 1-hour window.
  Future<int> getRemainingScans() async {
    await init();
    _pruneExpired();
    return remainingScansNotifier.value;
  }

  /// Reset for manual administration or debug demo.
  Future<void> resetForDemo() async {
    _timestamps.clear();
    await _save();
    _pruneExpired();
  }
}
