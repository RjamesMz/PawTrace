import 'package:flutter/material.dart';

/// PawTrace Design System Color Tokens
class AppColors {
  // Primary (Safety Orange #FF6600)
  static const Color primary = Color(0xFFFF6600);
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFFF8C00);
  static const Color onPrimaryContainer = Color(0xFF623200);
  static const Color primaryFixed = Color(0xFFFFDCC3);
  static const Color primaryFixedDim = Color(0xFFFFB77D);
  static const Color inversePrimary = Color(0xFFFFB77D);

  // Secondary
  static const Color secondary = Color(0xFF5D5F5F);
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFDFE0E0);
  static const Color onSecondaryContainer = Color(0xFF616363);
  static const Color secondaryFixed = Color(0xFFE2E2E2);

  // Tertiary
  static const Color tertiary = Color(0xFF5C5F60);
  static const Color onTertiary = Colors.white;
  static const Color tertiaryContainer = Color(0xFFA8AAAC);
  static const Color onTertiaryContainer = Color(0xFF3C3F41);

  // Surface
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF121C28);
  static const Color surfaceDim = Color(0xFFD1DBEC);
  static const Color surfaceBright = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFEEF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDFE9FA);
  static const Color surfaceContainerHighest = Color(0xFFD9E3F4);
  static const Color onSurfaceVariant = Color(0xFF564334);
  static const Color surfaceVariant = Color(0xFFD9E3F4);

  // Background
  static const Color background = Color(0xFFF8F9FF);
  static const Color onBackground = Color(0xFF121C28);

  // Outline
  static const Color outline = Color(0xFF897362);
  static const Color outlineVariant = Color(0xFFDDC1AE);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Inverse
  static const Color inverseSurface = Color(0xFF27313E);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);

  // orange == primary alias kept for BottomNavBar compatibility
  static const Color orange = primary;
}
