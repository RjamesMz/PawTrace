import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central application configuration and constants.
///
/// To customize the logo or app name, simply change [appName], [logoAsset],
/// or [logoIcon] below. All components using the logo across the app will
/// automatically update.
class AppConstants {
  // ── App Branding ──────────────────────────────────────────────────────────
  /// The global name of the application.
  static const String appName = 'PetTrace';

  // ── Logo Configuration ────────────────────────────────────────────────────
  /// CHANGE YOUR LOGO HERE:
  ///
  /// Option 1: Image Asset
  /// Set [logoAsset] to your asset path (e.g. 'assets/images/logo.png')
  /// and ensure it is registered in [pubspec.yaml] under `flutter: assets:`.
  /// When this is non-null and not empty, the image will be displayed.
  static const String logoAsset = 'assets/images/logo.png';

  /// Option 2: Material Icon
  /// If [logoAsset] is empty, this icon is displayed across the app.
  static const IconData logoIcon = Icons.pets;

  // ── Barangay / Location List ───────────────────────────────────────────────
  static const List<String> barangays = [
    'Calatagan',
  ];

  // ── Known Breeds List ──────────────────────────────────────────────────────
  static const List<String> dogBreeds = [
    'Aspin',
    'Shih Tzu',
    'Pomeranian',
    'Golden Retriever',
    'Labrador Retriever',
    'Siberian Husky',
    'Chihuahua',
    'Poodle',
    'German Shepherd',
    'Pug',
    'Beagle',
    'French Bulldog',
    'Rottweiler',
    'Dachshund',
    'Belgian Malinois',
    'Chow Chow',
    'Pitbull / Bully',
    'Corgi',
    'Japanese Spitz',
    'Doberman',
    'Great Dane',
    'Mixed Breed',
    'Other',
  ];

  static const List<String> catBreeds = [
    'Puspin',
    'Persian',
    'Siamese',
    'British Shorthair',
    'Maine Coon',
    'Scottish Fold',
    'Ragdoll',
    'Bengal',
    'Russian Blue',
    'American Shorthair',
    'Sphynx',
    'Munchkin',
    'Himalayan',
    'Birman',
    'Abyssinian',
    'Domestic Shorthair',
    'Mixed Breed',
    'Other',
  ];

  // ── Logo Widget Builders & Global Sizing ──────────────────────────────────
  /// Standard sizes so you can adjust the logo scale globally in one place:
  static const double headerLogoSize = 34.0;
  static const double defaultBadgeSize = 64.0;
  static const double brandHeaderBadgeSize = 84.0;

  /// Builds just the raw logo graphic (asset image or icon).
  static Widget buildLogoGraphic({
    double? size,
    Color? color,
    BoxFit fit = BoxFit.contain,
    bool applyColorToAsset = false,
  }) {
    // If size is omitted, use headerLogoSize. If a small size was passed (< 30), scale it up generously.
    final effectiveSize = size == null
        ? headerLogoSize
        : (size < 30 ? (size * 1.35).clamp(32.0, 60.0) : size);

    if (logoAsset.isNotEmpty) {
      return Image.asset(
        logoAsset,
        width: effectiveSize,
        height: effectiveSize,
        fit: fit,
        color: applyColorToAsset ? color : null,
        errorBuilder: (context, error, stackTrace) => Icon(
          logoIcon,
          size: effectiveSize,
          color: color,
        ),
      );
    }
    return Icon(
      logoIcon,
      size: effectiveSize,
      color: color,
    );
  }

