import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/admin/admin_analytics_service.dart';

class LostVsFoundTrendChart extends StatelessWidget {
  final List<TrendDataPoint> trendData;
  final TrendGranularity currentGranularity;
  final ValueChanged<TrendGranularity> onGranularityChanged;
  final bool isLoading;

  const LostVsFoundTrendChart({
    super.key,
    required this.trendData,
    required this.currentGranularity,
    required this.onGranularityChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Segmented Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 450;
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(),
                    const SizedBox(height: 10),
                    _buildGranularitySegment(),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTitle(),
                  _buildGranularitySegment(),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Legend
          Row(
            children: [
              _buildLegendItem(
                color: const Color(0xFFEA580C),
                label: 'Reported Lost',
              ),
              const SizedBox(width: 18),
              _buildLegendItem(
                color: const Color(0xFF16A34A),
                label: 'Recovered / Found',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart Canvas
          SizedBox(
            height: 230,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (trendData.isEmpty
                    ? Center(
                        child: Text(
                          'No incident records in this period',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : _buildChart()),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lost vs. Found Trends',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Timeline comparison of missing and recovered pets',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildGranularitySegment() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGranularityItem('Daily', TrendGranularity.daily),
          _buildGranularityItem('Weekly', TrendGranularity.weekly),
          _buildGranularityItem('Monthly', TrendGranularity.monthly),
        ],
      ),
    );
  }

  Widget _buildGranularityItem(String label, TrendGranularity g) {
    final isSelected = currentGranularity == g;
    return InkWell(
      onTap: () => onGranularityChanged(g),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final lostSpots = <FlSpot>[];
    final foundSpots = <FlSpot>[];

    double maxY = 4;
    for (int i = 0; i < trendData.length; i++) {
      final point = trendData[i];
      lostSpots.add(FlSpot(i.toDouble(), point.lostCount.toDouble()));
      foundSpots.add(FlSpot(i.toDouble(), point.foundCount.toDouble()));

      if (point.lostCount > maxY) maxY = point.lostCount.toDouble() + 1;
      if (point.foundCount > maxY) maxY = point.foundCount.toDouble() + 1;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1.0, 100.0),
          getDrawingHorizontalLine: (value) => const FlLine(
            color: Color(0xFFF1F5F9),
            strokeWidth: 1.2,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, meta) {
                if (val % 1 != 0) return const SizedBox.shrink();
                return Text(
                  val.toInt().toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF94A3B8),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1.0,
              getTitlesWidget: (val, meta) {
                final int idx = val.toInt();
                // Reject fractional ticks and out of range indices
                if ((val - idx).abs() > 0.001) return const SizedBox.shrink();
                final total = trendData.length;
                if (idx < 0 || idx >= total) {
                  return const SizedBox.shrink();
                }

                // Show evenly spaced labels without colliding into each other
                final step = (total / 4).ceil().clamp(1, 10);
                final isFirst = idx == 0;
                final isLast = idx == total - 1;

                if (!isFirst && !isLast && (idx % step != 0)) {
                  return const SizedBox.shrink();
                }

                // Prevent collision with the last label at the right boundary
                if (!isLast && (total - 1 - idx) < step) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    trendData[idx].label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        clipData: const FlClipData.all(),
        minX: 0,
        maxX: (trendData.length - 1).toDouble().clamp(0.0, 100.0),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isLost = spot.barIndex == 0;
                final idx = spot.x.toInt();
                final dateLabel =
                    (idx >= 0 && idx < trendData.length) ? trendData[idx].label : '';
                return LineTooltipItem(
                  '${isLost ? 'Lost' : 'Found'}: ${spot.y.toInt()} ($dateLabel)',
                  GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Lost curve
          LineChartBarData(
            spots: lostSpots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: const Color(0xFFEA580C),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFEA580C).withOpacity(0.12),
            ),
          ),
          // Found curve
          LineChartBarData(
            spots: foundSpots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: const Color(0xFF16A34A),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF16A34A).withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
