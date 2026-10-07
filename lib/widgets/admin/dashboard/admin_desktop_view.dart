import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../screens/admin/reports/admin_reports_screen.dart';
import 'admin_dashboard_analytics_view.dart';

class AdminDesktopView extends StatelessWidget {
  final String adminBarangay;
  final int registeredPets;
  final int lostReports;
  final int registeredUsers;
  final bool isLoading;
  final List<Map<String, dynamic>> pendingReports;
  final List<Map<String, dynamic>> recentActivity;

  const AdminDesktopView({
    super.key,
    required this.adminBarangay,
    required this.registeredPets,
    required this.lostReports,
    required this.registeredUsers,
    required this.isLoading,
    required this.pendingReports,
    required this.recentActivity,
  });

  String _formatRelativeTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner
        Container(
          height: 90,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6600), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6600).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Good morning Admin',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminBarangay.isNotEmpty
                          ? 'Brgy. $adminBarangay • Admin Operations'
                          : 'Admin Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_work_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Complete Dashboard Operations & Analytics
        AdminDashboardAnalyticsView(
          adminBarangay: adminBarangay,
        ),
        const SizedBox(height: 24),

        // Operational queues: left 60%, right 40%
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left 60%: Pending verification reports
            Expanded(
              flex: 6,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lost Pet Reports',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminReportsScreen()),
                            ),
                            child: Text(
                              'View All',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      if (pendingReports.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No pending reports to verify',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pendingReports.length > 5
                              ? 5
                              : pendingReports.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: Color(0x12000000)),
                          itemBuilder: (context, index) {
                            final report = pendingReports[index];
                            final pet = report['pets'];
                            final petName = pet is Map
                                ? (pet['name']?.toString() ?? 'Unknown Pet')
                                : 'Unknown Pet';
                            final petPhoto = pet is Map
                                ? (pet['photo_url']?.toString() ?? '')
                                : '';
                            final location = report['barangay']?.toString() ??
                                adminBarangay;
                            final status =
                                (report['status']?.toString() ?? 'pending')
                                    .toUpperCase();

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryContainer,
                                backgroundImage: petPhoto.isNotEmpty
                                    ? NetworkImage(petPhoto)
                                    : null,
                              child: petPhoto.isEmpty
                                  ? const Icon(Icons.pets,
                                      size: 16, color: AppColors.primary)
                                  : null,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    petName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 12,
                                      color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text(
                                    location,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminReportsScreen()),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Review',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right 40%: Recent activity timeline
            Expanded(
              flex: 4,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      if (recentActivity.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              'No recent activity',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentActivity.length > 6
                              ? 6
                              : recentActivity.length,
                          itemBuilder: (context, index) {
                            final act = recentActivity[index];
                            final desc = act['description']?.toString() ?? '';
                            final color =
                                (act['color'] as Color?) ?? AppColors.primary;
                            final ts = act['timestamp']?.toString() ?? '';
                            final isLast = index ==
                                ((recentActivity.length > 6
                                        ? 6
                                        : recentActivity.length) -
                                    1);

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 1.5,
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (ts.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatRelativeTime(ts),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Alias for compatibility
typedef BarangayAdminDesktopView = AdminDesktopView;
