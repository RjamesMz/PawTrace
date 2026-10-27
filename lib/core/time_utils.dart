/// PawTrace Time & Date Utilities
/// Handles UTC conversions from Supabase Postgres timestamps correctly
/// preventing timezone offset drift (e.g. 8-hour offset in UTC+8).
class TimeUtils {
  const TimeUtils._();

  /// Safely parses timestamps returned from Supabase / Postgres.
  /// If the timestamp string lacks timezone information (no 'Z' and no +/- offset),
  /// it is treated as UTC (since Postgres/Supabase defaults to UTC).
  static DateTime parseTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.trim().isEmpty) {
      return DateTime.now();
    }
    String clean = timestamp.trim();
    if (!clean.endsWith('Z') &&
        !clean.contains('+') &&
        !RegExp(r'T.*\d{2}-\d{2}').hasMatch(clean)) {
      clean = clean.replaceFirst(' ', 'T');
      clean = '${clean}Z';
    }
    try {
      return DateTime.parse(clean).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Formats a timestamp into a human-friendly relative string like 'Just now', '5m ago', '2h ago'.
  static String formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.trim().isEmpty) return 'Recent';
    try {
      final dt = parseTimestamp(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return 'Recent';
    }
  }
}
