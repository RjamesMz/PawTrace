import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage notifications and alerts from the Supabase `alerts` table.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Global notifier for unread alert count so UI badges update in real-time.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  RealtimeChannel? _realtimeChannel;
  Timer? _periodicTimer;

  /// Starts real-time listening to Postgres changes on the `alerts` table
  /// for alerts sent to the current user, along with a periodic fallback poll.
  void initRealtimeSubscription() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      if (_realtimeChannel != null) {
        _client.removeChannel(_realtimeChannel!);
      }
      _realtimeChannel = _client
          .channel('public:alerts:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'sent_to',
              value: uid,
            ),
            callback: (payload) {
              debugPrint('[AlertService] Realtime alert change received: ${payload.eventType}');
              refreshUnreadCount();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[AlertService] Error setting up realtime subscription: $e');
    }

    // Periodic safety poll every 20 seconds
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refreshUnreadCount();
    });
  }

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

  /// Dispatches alerts to barangay admins, super admins, and local users when a pet is reported lost.
  Future<void> createLostPetAlerts({
    required dynamic lostReportId,
    required String petName,
    required String barangay,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;

      // 1. Direct query for all admins & super admins (case-insensitive role check)
      List<dynamic> adminRecipients = [];
      try {
        adminRecipients = await _client
            .from('users')
            .select('user_id, role, barangay')
            .inFilter('role', ['admin', 'super_admin', 'Admin', 'Super Admin', 'ADMIN']);
      } catch (e) {
        debugPrint('[AlertService] Error querying admins: $e');
      }

      // 2. Query users located in the matching barangay
      List<dynamic> barangayRecipients = [];
      try {
        final cleanBrgy = barangay.trim();
        if (cleanBrgy.isNotEmpty) {
          barangayRecipients = await _client
              .from('users')
              .select('user_id, role, barangay')
              .ilike('barangay', '%$cleanBrgy%');
        }
      } catch (e) {
        debugPrint('[AlertService] Error querying barangay users: $e');
      }

      final List<Map<String, dynamic>> alertRows = [];
      final Set<String> addedUserIds = {};
      final now = DateTime.now().toIso8601String();

      // Dispatch to Admins (ALWAYS include all admins, even if the admin logged the report)
      for (final r in adminRecipients) {
        final userId = r['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        if (addedUserIds.contains(userId)) continue;
        addedUserIds.add(userId);

        alertRows.add({
          if (lostReportId != null) 'lost_report_id': lostReportId,
          'sent_to': userId,
          'message':
              '🚨 Admin Alert: "$petName" was reported missing in Brgy. $barangay. Verification & tracking recommended.',
          'is_read': false,
          'sent_at': now,
        });
      }

      // Dispatch to community residents in that barangay
      final communityMessage =
          '🐾 Lost Pet Alert: "$petName" was reported missing in Brgy. $barangay. Keep an eye out!';

      for (final r in barangayRecipients) {
        final userId = r['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        if (addedUserIds.contains(userId)) continue;
        // Don't alert the civilian pet owner who filed their own report
        if (userId == currentUserId) continue;

        addedUserIds.add(userId);
        alertRows.add({
          if (lostReportId != null) 'lost_report_id': lostReportId,
          'sent_to': userId,
          'message': communityMessage,
          'is_read': false,
          'sent_at': now,
        });
      }

      if (alertRows.isNotEmpty) {
        await _client.from('alerts').insert(alertRows);
        debugPrint(
            '[AlertService] Dispatched ${alertRows.length} lost pet alerts for $petName');
        await refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('[AlertService] Error creating lost pet alerts: $e');
    }
  }

  /// Dispatches an alert to barangay admins and super admins when a citizen registers a new pet.
  Future<void> createNewPetRegistrationAlert({
    required String petName,
    required String species,
    required String breed,
    required String barangay,
  }) async {
    try {
      final List<Map<String, dynamic>> alertRows = [];
      final now = DateTime.now().toIso8601String();
      final message =
          '🐾 New Pet Registered: "$petName" ($species · $breed) was registered in Brgy. $barangay.';

      List<dynamic> admins = [];
      try {
        admins = await _client
            .from('users')
            .select('user_id, role, barangay')
            .inFilter('role', ['admin', 'super_admin', 'Admin', 'Super Admin', 'ADMIN']);
      } catch (e) {
        debugPrint('[AlertService] Error querying admins for new pet alert: $e');
      }

      final cleanBrgy = barangay.toLowerCase().trim();
      for (final a in admins) {
        final userId = a['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        final adminBrgy = (a['barangay'] ?? '').toString().toLowerCase().trim();
        final role = (a['role'] ?? '').toString().toLowerCase().trim();

        // Super admins get all notifications; Barangay admins get matching barangay
        if (role == 'super_admin' ||
            adminBrgy.isEmpty ||
            adminBrgy.contains(cleanBrgy) ||
            cleanBrgy.contains(adminBrgy)) {
          alertRows.add({
            'sent_to': userId,
            'message': message,
            'is_read': false,
            'sent_at': now,
          });
        }
      }

      if (alertRows.isNotEmpty) {
        await _client.from('alerts').insert(alertRows);
        debugPrint('[AlertService] Dispatched new pet alerts to ${alertRows.length} admin(s)');
        await refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('[AlertService] Error creating new pet registration alert: $e');
    }
  }

  /// Broadcasts a lost pet news alert to ALL registered users across all barangays.
  Future<int> broadcastLostPetNewsAlert({
    required String petName,
    required String barangay,
    String? details,
  }) async {
    try {
      // Query ALL users regardless of barangay or role
      final recipients = await _client.from('users').select('user_id');

      final List<Map<String, dynamic>> alertRows = [];
      final Set<String> addedUserIds = {};

      final message =
          '📢 Community Alert: "$petName" was reported missing in Brgy. $barangay. Tap to view News!';
      final now = DateTime.now().toIso8601String();

      for (final r in recipients) {
        final userId = r['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        if (addedUserIds.contains(userId)) continue;

        addedUserIds.add(userId);
        alertRows.add({
          'sent_to': userId,
          'message': message,
          'is_read': false,
          'sent_at': now,
        });
      }

      if (alertRows.isNotEmpty) {
        await _client.from('alerts').insert(alertRows);
        debugPrint(
            '[AlertService] Broadcasted lost pet alert to ${alertRows.length} users across all barangays.');
        await refreshUnreadCount();
      }
      return alertRows.length;
    } catch (e) {
      debugPrint('[AlertService] Error broadcasting lost pet news alert: $e');
      return 0;
    }
  }

  /// Sends a test notification to the current logged-in admin or user.
  Future<bool> sendTestNotificationToCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final now = DateTime.now().toIso8601String();
      final timeStr =
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      await _client.from('alerts').insert({
        'sent_to': uid,
        'message':
            '🔔 Admin Test Alert ($timeStr): PetTrace notification delivery is active and functional!',
        'is_read': false,
        'sent_at': now,
      });
      await refreshUnreadCount();
      return true;
    } catch (e) {
      debugPrint('[AlertService] Error sending test alert: $e');
      return false;
    }
  }
}
