import 'package:flutter/material.dart';

/// Constrains admin screen content on wide displays so it doesn't stretch
/// across the full viewport.
///
/// - **Mobile (< 800 px):** returns [child] unchanged.
/// - **Web (≥ 800 px):** centres the [child] inside a [ConstrainedBox] with
///   [maxWidth] (default 1100 px) and adds horizontal + vertical padding.
class AdminContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdminContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1100,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
