import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

class AdminNewsCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  const AdminNewsCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final title = post['title'] as String? ?? 'Untitled';
    final summary = post['summary'] as String? ?? '';
    final category = post['category'] as String? ?? '';
    final imageUrl = post['image_url'] as String? ?? '';
    final accentHex = post['accent_color'] as String? ?? '#FF6600';

    Color accentColor = AppColors.primary;
    try {
      final hex = accentHex.replaceFirst('#', '');
      accentColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      child: Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: accentColor.withOpacity(0.15),
                          child: Icon(Icons.article_rounded,
                              color: accentColor, size: 28),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                      child: Icon(Icons.article_rounded,
                          color: accentColor, size: 28),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                category,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          Text(
                            title,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (summary.isNotEmpty)
                            Text(
                              summary,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined,
                color: AppColors.onSurfaceVariant, size: 20),
            tooltip: 'Archive post',
            onPressed: onArchive,
          ),
        ],
      ),
    );
  }
}

class AdminActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String timeAgo;

  const AdminActivityItem({
    super.key,
    required this.activity,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final description = activity['description'] as String? ?? '';
    final color = activity['color'] as Color? ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// Aliases for compatibility
typedef BarangayAdminNewsCard = AdminNewsCard;
typedef BarangayAdminActivityItem = AdminActivityItem;
