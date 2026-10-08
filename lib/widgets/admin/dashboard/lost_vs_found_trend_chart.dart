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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                    const SizedBox(height: 6),
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
          const SizedBox(height: 8),

          // Legend
          Row(
            children: [
              _buildLegendItem(
                color: const Color(0xFFEA580C),
                label: 'Reported Lost',
              ),
              const SizedBox(width: 14),
              _buildLegendItem(
                color: const Color(0xFF16A34A),
                label: 'Recovered / Found',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chart Canvas
          SizedBox(
            height: 250,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (trendData.isEmpty
                    ? Center(
                        child: Text(
                          'No incident records in this period',
                          style: GoogleFonts.inter(
                            fontSize: 12,
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
          'Lost and Found',
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

  static String _monthAbbr(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }

  Widget _buildChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final total = trendData.length;
        final pointWidth = total > 0 ? (chartWidth - 50) / total : chartWidth;

        double maxDataY = 4;
        for (int i = 0; i < trendData.length; i++) {
          final point = trendData[i];
          if (point.lostCount > maxDataY) maxDataY = point.lostCount.toDouble();
          if (point.foundCount > maxDataY) maxDataY = point.foundCount.toDouble();
        }

        final double stepY;
        if (maxDataY <= 4) {
          stepY = 1.0;
        } else if (maxDataY <= 10) {
          stepY = 2.0;
        } else if (maxDataY <= 25) {
          stepY = 5.0;
        } else if (maxDataY <= 50) {
          stepY = 10.0;
        } else {
          stepY = (maxDataY / 4).ceilToDouble();
        }

        final double maxY = ((maxDataY * 1.15) / stepY).ceil() * stepY;

        final rodWidth = (pointWidth * 0.24).clamp(5.0, 14.0);

        final barGroups = <BarChartGroupData>[];
        for (int i = 0; i < trendData.length; i++) {
          final point = trendData[i];
          barGroups.add(
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: point.lostCount.toDouble(),
                  color: const Color(0xFFEA580C),
                  width: rodWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: point.foundCount.toDouble(),
                  color: const Color(0xFF16A34A),
                  width: rodWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
              ],
            ),
          );
        }

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              drawHorizontalLine: true,
              horizontalInterval: stepY,
              checkToShowHorizontalLine: (value) => true,
              getDrawingHorizontalLine: (value) => const FlLine(
                color: Color(0xFFCBD5E1),
                strokeWidth: 1.3,
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
                  reservedSize: 42,
                  interval: stepY,
                  getTitlesWidget: (val, meta) {
                    if (val < 0 || val > maxY) return const SizedBox.shrink();
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 8,
                      child: Text(
                        val.toInt().toString(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 1.0,
                  getTitlesWidget: (val, meta) {
                    final int idx = val.toInt();
                    if ((val - idx).abs() > 0.001) return const SizedBox.shrink();
                    if (idx < 0 || idx >= total) {
                      return const SizedBox.shrink();
                    }

                    final point = trendData[idx];

                    Widget labelWidget;
                    if (currentGranularity == TrendGranularity.daily) {
                      if (pointWidth >= 52) {
                        labelWidget = Text(
                          point.label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        );
                      } else if (pointWidth >= 28) {
                        labelWidget = Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _monthAbbr(point.date),
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              point.date.day.toString().padLeft(2, '0'),
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                                height: 1.0,
                              ),
                            ),
                          ],
                        );
                      } else {
                        labelWidget = Text(
                          '${point.date.day}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        );
                      }
                    } else {
                      labelWidget = Text(
                        point.label,
                        style: GoogleFonts.inter(
                          fontSize: pointWidth < 45 ? 9 : 10,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      );
                    }

                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: labelWidget,
                    );
                  },
                ),
              ),
            ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => const Color(0xFF1E293B),
            tooltipRoundedRadius: 8,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isLost = rodIndex == 0;
              final idx = group.x;
              final dateLabel = (idx >= 0 && idx < trendData.length)
                  ? trendData[idx].label
                  : '';
              return BarTooltipItem(
                '${isLost ? 'Lost' : 'Found'}: ${rod.toY.toInt()}\n',
                GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isLost
                      ? const Color(0xFFFB923C)
                      : const Color(0xFF4ADE80),
                ),
                children: [
                  TextSpan(
                    text: dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: barGroups,
      ),
    );
      },
    );
  }
}