  /// Builds the logo inside a circular or rounded container badge.
  static Widget buildLogoBadge({
    double size = defaultBadgeSize,
    double? iconSize,
    Color backgroundColor = AppColors.primary,
    Color iconColor = Colors.white,
    BoxShape shape = BoxShape.circle,
    BorderRadiusGeometry? borderRadius,
    EdgeInsetsGeometry? padding,
    bool applyColorToAsset = false,
  }) {
    // Ensure badge is never too small to see the logo clearly
    final effectiveBadgeSize = size < 44 ? 44.0 : size;

    // If the asset is an image and the default background was primary orange,
    // use a crisp white background so the orange paw logo stands out vividly.
    final effectiveBg =
        (logoAsset.isNotEmpty && backgroundColor == AppColors.primary)
            ? Colors.white
            : backgroundColor;

    // Make the logo fill 88% of the badge so it is clear, large, and prominent
    final effectiveIconSize =
        iconSize != null && iconSize >= (effectiveBadgeSize * 0.75)
            ? iconSize
            : (effectiveBadgeSize * (logoAsset.isNotEmpty ? 0.88 : 0.65));

    return Container(
      width: effectiveBadgeSize,
      height: effectiveBadgeSize,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        shape: shape,
        boxShadow: (effectiveBg == Colors.white)
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.circular(12)),
      ),
      alignment: Alignment.center,
      child: buildLogoGraphic(
        size: effectiveIconSize,
        color: iconColor,
        applyColorToAsset: applyColorToAsset,
      ),
    );
  }

  /// Builds a complete branding section with logo badge + app name.
  static Widget buildBrandHeader({
    double badgeSize = brandHeaderBadgeSize,
    double? iconSize,
    Color badgeColor = AppColors.primary,
    Color iconColor = Colors.white,
    double titleSize = 26,
    Color? titleColor,
    FontWeight titleWeight = FontWeight.w800,
    double spacing = 10,
    bool isVertical = true,
    Widget? trailing,
  }) {
    final titleWidget = Text(
      appName,
      style: GoogleFonts.montserrat(
        fontSize: titleSize,
        fontWeight: titleWeight,
        color: titleColor ?? AppColors.primary,
        letterSpacing: -0.5,
      ),
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildLogoBadge(
            size: badgeSize,
            iconSize: iconSize,
            backgroundColor: badgeColor,
            iconColor: iconColor,
          ),
          SizedBox(height: spacing),
          if (trailing != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                trailing,
              ],
            )
          else
            titleWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildLogoBadge(
          size: badgeSize,
          iconSize: iconSize,
          backgroundColor: badgeColor,
          iconColor: iconColor,
        ),
        SizedBox(width: spacing),
        titleWidget,
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Timestamp Timezone Parsing ─────────────────────────────────────────────
  /// Parses an ISO 8601 timestamp string from Supabase / API into local device time.
  /// Automatically guards against timestamps that were saved with local wall-clock values
  /// into UTC database columns (which otherwise adds a redundant timezone offset, shifting
  /// the date into the future).
  static DateTime? tryParseLocalTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    try {
      String clean = timestamp.trim();
      if (!clean.endsWith('Z') &&
          !clean.contains('+') &&
          !RegExp(r'T.*\d{2}-\d{2}').hasMatch(clean)) {
        clean = clean.replaceFirst(' ', 'T');
        clean = '${clean}Z';
      }
      var dt = DateTime.parse(clean).toLocal();
      final now = DateTime.now();
      if (dt.isAfter(now.add(const Duration(minutes: 5)))) {
        dt = dt.subtract(dt.timeZoneOffset);
      }
      return dt;
    } catch (_) {
      return null;
    }
  }

  /// Parses timestamp string into local device time, falling back to DateTime.now() if invalid.
  static DateTime parseLocalTime(String timestamp) {
    return tryParseLocalTime(timestamp) ?? DateTime.now();
  }
}

/// Standalone convenience widget for displaying the application logo.
class AppLogo extends StatelessWidget {
  final double? size;
  final Color? color;
  final BoxFit fit;
  final bool applyColorToAsset;

