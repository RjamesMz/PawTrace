import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../common/photo_placeholder.dart';
import '../../screens/admin/reports/admin_reports_screen.dart';

/// Barangay summary card for SuperAdmin overview carousel.
class SuperAdminBarangayCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  const SuperAdminBarangayCard({
    super.key,
    required this.data,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? '';
    final petCount = data['pets'] as int? ?? 0;
    final lostCount = data['lost'] as int? ?? 0;
    final adminName = data['admin']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Pet count pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$petCount pets',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Lost / safe pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: lostCount > 0
                    ? AppColors.errorContainer.withOpacity(0.4)
                    : const Color(0xFF22C55E).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lostCount > 0 ? '$lostCount lost' : 'All Safe',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: lostCount > 0
                      ? AppColors.error
                      : const Color(0xFF22C55E),
                ),
              ),
            ),
            const Spacer(),
            // Admin name
            Text(
              adminName != null && adminName.isNotEmpty
                  ? adminName
                  : 'No Admin Assigned',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: adminName != null && adminName.isNotEmpty
                    ? AppColors.onSurfaceVariant
                    : AppColors.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin card for Barangay Admins list in SuperAdmin dashboard.
class SuperAdminAdminCard extends StatelessWidget {
  final Map<String, dynamic> admin;
  final Function(String userId, String email, bool isDeactivated) onToggleStatus;

  const SuperAdminAdminCard({
    super.key,
    required this.admin,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final fName = admin['first_name'] as String? ?? '';
    final sName = admin['surname'] as String? ?? '';
    final email = admin['email'] as String? ?? '';
    final phone = admin['phone'] as String? ?? '';
    final barangay = admin['barangay'] as String? ?? '';
    final userId = admin['user_id'] as String? ?? '';
    final initial = fName.isNotEmpty ? fName[0].toUpperCase() : 'A';
    final rawStatus = (admin['status'] ?? 'active').toString().toLowerCase();
    final isDeactivated =
        rawStatus == 'deactivated' || rawStatus == 'de_activated';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              initial,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fName $sName',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (barangay.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              constraints: const BoxConstraints(maxWidth: 80),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                barangay,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          IconButton(
            tooltip: isDeactivated ? 'Reactivate Admin' : 'Deactivate Admin',
            icon: Icon(
              isDeactivated
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              color: isDeactivated
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
              size: 20,
            ),
            onPressed: () => onToggleStatus(userId, email, isDeactivated),
          ),
        ],
      ),
    );
  }
}

/// Report item card for recent reports in SuperAdmin dashboard.
class SuperAdminReportItem extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool removeBottomMargin;
  final VoidCallback onRefreshNeeded;

  const SuperAdminReportItem({
    super.key,
    required this.report,
    this.removeBottomMargin = false,
    required this.onRefreshNeeded,
  });

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = report['pets'];
    final petName =
        pet is Map ? (pet['name']?.toString() ?? 'Unknown Pet') : 'Unknown Pet';
    final petPhoto = pet is Map ? (pet['photo_url']?.toString() ?? '') : '';

    final owner = report['owner_id'];
    final ownerName = owner is Map
        ? '${owner['first_name'] ?? ''} ${owner['surname'] ?? ''}'.trim()
        : 'Unknown Owner';

    final barangay = report['barangay']?.toString() ??
        report['municipality']?.toString() ??
        '';
    final reportedAt = report['reported_at']?.toString() ?? '';
    final reportStatus =
        (report['status']?.toString() ?? 'active').toLowerCase();
    final petStatus =
        pet is Map ? (pet['status']?.toString() ?? '').toLowerCase() : '';

    final bool isFound = reportStatus == 'resolved' ||
        reportStatus == 'found' ||
        report['is_found'] == true ||
        (petStatus == 'active' && reportStatus == 'archived') ||
        petStatus == 'found';
    final String petCondition = isFound ? 'FOUND' : 'LOST';

    String formattedDate = '';
    String formattedTime = '';
    if (reportedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(reportedAt).toLocal();
        formattedDate = '${dt.month}/${dt.day}/${dt.year}';
        final hour =
            dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour < 12 ? 'AM' : 'PM';
        formattedTime = '$hour:$minute $period';
      } catch (_) {
        formattedDate = reportedAt;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: removeBottomMargin ? 0 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
            );
            onRefreshNeeded();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: petPhoto.isNotEmpty
                      ? Image.network(
                          petPhoto,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const PhotoPlaceholder(
                            width: 52,
                            height: 52,
                            iconSize: 22,
                          ),
                        )
                      : const PhotoPlaceholder(
                          width: 52,
                          height: 52,
                          iconSize: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petName,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Owner: $ownerName',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (barangay.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          barangay,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (formattedDate.isNotEmpty)
                        Text(
                          '$formattedDate • $formattedTime (${_formatTimeAgo(reportedAt)})',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: petCondition == 'FOUND'
                        ? const Color(0xFF22C55E).withOpacity(0.15)
                        : AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    petCondition,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: petCondition == 'FOUND'
                          ? const Color(0xFF16A34A)
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
