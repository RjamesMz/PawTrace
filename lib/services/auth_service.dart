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

    // Check if account is deactivated
    final profile = await getCurrentUserProfile();
    if (profile != null) {
      final status = (profile['status'] ?? 'active').toString().toLowerCase();
      if (status == 'deactivated' || status == 'de_activated') {
        await signOut();
        throw const AuthException(
            'This account has been deactivated. Please contact your administrator.');
      }
    }

    final role = await _fetchRole(uid);
    _cachedRole = role;
    return role;
  }

  // ─── Register ──────────────────────────────────────────────────────────────

  /// Creates a new user account with [role] = "user".
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
      emailRedirectTo: 'https://rjamesmz.github.io/PawTrace/web/verified.html',
      data: {
        'first_name': firstName.trim(),
        'middle_name': middleName?.trim(),
        'surname': surname.trim(),
        'suffix': suffix,
        'phone': phone.trim(),
        'address': address?.trim(),
        'barangay': barangay,
        'role': 'user',
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
        final role = meta['role']?.toString() ?? 'user';

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
        data = await _client
            .from('users')
            .select()
            .eq('user_id', uid)
            .maybeSingle();
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

  /// Validates that a password is at least 8 characters and alphanumeric (contains letters and numbers).
  /// Returns null if valid, or an error message if invalid.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'Password must contain both letters and numbers.';
    }
    return null;
  }

  /// Validates a street / house address:
  /// - Required and non-empty
  /// - Min 5 characters, Max 120 characters
  /// - Must contain alphabetic characters (rejects purely numeric inputs like '123123213123123213')
  /// - Rejects repetitive spam sequences (e.g. 'aaaaaa')
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your street or house number.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 5) {
      return 'Address is too short (minimum 5 characters).';
    }
    if (trimmed.length > 120) {
      return 'Address is too long (maximum 120 characters).';
    }
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(trimmed);
    if (!hasLetters) {
      return 'Address must include a street, purok, or place name (not numbers only).';
    }
    final clean = trimmed.replaceAll(RegExp(r'[\s,\.\-#/]+'), '');
    if (clean.length >= 5 && RegExp(r'^(.)\1+$').hasMatch(clean)) {
      return 'Please enter a valid, recognizable street address.';
    }
    return null;
  }

  /// Validates personal or entity names (First Name, Surname, etc.):
  /// - Only letters, spaces, hyphens, and apostrophes allowed
  /// - Rejects numbers, symbols, and repetitive spam
  /// - Length: 2 to 50 characters
  static String? validateName(
    String? value, {
    String fieldName = 'Name',
    bool isRequired = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (!isRequired) return null;
      return '$fieldName is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '$fieldName must be at least 2 characters.';
    }
    if (trimmed.length > 50) {
      return '$fieldName cannot exceed 50 characters.';
    }
    if (!RegExp(r"^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\.\-']+$").hasMatch(trimmed)) {
      return '$fieldName can only contain letters, spaces, and hyphens.';
    }
    final clean = trimmed.replaceAll(RegExp(r'[\s\.\-]+'), '');
    if (clean.length >= 4 && RegExp(r'^(.)\1+$').hasMatch(clean)) {
      return 'Please enter a valid $fieldName.';
    }
    return null;
  }

  /// Validates Philippine mobile phone numbers:
  /// Formats: 09XXXXXXXXX (11 digits) or +639XXXXXXXXX (13 chars)
  static String? validatePhone(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (!isRequired) return null;
      return 'Phone number is required.';
    }
    final trimmed = value.trim().replaceAll(RegExp(r'[\s\-]+'), '');
    final phRegex = RegExp(r'^(09|\+639)\d{9}$');
    if (!phRegex.hasMatch(trimmed)) {
      return 'Enter a valid 11-digit mobile number (e.g. 09123456789).';
    }
    return null;
  }

  /// Validates email address format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final trimmed = value.trim();
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }
    if (trimmed.length > 100) {
      return 'Email cannot exceed 100 characters.';
    }
    return null;
  }

  /// Validates general text fields (descriptions, titles, sources)
  static String? validateText(
    String? value, {
    required String fieldName,
    int minLength = 3,
    int maxLength = 500,
    bool isRequired = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (!isRequired) return null;
      return '$fieldName is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }
    if (trimmed.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }
    return null;
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
      return 'Password must be at least 8 alphanumeric characters.';
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
