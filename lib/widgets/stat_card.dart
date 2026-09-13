import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable stat card with coloured background, icon, count number, and label.
///
/// Used on both the Super Admin and Barangay Admin dashboards.
class StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
          ),
          Flexible(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      count.toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// Convenience wrapper that lays out a list of [StatCard] widgets in a 2-column
/// (or custom column-count) grid.
class StatCardGrid extends StatelessWidget {
  final List<StatCard> children;
  final int crossAxisCount;
  final double childAspectRatio;

  const StatCardGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
