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

  // ── Logo Widget Builders ──────────────────────────────────────────────────

  /// Builds just the raw logo graphic (asset image or icon).
  static Widget buildLogoGraphic({
    double? size,
    Color? color,
    BoxFit fit = BoxFit.contain,
    bool applyColorToAsset = false,
  }) {
    if (logoAsset.isNotEmpty) {
      return Image.asset(
        logoAsset,
        width: size,
        height: size,
        fit: fit,
        color: applyColorToAsset ? color : null,
        errorBuilder: (context, error, stackTrace) => Icon(
          logoIcon,
          size: size,
          color: color,
        ),
      );
    }
    return Icon(
      logoIcon,
      size: size,
      color: color,
    );
  }

  /// Builds the logo inside a circular or rounded container badge.
  static Widget buildLogoBadge({
    double size = 48,
    double? iconSize,
    Color backgroundColor = AppColors.primary,
    Color iconColor = Colors.white,
    BoxShape shape = BoxShape.circle,
    BorderRadiusGeometry? borderRadius,
    EdgeInsetsGeometry? padding,
    bool applyColorToAsset = false,
  }) {
    // If the asset is an image and the default background was primary orange,
    // use a crisp white background so the orange paw logo stands out vividly.
    final effectiveBg = (logoAsset.isNotEmpty && backgroundColor == AppColors.primary)
        ? Colors.white
        : backgroundColor;
    final effectiveIconSize = iconSize ?? (size * (logoAsset.isNotEmpty ? 0.78 : 0.55));

    return Container(
      width: size,
      height: size,
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
    double badgeSize = 64,
    double? iconSize,
    Color badgeColor = AppColors.primary,
    Color iconColor = Colors.white,
    double titleSize = 24,
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
    final str = error.toString().toLowerCase();

    // Supabase Email Rate Limit (e.g. 429 over_email_send_rate_limit)
    if (str.contains('over_email_send_rate_limit') ||
        str.contains('rate_limit') ||
        str.contains('rate limit') ||
        str.contains('429')) {
      return rateLimit;
    }

    // Invalid credentials / login failed
    if (str.contains('invalid_credentials') ||
        str.contains('invalid login credentials')) {
      return invalidCredentials;
    }

    // User not found
    if (str.contains('user_not_found') || str.contains('user not found')) {
      return userNotFound;
    }

    // Email not confirmed
    if (str.contains('email_not_confirmed') ||
        str.contains('email not confirmed')) {
      return emailNotConfirmed;
    }

    // Expired tokens or links
    if (str.contains('token has expired') ||
        str.contains('otp_expired') ||
        str.contains('expired')) {
      return linkExpired;
    }

    // Password validations
    if (str.contains('same_password') || str.contains('should be different')) {
      return samePassword;
    }
    if (str.contains('weak_password') || str.contains('password is too weak')) {
      return weakPassword;
    }

    // Network / connectivity
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('connection refused') ||
        str.contains('timeout')) {
      return networkError;
    }

    // Session expired
    if (str.contains('jwt expired') || str.contains('session_expired')) {
      return sessionExpired;
    }

    // Clean up generic "Exception: "
    if (str.startsWith('exception: ')) {
      final clean = error.toString().substring(11).trim();
      if (clean.isNotEmpty &&
          !clean.toLowerCase().contains('authapiexception')) {
        return '${clean[0].toUpperCase()}${clean.substring(1)}';
      }
    }

    if (fallback != null) return fallback;

    return defaultError;
  }
}
