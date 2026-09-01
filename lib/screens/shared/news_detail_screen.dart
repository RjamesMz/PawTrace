import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> news;

  const NewsDetailScreen({super.key, required this.news});

  Color _parseHexColor(String? hexStr) {
    if (hexStr == null || hexStr.isEmpty) return AppColors.primary;
    try {
      final hex = hexStr.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Recent Update';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMMM d, yyyy • h:mm a').format(dt);
    } catch (_) {
      return 'Recent Update';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = news['title'] as String? ?? 'Announcement';
    final summary = news['summary'] as String? ?? '';
    final category = news['category'] as String? ?? 'General Update';
    final source = news['source'] as String? ?? 'PawTrace Updates';
    final imageUrl = news['image_url'] as String? ?? '';
    final dateFormatted = _formatDate(news['created_at']);
    final themeColor = _parseHexColor(news['accent_color']);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Collapsible Floating Header Image
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: themeColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: themeColor.withOpacity(0.85),
                            child: const Icon(Icons.article_rounded,
                                size: 80, color: Colors.white),
                          ),
                        )
                      : Container(
                          color: themeColor.withOpacity(0.85),
                          child: const Icon(Icons.article_rounded,
                              size: 80, color: Colors.white),
                        ),
                  // Bottom gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Body Content
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // News Title
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: themeColor.withOpacity(0.12),
                        child: Icon(Icons.edit_note_rounded,
                            color: themeColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormatted,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.surfaceContainer, height: 1),
                  const SizedBox(height: 24),

                  // Announcement Summary/Content Detail
                  Text(
                    summary,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.onSurface.withOpacity(0.85),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
