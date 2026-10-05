import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Reusable photo placeholder widget for pet and report image fallbacks.
class PhotoPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final BorderRadius? borderRadius;

  const PhotoPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.pets,
    this.iconSize = 32,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: width,
      height: height,
      color: backgroundColor ?? AppColors.primaryContainer.withOpacity(0.2),
      child: Center(
        child: Icon(
          icon,
          color: iconColor ?? AppColors.primaryContainer,
          size: iconSize,
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: container,
      );
    }
    return container;
  }
}
