import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/admin/admin_analytics_service.dart';

class UserRegistrationGrowthChart extends StatefulWidget {
  final List<UserGrowthPoint> growthData;
  final bool isLoading;

  const UserRegistrationGrowthChart({
    super.key,
    required this.growthData,
    this.isLoading = false,
  });

  @override
  State<UserRegistrationGrowthChart> createState() =>
      _UserRegistrationGrowthChartState();
}

class _UserRegistrationGrowthChartState
    extends State<UserRegistrationGrowthChart> {
  bool _showCumulative = true;

  @override
  Widget build(BuildContext context) {
    final latestTotal = widget.growthData.isNotEmpty
        ? widget.growthData.last.cumulativeUsers
        : 0;
    final totalNewInPeriod =
        widget.growthData.fold<int>(0, (sum, item) => sum + item.newUsers);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'User Registration Growth',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _showCumulative
                              ? '$latestTotal'
                              : '+$totalNewInPeriod',
                          style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded,
                                  size: 11, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                _showCumulative ? 'Total Users' : 'New Signups',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Community adoption trend across the barangay',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem('Cumulative', true),
                    _buildToggleItem('New', false),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 274,
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (widget.growthData.isEmpty
                    ? Center(
                        child: Text(
                          'No registration data found for this period',
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

  Widget _buildToggleItem(String label, bool isCumulative) {
    final isSelected = _showCumulative == isCumulative;
    return InkWell(
      onTap: () => setState(() => _showCumulative = isCumulative),
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
            color:
                isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
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
        final total = widget.growthData.length;
        final pointWidth = total > 0 ? (chartWidth - 50) / total : chartWidth;

        double maxDataY = 4;
        for (int i = 0; i < widget.growthData.length; i++) {
          final point = widget.growthData[i];
          final val = _showCumulative
              ? point.cumulativeUsers.toDouble()
              : point.newUsers.toDouble();
          if (val > maxDataY) maxDataY = val;
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

        final rodWidth = (pointWidth * 0.42).clamp(6.0, 22.0);

        final barGroups = <BarChartGroupData>[];
        for (int i = 0; i < widget.growthData.length; i++) {
          final point = widget.growthData[i];
          final val = _showCumulative
              ? point.cumulativeUsers.toDouble()
              : point.newUsers.toDouble();
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: const Color(0xFF2563EB),
                  width: rodWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
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
              getDrawingHorizontalLine: (v) => const FlLine(
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

                    final point = widget.growthData[idx];

                    Widget labelWidget;
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
                  final idx = group.x;
                  final dateLabel = (idx >= 0 && idx < widget.growthData.length)
                      ? widget.growthData[idx].label
                      : '';
                  final prefix =
                      _showCumulative ? 'Total Users' : 'New Signups';
                  return BarTooltipItem(
                    '$prefix: ${rod.toY.toInt()}\n',
                    GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF60A5FA),
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
