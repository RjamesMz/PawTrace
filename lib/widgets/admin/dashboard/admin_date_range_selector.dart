import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/admin/admin_analytics_service.dart';

class AdminDateRangeSelector extends StatelessWidget {
  final DashboardDateRange selectedRange;
  final ValueChanged<DashboardDateRange> onRangeChanged;

  const AdminDateRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(
              label: 'This Month',
              range: DashboardDateRange.thisMonth,
            ),
            const SizedBox(width: 4),
            _buildOption(
              label: 'Last 3 Months',
              range: DashboardDateRange.last3Months,
            ),
            const SizedBox(width: 4),
            _buildOption(
              label: 'This Year',
              range: DashboardDateRange.thisYear,
            ),
            const SizedBox(width: 4),
            _buildOption(
              label: 'All Time',
              range: DashboardDateRange.allTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String label,
    required DashboardDateRange range,
  }) {
    final isSelected = selectedRange == range;
    return InkWell(
      onTap: () => onRangeChanged(range),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
