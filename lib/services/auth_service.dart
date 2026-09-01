import 'package:supabase_flutter/supabase_flutter.dart';

/// Roles a PawTrace user can hold.
/// There are exactly two roles: [user] and [admin].
enum UserRole { user, admin, superAdmin }

/// Thin wrapper around Supabase Authentication and the `users` table.
///
/// All screens should use this service rather than touching Supabase directly,
/// keeping the rest of the codebase free of Supabase-specific imports.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;
  UserRole? _cachedRole;
  String? _cachedBarangay;

  // ─── Stream ────────────────────────────────────────────────────────────────

  /// Emits auth state changes (sign-in, sign-out, token refresh, etc.).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// The currently signed-in Supabase user, or null if not authenticated.
  User? get currentUser => _client.auth.currentUser;

  // ─── Sign In ───────────────────────────────────────────────────────────────

  /// Signs in with email and password.
  ///
  /// Returns the [UserRole] read from the `users` table so the caller can
  /// redirect to the correct screen.  Throws [AuthException] on failure.
  Future<UserRole> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final uid = response.user!.id;
    final role = await _fetchRole(uid);
    _cachedRole = role;
    return role;
  }

  // ─── Register ──────────────────────────────────────────────────────────────

  /// Creates a new user account with [role] = "owner".
  ///
  /// Also inserts a row into the `users` table with the supplied profile data.
  /// Throws [AuthException] on failure.
  Future<void> register({
    required String firstName,
    required String surname,
    required String email,
    required String password,
    required String phone,
    String? middleName,
    String? suffix,
    String? address,
    String? barangay,
  }) async {
    // We send everything as user metadata. The database trigger will
    // read these fields and automatically insert them into public.users.
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'first_name': firstName.trim(),
        'middle_name': middleName?.trim(),
        'surname': surname.trim(),
        'suffix': suffix,
        'phone': phone.trim(),
        'address': address?.trim(),
        'barangay': barangay,
      },
    );

    _cachedRole = UserRole.user;
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  /// Signs the current user out of Supabase Auth.
  Future<void> signOut() async {
    _cachedRole = null;
    _cachedBarangay = null;
    await _client.auth.signOut();
  }

  // ─── Role helpers ──────────────────────────────────────────────────────────

  /// Reads the `role` field from the `users` table.
  ///
  /// Defaults to [UserRole.user] if the row or field is missing.
  Future<UserRole> getCurrentUserRole() async {
    if (_cachedRole != null) return _cachedRole!;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return UserRole.user;
    final role = await _fetchRole(uid);
    _cachedRole = role;
    return role;
  }

  /// Returns the barangay  assigned to the current admin user.
  ///
  /// Falls back to empty string if the user row or field is missing.
  Future<String> getCurrentUserBarangay() async {
    if (_cachedBarangay != null) return _cachedBarangay!;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return '';
    try {
      final data = await _client
          .from('users')
          .select('barangay')
          .eq('user_id', uid)
          .maybeSingle();
      _cachedBarangay = data?['barangay']?.toString() ?? '';
    } catch (_) {
      _cachedBarangay = '';
    }
    return _cachedBarangay!;
  }

  /// Updates the cached barangay value.
  void updateCachedBarangay(String? barangay) {
    _cachedBarangay = barangay;
  }

  /// Fetches the current user's profile from the `users` table.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final uid = user.id;
    try {
      var data =
          await _client.from('users').select().eq('user_id', uid).maybeSingle();
      if (data == null) {
        // Self-healing: if the user's row in public.users is missing, create it
        final email = user.email;
        final meta = user.userMetadata ?? {};
        final fName = meta['first_name']?.toString() ?? 'User';
        final sName = meta['surname']?.toString() ?? '';
        final phone = meta['phone']?.toString() ?? '';
        final address = meta['address']?.toString() ?? '';
        final barangay = meta['barangay']?.toString() ?? 'Calatagan';
        final role = meta['role']?.toString() ?? 'owner';

        await _client.from('users').insert({
          'user_id': uid,
          'email': email,
          'first_name': fName,
          'surname': sName,
          'phone': phone,
          'address': address.isEmpty ? null : address,
          'barangay': barangay.isEmpty ? null : barangay,
          'role': role,
        });

        // Re-fetch
        data = await _client.from('users').select().eq('user_id', uid).maybeSingle();
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<UserRole> _fetchRole(String uid) async {
    try {
      final data = await _client
          .from('users')
          .select('role')
          .eq('user_id', uid)
          .maybeSingle();
      if (data == null) return UserRole.user;
      final role = data['role']?.toString().trim().toLowerCase();
      if (role == 'super_admin') return UserRole.superAdmin;
      if (role == 'admin') return UserRole.admin;
      return UserRole.user;
    } catch (e) {
      print('Error fetching role: $e');
      return UserRole.user;
    }
  }

  // ─── Error helper ──────────────────────────────────────────────────────────

  /// Converts an [AuthException] message into a user-friendly string.
  static String friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'An account with that email already exists.';
    }
    if (msg.contains('weak password') || msg.contains('at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('invalid email') || msg.contains('not a valid')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please try again later.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Check your connection.';
    }
    return e.message;
  }
}