  const AppLogo({
    super.key,
    this.size,
    this.color,
    this.fit = BoxFit.contain,
    this.applyColorToAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppConstants.buildLogoGraphic(
      size: size,
      color: color,
      fit: fit,
      applyColorToAsset: applyColorToAsset,
    );
  }
}

/// Centralized error message translation and formatting.
/// Translates raw technical errors, Supabase exceptions, and status codes
/// into clear, user-friendly language.
class AppErrors {
  static const String defaultError =
      'An unexpected error occurred. Please try again.';
  static const String rateLimit =
      'Too many email requests. Please wait a minute before requesting another link.';
  static const String invalidCredentials =
      'Incorrect email or password. Please try again.';
  static const String userNotFound =
      'No account found with this email address.';
  static const String emailNotConfirmed =
      'Please verify your email address before continuing.';
  static const String linkExpired =
      'This password reset link has expired. Please request a new one.';
  static const String weakPassword =
      'Password is too weak. Please use at least 8 characters with letters and numbers.';
  static const String samePassword =
      'Your new password must be different from your old password.';
  static const String networkError =
      'Network error. Please check your internet connection and try again.';
  static const String sessionExpired =
      'Your session has expired. Please sign in again.';

  /// Converts any exception, raw technical error, or code into a clean, human-readable message.
  static String format(dynamic error, {String? fallback}) {
    if (error == null) return fallback ?? defaultError;
    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback ?? defaultError;
    final str = raw.toLowerCase();

    // 1. Network & Connectivity (Socket, HTTP, DNS, Timeout)
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('connection refused') ||
        str.contains('network is unreachable') ||
        str.contains('clientexception') ||
        str.contains('timeout') ||
        str.contains('timeoutexception') ||
        str.contains('handshakeexception') ||
        str.contains('connection reset') ||
        str.contains('network error') ||
        str.contains('no internet')) {
      return networkError;
    }

    // 2. Authentication & Account Access
    if (str.contains('invalid_credentials') ||
        str.contains('invalid login credentials') ||
        str.contains('invalid email or password') ||
        str.contains('incorrect email or password')) {
      return invalidCredentials;
    }

    if (str.contains('email_not_confirmed') ||
        str.contains('email not confirmed')) {
      return emailNotConfirmed;
    }

    if (str.contains('user_not_found') ||
        str.contains('user not found') ||
        str.contains('no user found')) {
      return userNotFound;
    }

    if (str.contains('over_email_send_rate_limit') ||
        str.contains('rate_limit') ||
        str.contains('rate limit') ||
        str.contains('too many requests') ||
        str.contains('429')) {
      return rateLimit;
    }

    if (str.contains('token has expired') ||
        str.contains('otp_expired') ||
        str.contains('expired')) {
      return linkExpired;
    }

    if (str.contains('same_password') ||
        str.contains('should be different') ||
        str.contains('different from your old')) {
      return samePassword;
    }

    if (str.contains('weak_password') ||
        str.contains('password is too weak') ||
        str.contains('at least 8')) {
      return weakPassword;
    }

    if (str.contains('jwt expired') || str.contains('session_expired')) {
      return sessionExpired;
    }

    if (str.contains('deactivated') || str.contains('de_activated')) {
      return 'This account has been deactivated. Please contact your administrator.';
    }

    if (str.contains('user_banned') || str.contains('user is banned')) {
      return 'This account has been suspended. Please contact your administrator.';
    }

    if (str.contains('signup_disabled') || str.contains('signups not allowed')) {
      return 'Account registration is currently disabled.';
    }

    // 3. Database unique constraint violation (e.g. Postgres 23505)
    if (str.contains('23505') ||
        str.contains('unique constraint') ||
        str.contains('duplicate key')) {
      if (str.contains('collar') || str.contains('gps')) {
        return 'This GPS Collar ID is already paired with another pet. 1 collar can only belong to 1 pet.';
      }
      if (str.contains('email')) {
        return 'An account with this email address already exists. Please sign in instead.';
      }
      if (str.contains('phone')) {
        return 'This phone number is already registered to another account.';
      }
      return 'This record already exists. Please choose a different one.';
    }

    // 4. Database Foreign Key Violation (e.g. Postgres 23503)
    if (str.contains('23503') || str.contains('foreign key')) {
      return 'The referenced item could not be found or has been removed.';
    }

    // 5. Permission denied / Row-level security (e.g. Postgres 42501)
    if (str.contains('42501') ||
        str.contains('permission denied') ||
        str.contains('row-level security') ||
        str.contains('row-level security policy')) {
      return 'You do not have permission to perform this action.';
    }

