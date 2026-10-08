import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PetDemographicsDonutCharts extends StatelessWidget {
  final int catCount;
  final int dogCount;
  final int otherSpeciesCount;
  final int activePetCount;
  final int lostPetCount;
  final int archivedPetCount;
  final bool isLoading;

  const PetDemographicsDonutCharts({
    super.key,
    required this.catCount,
    required this.dogCount,
    required this.otherSpeciesCount,
    required this.activePetCount,
    required this.lostPetCount,
    required this.archivedPetCount,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 420;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSpeciesDonutCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusDonutCard()),
            ],
          );
        }
        return Column(
          children: [
            _buildSpeciesDonutCard(),
            const SizedBox(height: 12),
            _buildStatusDonutCard(),
          ],
        );
      },
    );
  }

  Widget _buildSpeciesDonutCard() {
    final total = catCount + dogCount + otherSpeciesCount;
    final catPct = total > 0 ? (catCount / total * 100).round() : 0;
    final dogPct = total > 0 ? (dogCount / total * 100).round() : 0;

    final otherPct = total > 0 ? (otherSpeciesCount / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
            children: [
              Text(
                'Species Ratio',
                style: GoogleFonts.montserrat(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$total Pets',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            'Cat vs. Dog registered community balance',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: total == 0
                ? const Center(child: Text('No pets registered', style: TextStyle(fontSize: 11)))
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 28,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFFF97316), // Orange Cat
                                value:
                                    catCount > 0 ? catCount.toDouble() : 0.001,
                                title: '$catPct%',
                                radius: 20,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF3B82F6), // Blue Dog
                                value:
                                    dogCount > 0 ? dogCount.toDouble() : 0.001,
                                title: '$dogPct%',
                                radius: 20,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (otherSpeciesCount > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF10B981), // Emerald
                                  value: otherSpeciesCount.toDouble(),
                                  title: '$otherPct%',
                                  radius: 20,
                                  titleStyle: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendRow(
                              color: const Color(0xFFF97316),
                              label: '🐱 Cats',
                              count: catCount,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendRow(
                              color: const Color(0xFF3B82F6),
                              label: '🐶 Dogs',
                              count: dogCount,
                            ),
                            if (otherSpeciesCount > 0) ...[
                              const SizedBox(height: 8),
                              _buildLegendRow(
                                color: const Color(0xFF10B981),
                                label: '🐾 Other',
                                count: otherSpeciesCount,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDonutCard() {
    final total = activePetCount + lostPetCount + archivedPetCount;
    final activePct = total > 0 ? (activePetCount / total * 100).round() : 0;
    final lostPct = total > 0 ? (lostPetCount / total * 100).round() : 0;
    final archPct = total > 0 ? (archivedPetCount / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
            children: [
              Text(
                'Pet Status Composition',
                style: GoogleFonts.montserrat(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$total Total',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            'Safety, incident, and archive breakdown',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: total == 0
                ? const Center(child: Text('No pets registered', style: TextStyle(fontSize: 11)))
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 28,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFF16A34A), // Green Active
                                value: activePetCount > 0
                                    ? activePetCount.toDouble()
                                    : 0.001,
                                title: '$activePct%',
                                radius: 20,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFDC2626), // Red Lost
                                value: lostPetCount > 0
                                    ? lostPetCount.toDouble()
                                    : 0.001,
                                title: '$lostPct%',
                                radius: 20,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                color:
                                    const Color(0xFF94A3B8), // Slate Archived
                                value: archivedPetCount > 0
                                    ? archivedPetCount.toDouble()
                                    : 0.001,
                                title: archPct > 0 ? '$archPct%' : '',
                                radius: 20,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendRow(
                              color: const Color(0xFF16A34A),
                              label: 'Active',
                              count: activePetCount,
                            ),
                            const SizedBox(height: 4),
                            _buildLegendRow(
                              color: const Color(0xFFDC2626),
                              label: 'Lost',
                              count: lostPetCount,
                            ),
                            const SizedBox(height: 4),
                            _buildLegendRow(
                              color: const Color(0xFF94A3B8),
                              label: 'Archived',
                              count: archivedPetCount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow({
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
