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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _showCumulative
                              ? '$latestTotal'
                              : '+$totalNewInPeriod',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded,
                                  size: 12, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                _showCumulative ? 'Total Users' : 'New Signups',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Community adoption trend across the barangay',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (widget.growthData.isEmpty
                    ? Center(
                        child: Text(
                          'No registration data found for this period',
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

  Widget _buildChart() {
    final spots = <FlSpot>[];
    double maxY = 5;

    for (int i = 0; i < widget.growthData.length; i++) {
      final point = widget.growthData[i];
      final val = _showCumulative
          ? point.cumulativeUsers.toDouble()
          : point.newUsers.toDouble();
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxY) maxY = val + 1;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1.0, 100.0),
          getDrawingHorizontalLine: (v) => const FlLine(
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
              reservedSize: 32,
              getTitlesWidget: (val, meta) {
                if (val % 1 != 0) return const SizedBox.shrink();
                return Text(
                  val.toInt().toString(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1.0,
              getTitlesWidget: (val, meta) {
                final int idx = val.toInt();
                // Reject fractional ticks and out of range indices
                if ((val - idx).abs() > 0.001) return const SizedBox.shrink();
                final total = widget.growthData.length;
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
                    widget.growthData[idx].label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
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
        maxX: (widget.growthData.length - 1).toDouble().clamp(0.0, 100.0),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final label = (idx >= 0 && idx < widget.growthData.length)
                    ? widget.growthData[idx].label
                    : '';
                return LineTooltipItem(
                  '${_showCumulative ? 'Total' : 'New'}: ${spot.y.toInt()} ($label)',
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
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: const Color(0xFF2563EB),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isLast = index == barData.spots.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 5.5 : 3.5,
                  color: isLast
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF2563EB),
                  strokeWidth: isLast ? 2.5 : 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF2563EB).withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}