    // 6. Camera / Media / Location Permissions
    if (str.contains('camera_access_denied') ||
        str.contains('photo_access_denied') ||
        str.contains('permission denied to access camera') ||
        str.contains('camera permission')) {
      return 'Camera or photo permission denied. Please allow access in device settings.';
    }

    if (str.contains('no available camera') ||
        str.contains('camera is not ready')) {
      return 'Camera is not available. Please check your camera permissions.';
    }

    if (str.contains('location permissions are denied') ||
        str.contains('location_permission_denied')) {
      return 'Location permission is required. Please enable location in settings.';
    }

    if (str.contains('location services are disabled')) {
      return 'Location services are disabled. Please enable GPS on your device.';
    }

    // 7. Storage / File Size
    if (str.contains('payload too large') ||
        str.contains('file too large') ||
        str.contains('request entity too large') ||
        str.contains('413')) {
      return 'The selected photo is too large. Please select a smaller photo.';
    }

    if (str.contains('bucket not found') || str.contains('storageexception')) {
      return 'Storage service is temporarily unavailable. Please try again later.';
    }

    // 8. Extract meaningful message from PostgrestException if present
    if (str.contains('postgrestexception')) {
      final msgMatch =
          RegExp(r'message:\s*([^,\)\n]+)', caseSensitive: false).firstMatch(raw);
      if (msgMatch != null) {
        final innerMsg = msgMatch.group(1)?.trim() ?? '';
        final lowerInner = innerMsg.toLowerCase();
        if (lowerInner.contains('unique constraint') ||
            lowerInner.contains('23505')) {
          if (lowerInner.contains('collar') || lowerInner.contains('gps')) {
            return 'This GPS Collar ID is already paired with another pet. 1 collar can only belong to 1 pet.';
          }
          if (lowerInner.contains('email')) {
            return 'An account with this email address already exists. Please sign in instead.';
          }
          return 'This record already exists. Please choose a different one.';
        }
        if (lowerInner.contains('violates row-level security')) {
          return 'You do not have permission to perform this action.';
        }
        if (innerMsg.isNotEmpty &&
            !lowerInner.contains('syntax error') &&
            !lowerInner.contains('relation') &&
            !lowerInner.contains('column')) {
          return innerMsg;
        }
      }
      return fallback ?? 'Database request failed. Please try again.';
    }

    // 9. Clean up common wrapper prefixes: "Exception: ", "AuthException: ", "Error: ", "StateError: "
    final clean = raw
        .replaceFirst(
          RegExp(
            r'^(exception|authexception|postgrestexception|error|stateerror):\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // If string has a custom prefix like "Failed to submit report: <message>"
    final prefixMatch = RegExp(
      r'^(failed to [^:]+|error [^:]+|could not [^:]+):\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (prefixMatch != null) {
      final prefix = prefixMatch.group(1)!.trim();
      final remainder = prefixMatch.group(2)!.trim();
      final formattedRemainder = format(remainder, fallback: fallback);
      if (formattedRemainder != defaultError) {
        return '$prefix: $formattedRemainder';
      }
    }

    // 10. If the cleaned string is already human-readable (not technical garbage/stack)
    final isTechnical = clean.toLowerCase().contains('authapiexception') ||
        clean.toLowerCase().contains('postgrest') ||
        clean.toLowerCase().contains('postgresql') ||
        clean.toLowerCase().contains('sqlstate') ||
        clean.toLowerCase().contains('stacktrace') ||
        clean.toLowerCase().contains('syntax error') ||
        clean.toLowerCase().contains('type \'') ||
        clean.toLowerCase().contains('null check operator') ||
        clean.toLowerCase().contains('nosuchmethoderror') ||
        clean.contains('  at ') ||
        clean.contains('.dart:');

    if (!isTechnical && clean.isNotEmpty) {
      return '${clean[0].toUpperCase()}${clean.substring(1)}';
    }

    if (fallback != null) return fallback;

    return defaultError;
  }
}
