import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/admin/admin_analytics_service.dart';

class AdminDashboardKpiCards extends StatelessWidget {
  final DashboardAnalyticsData data;
  final bool isLoading;
  final VoidCallback? onActiveLostTap;
  final VoidCallback? onFoundTap;
  final VoidCallback? onCollarTap;

  const AdminDashboardKpiCards({
    super.key,
    required this.data,
    this.isLoading = false,
    this.onActiveLostTap,
    this.onFoundTap,
    this.onCollarTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final cardWidth = isWide
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Active Lost',
                value: data.activeLostReports.toString(),
                subtitle: 'Current Snapshot',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                badgeText: 'Live',
                onTap: onActiveLostTap,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Found This Month',
                value: data.foundThisMonth.toString(),
                subtitle: 'Recovered Pets',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                badgeText: 'Monthly',
                onTap: onFoundTap,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildRecoveryKpiCard(
                title: 'Avg Recovery',
                value: data.formattedAvgRecoveryTime,
                trendPercent: data.recoveryTrendChangePercent,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Collar Pairing',
                value: '${data.collarPairingPercent.toStringAsFixed(0)}%',
                subtitle: '${data.pairedPets} of ${data.totalPets} pets',
                icon: Icons.sensors_rounded,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
                badgeText: 'Snapshot',
                onTap: onCollarTap,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String badgeText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isLoading ? '...' : value,
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryKpiCard({
    required String title,
    required String value,
    required double trendPercent,
  }) {
    final hasTrend = trendPercent != 0.0;
    // For recovery duration, negative % means faster resolution (good)
    final isImproved = trendPercent < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_outlined,
                    color: Color(0xFFEA580C), size: 20),
              ),
              if (hasTrend)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isImproved
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isImproved
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 11,
                        color: isImproved
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${trendPercent.abs().toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isImproved
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Monthly',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isLoading ? '...' : value,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            hasTrend
                ? (isImproved
                    ? 'Faster than last month'
                    : 'Slower than last month')
                : 'Incident to recovery',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
