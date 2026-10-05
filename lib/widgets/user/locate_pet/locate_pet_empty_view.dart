import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Placeholder displayed on Locate Pet screen when coordinates are null
class LocatePetEmptyView extends StatelessWidget {
  final bool hasCollar;

  const LocatePetEmptyView({super.key, required this.hasCollar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                hasCollar
                    ? Icons.gps_not_fixed_rounded
                    : Icons.location_off_rounded,
                size: 48,
                color: hasCollar
                    ? AppColors.primary
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasCollar ? 'Getting Location…' : 'No Location Available',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasCollar
                  ? 'Waiting for the collar to send its first GPS ping.'
                  : 'Pair a GPS collar to start tracking your pet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
