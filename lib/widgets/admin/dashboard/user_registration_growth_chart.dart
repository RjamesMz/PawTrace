import 'dart:math' as math;
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToEndDelayed();
  }

  @override
  void didUpdateWidget(covariant UserRegistrationGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.growthData.length != widget.growthData.length) {
      _scrollToEndDelayed();
    }
  }

  void _scrollToEndDelayed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showEnlargedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _EnlargedGrowthChartDialog(
        growthData: widget.growthData,
        initialShowCumulative: _showCumulative,
      ),
    );
  }

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
                          _showCumulative ? '$latestTotal' : '+$totalNewInPeriod',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Enlarge graph & scroll full timeline',
                    child: InkWell(
                      onTap: () => _showEnlargedDialog(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.open_in_full_rounded, size: 12, color: Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
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
                    : _buildChart(
                        growthData: widget.growthData,
                        showCumulative: _showCumulative,
                        scrollController: _scrollController,
                        isEnlarged: false,
                      )),
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
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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

  static Widget _buildChart({
    required List<UserGrowthPoint> growthData,
    required bool showCumulative,
    required ScrollController scrollController,
    required bool isEnlarged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final total = growthData.length;
        if (total == 0) return const SizedBox.shrink();

        final minPointWidth = isEnlarged ? 52.0 : 38.0;
        final yAxisWidth = 38.0;
        final plotWidth = availableWidth - yAxisWidth;
        final contentWidth = math.max(plotWidth, total * minPointWidth);
        final isScrollable = contentWidth > plotWidth;
        final pointWidth = contentWidth / total;

        double maxDataY = 4;
        for (int i = 0; i < growthData.length; i++) {
          final point = growthData[i];
          final val = showCumulative
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
        final rodWidth = (pointWidth * 0.40).clamp(6.0, 22.0);

        final barGroups = <BarChartGroupData>[];
        for (int i = 0; i < growthData.length; i++) {
          final point = growthData[i];
          final val = showCumulative
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

        return Row(
          children: [
            // 1. Pinned Left Y-Axis
            SizedBox(
              width: yAxisWidth,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: stepY,
                        getTitlesWidget: (val, meta) {
                          if (val < 0 || val > maxY) return const SizedBox.shrink();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(
                              val.toInt().toString(),
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(toY: 0, width: 0, color: Colors.transparent),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Horizontally Scrollable Bars Canvas
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: isScrollable,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    child: BarChart(
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
                            strokeWidth: 1.2,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              interval: 1.0,
                              getTitlesWidget: (val, meta) {
                                final int idx = val.toInt();
                                if ((val - idx).abs() > 0.001) return const SizedBox.shrink();
                                if (idx < 0 || idx >= total) return const SizedBox.shrink();
                                final point = growthData[idx];

                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 6,
                                  child: Column(
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
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => const Color(0xFF0F172A),
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final idx = group.x;
                              final dateLabel = (idx >= 0 && idx < growthData.length)
                                  ? growthData[idx].label
                                  : '';
                              final val = rod.toY.toInt();
                              return BarTooltipItem(
                                '${showCumulative ? 'Total' : 'New'}: $val\n',
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
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENLARGED FULLSCREEN DIALOG FOR USER REGISTRATION GROWTH
// ─────────────────────────────────────────────────────────────────────────────

class _EnlargedGrowthChartDialog extends StatefulWidget {
  final List<UserGrowthPoint> growthData;
  final bool initialShowCumulative;

  const _EnlargedGrowthChartDialog({
    required this.growthData,
    required this.initialShowCumulative,
  });

  @override
  State<_EnlargedGrowthChartDialog> createState() =>
      _EnlargedGrowthChartDialogState();
}

class _EnlargedGrowthChartDialogState extends State<_EnlargedGrowthChartDialog> {
  late bool _showCumulative;
  final ScrollController _dialogScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _showCumulative = widget.initialShowCumulative;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dialogScrollCtrl.hasClients &&
          _dialogScrollCtrl.position.maxScrollExtent > 0) {
        _dialogScrollCtrl.jumpTo(_dialogScrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _dialogScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToStart() {
    if (_dialogScrollCtrl.hasClients) {
      _dialogScrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToEnd() {
    if (_dialogScrollCtrl.hasClients) {
      _dialogScrollCtrl.animateTo(
        _dialogScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = math.min(1100.0, screenSize.width * 0.94);
    final dialogHeight = math.min(620.0, screenSize.height * 0.88);

    final latestTotal = widget.growthData.isNotEmpty
        ? widget.growthData.last.cumulativeUsers
        : 0;
    final totalNew =
        widget.growthData.fold<int>(0, (sum, p) => sum + p.newUsers);

    final firstDateStr = widget.growthData.isNotEmpty ? widget.growthData.first.label : '';
    final lastDateStr = widget.growthData.isNotEmpty ? widget.growthData.last.label : '';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Row ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Registration Growth Timeline',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$firstDateStr — $lastDateStr • Scroll horizontally to inspect any date',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Controls & Quick Jump Buttons ────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Toggle
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogToggleItem('Cumulative Total ($latestTotal)', true),
                      _buildDialogToggleItem('New Signups (+$totalNew)', false),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Quick Navigation Jumps
                OutlinedButton.icon(
                  onPressed: _scrollToStart,
                  icon: const Icon(Icons.first_page_rounded, size: 16),
                  label: Text('Jump to Start (${firstDateStr.split(' ').firstOrNull ?? 'Oct 1'})',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _scrollToEnd,
                  icon: const Icon(Icons.last_page_rounded, size: 16),
                  label: Text('Jump to Latest',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Main Enlarged Chart Canvas ───────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: _UserRegistrationGrowthChartState._buildChart(
                  growthData: widget.growthData,
                  showCumulative: _showCumulative,
                  scrollController: _dialogScrollCtrl,
                  isEnlarged: true,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Footer Info & Tip ────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.swipe_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Tip: Drag or use mouse wheel to scroll horizontally through the entire date timeline.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const Spacer(),
                Text(
                  'Total Data Points: ${widget.growthData.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogToggleItem(String label, bool isCumulative) {
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
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
