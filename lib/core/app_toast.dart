import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized utility for crisp, quick toast notifications in PawTrace.
/// Disappears quickly (1.8s by default) instead of lingering for 4+ seconds.
class AppToast {
  static const Duration defaultDuration = Duration(milliseconds: 1800);
  static const Duration errorDuration = Duration(milliseconds: 2200);

  /// Shows a general toast notification with auto-dismiss and previous-toast cleanup.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: backgroundColor ?? AppColors.inverseSurface,
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a success toast with checkmark and green background.
  static void success(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
  }) {
    show(
      context,
      message,
      duration: duration,
      backgroundColor: const Color(0xFF22C55E),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  /// Shows an error toast with error icon and red background.
  static void error(
    BuildContext context,
    String message, {
    Duration duration = errorDuration,
  }) {
    show(
      context,
      message,
      duration: duration,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline_rounded,
    );
  }

  /// Shows an info or warning toast.
  static void info(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
  }) {
    show(
      context,
      message,
      duration: duration,
      backgroundColor: AppColors.primaryContainer,
      icon: Icons.info_outline_rounded,
    );
  }
}
