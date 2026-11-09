import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/admin/admin_analytics_service.dart';

class LostVsFoundTrendChart extends StatefulWidget {
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
  State<LostVsFoundTrendChart> createState() => _LostVsFoundTrendChartState();
}

class _LostVsFoundTrendChartState extends State<LostVsFoundTrendChart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToEndDelayed();
  }

  @override
  void didUpdateWidget(covariant LostVsFoundTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trendData.length != widget.trendData.length ||
        oldWidget.currentGranularity != widget.currentGranularity) {
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
      builder: (_) => _EnlargedTrendChartDialog(
        trendData: widget.trendData,
        currentGranularity: widget.currentGranularity,
        onGranularityChanged: widget.onGranularityChanged,
      ),
    );
  }

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
          // Header + Segmented Buttons + Enlarge Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildTitle()),
                        _buildEnlargeButton(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildGranularitySegment(),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTitle(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGranularitySegment(),
                      const SizedBox(width: 8),
                      _buildEnlargeButton(),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Legend & Scroll Hint
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
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (widget.trendData.isEmpty
                    ? Center(
                        child: Text(
                          'No incident records in this period',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : _buildChart(
                        trendData: widget.trendData,
                        currentGranularity: widget.currentGranularity,
                        scrollController: _scrollController,
                        isEnlarged: false,
                      )),
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

  Widget _buildEnlargeButton() {
    return Tooltip(
      message: 'Enlarge graph & scroll full timeline',
      child: InkWell(
        onTap: () => _showEnlargedDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_full_rounded, size: 12, color: Color(0xFF475569)),
              const SizedBox(width: 4),
              Text(
                'Enlarge',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final isSelected = widget.currentGranularity == g;
    return InkWell(
      onTap: () => widget.onGranularityChanged(g),
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

  static Widget _buildChart({
    required List<TrendDataPoint> trendData,
    required TrendGranularity currentGranularity,
    required ScrollController scrollController,
    required bool isEnlarged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final total = trendData.length;
        if (total == 0) return const SizedBox.shrink();

        final minPointWidth = isEnlarged ? 52.0 : 38.0;
        final yAxisWidth = 38.0;
        final plotWidth = availableWidth - yAxisWidth;
        final contentWidth = math.max(plotWidth, total * minPointWidth);
        final isScrollable = contentWidth > plotWidth;
        final pointWidth = contentWidth / total;

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
        final rodWidth = (pointWidth * 0.25).clamp(5.0, 15.0);

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

        return Row(
          children: [
            // 1. Pinned Y-Axis
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
                        BarChartRodData(
                          toY: 0,
                          width: 0,
                          color: Colors.transparent,
                        ),
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
                          getDrawingHorizontalLine: (value) => const FlLine(
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
                                final point = trendData[idx];

                                Widget labelWidget;
                                if (currentGranularity == TrendGranularity.daily) {
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
                                    point.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
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
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => const Color(0xFF1E293B),
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
// ENLARGED FULLSCREEN DIALOG FOR SCROLLABLE INSPECTION (e.g. Oct 1 - Oct 30)
// ─────────────────────────────────────────────────────────────────────────────

class _EnlargedTrendChartDialog extends StatefulWidget {
  final List<TrendDataPoint> trendData;
  final TrendGranularity currentGranularity;
  final ValueChanged<TrendGranularity> onGranularityChanged;

  const _EnlargedTrendChartDialog({
    required this.trendData,
    required this.currentGranularity,
    required this.onGranularityChanged,
  });

  @override
  State<_EnlargedTrendChartDialog> createState() =>
      _EnlargedTrendChartDialogState();
}

class _EnlargedTrendChartDialogState extends State<_EnlargedTrendChartDialog> {
  late TrendGranularity _granularity;
  final ScrollController _dialogScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _granularity = widget.currentGranularity;
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

    final totalLost = widget.trendData.fold<int>(0, (sum, p) => sum + p.lostCount);
    final totalFound = widget.trendData.fold<int>(0, (sum, p) => sum + p.foundCount);

    final firstDateStr = widget.trendData.isNotEmpty ? widget.trendData.first.label : '';
    final lastDateStr = widget.trendData.isNotEmpty ? widget.trendData.last.label : '';

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
                    color: AppColors.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lost and Found Timeline (All Dates)',
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
                // Legend items
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(
                      color: const Color(0xFFEA580C),
                      label: 'Reported Lost ($totalLost)',
                    ),
                    const SizedBox(width: 14),
                    _buildLegendItem(
                      color: const Color(0xFF16A34A),
                      label: 'Recovered / Found ($totalFound)',
                    ),
                  ],
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
                child: _LostVsFoundTrendChartState._buildChart(
                  trendData: widget.trendData,
                  currentGranularity: _granularity,
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
                  'Total Data Points: ${widget.trendData.length}',
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

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
}
