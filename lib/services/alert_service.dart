import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage notifications and alerts from the Supabase `alerts` table.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Global notifier for unread alert count so UI badges update in real-time.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Refreshes the unread count and notifies listeners.
  Future<int> refreshUnreadCount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      unreadCount.value = 0;
      return 0;
    }
    try {
      final res = await _client
          .from('alerts')
          .select('alert_id')
          .eq('sent_to', uid)
          .eq('is_read', false);

      final count = (res as List).length;
      unreadCount.value = count;
      return count;
    } catch (e) {
      debugPrint('[AlertService] Error fetching unread count: $e');
      return unreadCount.value;
    }
  }

  /// Fetches all alerts sent to the current user, ordered latest first.
  Future<List<Map<String, dynamic>>> fetchUserAlerts() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      // Try joining lost_reports and pets for rich preview
      try {
        final data = await _client
            .from('alerts')
            .select('*, lost_reports(*, pets(*))')
            .eq('sent_to', uid)
            .order('sent_at', ascending: false);

        await refreshUnreadCount();
        return List<Map<String, dynamic>>.from(data);
      } catch (_) {
        // Fallback without join if foreign key alias or relationship differs
        final data = await _client
            .from('alerts')
            .select('*')
            .eq('sent_to', uid)
            .order('sent_at', ascending: false);

        await refreshUnreadCount();
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[AlertService] Error fetching alerts: $e');
      return [];
    }
  }

  /// Marks a specific alert as read.
  Future<bool> markAsRead(dynamic alertId) async {
    try {
      await _client
          .from('alerts')
          .update({'is_read': true})
          .eq('alert_id', alertId);

      if (unreadCount.value > 0) {
        unreadCount.value -= 1;
      }
      return true;
    } catch (e) {
      debugPrint('[AlertService] Error marking alert as read: $e');
      return false;
    }
  }

  /// Marks all alerts for the current user as read.
  Future<bool> markAllAsRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;

    try {
      await _client
          .from('alerts')
          .update({'is_read': true})
          .eq('sent_to', uid)
          .eq('is_read', false);

      unreadCount.value = 0;
      return true;
    } catch (e) {
      debugPrint('[AlertService] Error marking all as read: $e');
      return false;
    }
  }

  /// Dispatches alerts to barangay admins and local users when a pet is reported lost.
  Future<void> createLostPetAlerts({
    required dynamic lostReportId,
    required String petName,
    required String barangay,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;

      // Query potential recipients:
      // 1. Admins / Super Admins
      // 2. Users in the same barangay
      final recipients = await _client
          .from('users')
          .select('user_id, role, barangay')
          .or('barangay.eq.$barangay,role.eq.admin,role.eq.super_admin');

      final List<Map<String, dynamic>> alertRows = [];
      final Set<String> addedUserIds = {};

      final message =
          'URGENT: "$petName" was reported lost in Barangay $barangay. Keep a lookout!';
      final now = DateTime.now().toIso8601String();

      for (final r in recipients) {
        final userId = r['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        // Don't alert the owner who just filed the report
        if (userId == currentUserId) continue;
        if (addedUserIds.contains(userId)) continue;

        addedUserIds.add(userId);
        alertRows.add({
          'lost_report_id': lostReportId,
          'sent_to': userId,
          'message': message,
          'is_read': false,
          'sent_at': now,
        });
      }

      if (alertRows.isNotEmpty) {
        await _client.from('alerts').insert(alertRows);
        debugPrint(
            '[AlertService] Dispatched ${alertRows.length} lost pet alerts for $petName');
      }
    } catch (e) {
      debugPrint('[AlertService] Error creating lost pet alerts: $e');
    }
  }
}
