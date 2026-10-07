import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../widgets/common/photo_placeholder.dart';

class AdminPetCard extends StatelessWidget {
  final Map<String, dynamic> pet;
  final VoidCallback onTap;
  final VoidCallback onContact;
  final VoidCallback? onViewMap;
  final VoidCallback onRepost;
  final VoidCallback? onViewLogs;

  const AdminPetCard({
    super.key,
    required this.pet,
    required this.onTap,
    required this.onContact,
    this.onViewMap,
    required this.onRepost,
    this.onViewLogs,
  });

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return '-';
    try {
      final dt = DateTime.parse(str).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = (pet['status'] ?? 'active').toString().toLowerCase();
    final isLost = rawStatus == 'lost';
    final isArchived = rawStatus == 'archived';
    final name = pet['name'] ?? 'Unknown';
    final breed = pet['breed'] ?? '';
    final species = pet['species'] ?? '';
    final barangay = pet['barangay'] ?? '';
    final photoUrl = pet['photo_url'] ?? '';
    final regDate = _formatDate(pet['created_at']);
    final u = pet['users'];
    final ownerName = u != null
        ? [u['first_name'], u['middle_name'], u['surname'], u['suffix']]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(' ')
        : 'Unknown Owner';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: photoUrl.toString().isNotEmpty
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const PhotoPlaceholder(width: 72, height: 72),
                          )
                        : const PhotoPlaceholder(width: 72, height: 72),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$breed • $species',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Owner: $ownerName',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          if (barangay.toString().isNotEmpty)
                            Text(
                              barangay,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    AppColors.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          if (barangay.toString().isNotEmpty && regDate != '-')
                            Text(' • ',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant
                                        .withOpacity(0.4))),
                          if (regDate != '-')
                            Text(
                              'Reg: $regDate',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    AppColors.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isArchived
                        ? const Color(0xFFF1F5F9)
                        : (isLost
                            ? AppColors.errorContainer
                            : const Color(0xFFD1FAE5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isArchived ? 'Archived' : (isLost ? 'Lost' : 'Active'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isArchived
                          ? const Color(0xFF64748B)
                          : (isLost
                              ? AppColors.error
                              : const Color(0xFF065F46)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Action row of pet (pill-type buttons)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.call, size: 13),
                    label: Text(
                      'Contact',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side:
                          BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  if (onViewLogs != null) ...[
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: onViewLogs,
                      icon: const Icon(Icons.history_rounded, size: 13),
                      label: Text(
                        'Audit Log',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                            color: const Color(0xFF6366F1).withOpacity(0.6)),
                        foregroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
