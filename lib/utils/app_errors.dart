import 'package:supabase_flutter/supabase_flutter.dart';

class AppErrors {
  /// Converts any exception into a short, user-friendly message.
  ///
  /// Handles:
  /// - [PostgrestException] — maps Postgres error codes / keywords to plain English
  /// - [AuthException]      — maps Supabase auth errors to plain English
  /// - Network / timeout errors
  /// - Falls back to [fallback] for anything unrecognised.
  static String format(Object error, {required String fallback}) {
    if (error is PostgrestException) {
      return _fromPostgrest(error, fallback);
    }

    if (error is AuthException) {
      return _fromAuth(error, fallback);
    }

    final raw = error.toString().toLowerCase();

    if (_contains(raw, ['socketexception', 'failed host lookup', 'network'])) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (_contains(raw, ['timeout', 'timed out'])) {
      return 'The request timed out. Please try again.';
    }

    return fallback;
  }

  // ── Postgrest / Supabase DB errors ───────────────────────────────────────

  static String _fromPostgrest(PostgrestException e, String fallback) {
    final code = e.code ?? '';
    final msg = (e.message ?? '').toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final combined = '$msg $details';

    // Postgres error codes — https://www.postgresql.org/docs/current/errcodes-appendix.html
    switch (code) {
      case '23505': // unique_violation
        if (_contains(combined, ['gps_id', 'collar', 'gps'])) {
          return 'This collar is already paired to another pet.';
        }
        return 'A record with this value already exists.';

      case '23503': // foreign_key_violation
        return 'This action references a record that no longer exists.';

      case '23502': // not_null_violation
        return 'Some required information is missing. Please fill in all fields.';

      case '42703': // undefined_column
        return 'Something went wrong with the request. Please contact support.';

      case '42P01': // undefined_table
        return 'Something went wrong on our end. Please contact support.';

      case 'PGRST116': // 0 rows returned when exactly 1 expected
        return 'The record was not found.';

      case '400':
        if (_contains(combined, ['does not exist'])) {
          return 'Something went wrong with the request. Please contact support.';
        }
        return 'Bad request. Please try again.';

      case '401':
      case '403':
        return 'You don\'t have permission to do that. Please log in and try again.';

      case '404':
        return 'The requested data was not found.';

      case '500':
        return 'A server error occurred. Please try again later.';
    }

    // Keyword fallbacks for messages without a clean code
    if (_contains(combined, ['unique', 'duplicate'])) {
      return 'A record with this value already exists.';
    }
    if (_contains(combined, ['permission', 'policy', 'rls', 'not allowed'])) {
      return 'You don\'t have permission to do that.';
    }
    if (_contains(combined, ['does not exist', 'undefined'])) {
      return 'Something went wrong. Please contact support.';
    }
    if (_contains(combined, ['timeout', 'timed out'])) {
      return 'The request timed out. Please try again.';
    }

    return fallback;
  }

  // ── Supabase Auth errors ──────────────────────────────────────────────────

  static String _fromAuth(AuthException e, String fallback) {
    final msg = e.message.toLowerCase();

    if (_contains(msg, ['invalid login', 'invalid credentials', 'wrong password'])) {
      return 'Incorrect email or password. Please try again.';
    }
    if (_contains(msg, ['email not confirmed', 'not confirmed'])) {
      return 'Please verify your email address before logging in.';
    }
    if (_contains(msg, ['user not found'])) {
      return 'No account found with that email address.';
    }
    if (_contains(msg, ['email already', 'already registered'])) {
      return 'An account with this email already exists.';
    }
    if (_contains(msg, ['password', 'too short', 'weak'])) {
      return 'Password is too weak. Please use at least 8 characters.';
    }
    if (_contains(msg, ['rate limit', 'too many requests'])) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (_contains(msg, ['token', 'expired', 'invalid'])) {
      return 'Your session has expired. Please log in again.';
    }

    return fallback;
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  static bool _contains(String source, List<String> keywords) =>
      keywords.any((k) => source.contains(k));
}
