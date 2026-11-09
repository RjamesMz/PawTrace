import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Service to apply anti-fraud security watermarks to government ID photos.
///
/// This burns "FOR PETTRACE VERIFICATION ONLY" and anti-fraud warnings directly
/// into the image pixels and provides overlay widgets, making the ID document
/// unusable for fake identity creation, loans, unauthorized bank/e-wallet accounts,
/// or identity theft while preserving readability for PetTrace administrators.
class IdWatermarkService {
  IdWatermarkService._();

  /// Adds a permanent anti-fraud security watermark to an ID image.
  ///
  /// The watermark stamps:
  /// - Repeated semi-transparent diagonal security lines:
  ///   "FOR PETTRACE VERIFICATION ONLY • NOT FOR OTHER TRANSACTIONS"
  /// - A prominent center diagonal security banner:
  ///   "FOR PETTRACE VERIFICATION ONLY"
  ///   "NOT VALID FOR FAKE IDENTITY • DO NOT DUPLICATE"
  ///   "[DATE] • PETTRACE ID PROTECTION"
  /// - A bottom security banner with an anti-fraud lock stamp.
  static Future<Uint8List> addAntiFraudWatermark(
    Uint8List originalBytes, {
    String? dateString,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final width = img.width.toDouble();
      final height = img.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // 1. Draw the original ID image
      canvas.drawImage(img, Offset.zero, Paint());

      final dateStr =
          dateString ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 2. Compute dynamic scaling based on image dimensions
      final diag = math.sqrt(width * width + height * height);
      final baseFontSize = math.max(14.0, width * 0.038);
      final subFontSize = math.max(10.0, baseFontSize * 0.65);

      // 3. Draw repeating diagonal watermark bands across the ID (-26 degrees)
      canvas.save();
      canvas.translate(width / 2, height / 2);
      canvas.rotate(-0.45); // ~ -26 degrees

      final lineSpacing = baseFontSize * 3.6;
      final count = (diag / lineSpacing).ceil() + 2;

      for (int i = -count; i <= count; i++) {
        final y = i * lineSpacing;
        final isCenter = i.abs() <= 1;

        // Draw translucent dark background band for center lines to guarantee high contrast
        if (isCenter) {
          final bandPaint = Paint()
            ..color = const Color(0x38000000) // ~22% black tint
            ..style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(
                -diag, y - (baseFontSize * 0.35), diag * 2, baseFontSize * 2.3),
            bandPaint,
          );
        }

        final primaryText = 'FOR PETTRACE VERIFICATION ONLY   •   ';

        final tp1 = TextPainter(
          text: TextSpan(
            text: primaryText,
            style: TextStyle(
              color: isCenter
                  ? Colors.white.withOpacity(0.60)
                  : Colors.white.withOpacity(0.44),
              fontSize: isCenter ? baseFontSize * 1.0 : baseFontSize * 0.85,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              shadows: const [
                Shadow(color: Color(0x99000000), offset: Offset(-0.8, -0.8), blurRadius: 1.0),
                Shadow(color: Color(0x99000000), offset: Offset(0.8, -0.8), blurRadius: 1.0),
                Shadow(color: Color(0x99000000), offset: Offset(-0.8, 0.8), blurRadius: 1.0),
                Shadow(color: Color(0x99000000), offset: Offset(0.8, 0.8), blurRadius: 1.0),
              ],
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        final itemWidth = tp1.width;
        final rowOffset = (i % 2 == 0) ? 0.0 : (itemWidth * 0.5);
        for (double x = -diag - itemWidth; x <= diag + itemWidth; x += itemWidth) {
          tp1.paint(canvas, Offset(x + rowOffset, y));
        }

        if (isCenter) {
          final subText =
              'NOT VALID FOR FAKE IDENTITY • DO NOT DUPLICATE • $dateStr   •   ';
          final tp2 = TextPainter(
            text: TextSpan(
              text: subText,
              style: TextStyle(
                color: const Color(0xE0FECACA), // subtle warning tint
                fontSize: subFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                shadows: const [
                  Shadow(color: Color(0x99000000), offset: Offset(-0.6, -0.6), blurRadius: 1.0),
                  Shadow(color: Color(0x99000000), offset: Offset(0.6, -0.6), blurRadius: 1.0),
                  Shadow(color: Color(0x99000000), offset: Offset(-0.6, 0.6), blurRadius: 1.0),
                  Shadow(color: Color(0x99000000), offset: Offset(0.6, 0.6), blurRadius: 1.0),
                ],
              ),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();

          final subItemWidth = tp2.width;
          for (double x = -diag - subItemWidth; x <= diag + subItemWidth; x += subItemWidth) {
            tp2.paint(canvas, Offset(x + rowOffset, y + baseFontSize * 1.18));
          }
        }
      }

      canvas.restore();

      // 4. Draw a bottom security stamp banner across the bottom of the image
      final bannerHeight = math.max(22.0, height * 0.065);
      final bottomBannerRect =
          Rect.fromLTWH(0, height - bannerHeight, width, bannerHeight);

      final bottomBgPaint = Paint()
        ..color = const Color(0xD90F172A) // 85% slate-900
        ..style = PaintingStyle.fill;
      canvas.drawRect(bottomBannerRect, bottomBgPaint);

      // Top colored border on the banner (red security accent)
      final borderPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = math.max(1.5, height * 0.005)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, height - bannerHeight),
        Offset(width, height - bannerHeight),
        borderPaint,
      );

      final bannerTextPainter = TextPainter(
        text: TextSpan(
          text:
              '🔒 FOR PETTRACE VERIFICATION ONLY • NOT VALID FOR OTHER USE • $dateStr',
          style: TextStyle(
            color: Colors.white,
            fontSize: math.max(9.0, bannerHeight * 0.42),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 20);

      bannerTextPainter.paint(
        canvas,
        Offset(
          (width - bannerTextPainter.width) / 2,
          height - bannerHeight + (bannerHeight - bannerTextPainter.height) / 2,
        ),
      );

      // 5. Complete picture and encode to PNG bytes
      final picture = recorder.endRecording();
      final watermarkedImage =
          await picture.toImage(width.toInt(), height.toInt());
      final byteData =
          await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return originalBytes;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[IdWatermarkService] Error applying watermark: $e');
      return originalBytes;
    }
  }
}

/// Visual overlay widget providing real-time anti-fraud watermark styling over ID preview cards.
class IdWatermarkOverlay extends StatelessWidget {
  final bool showBadge;
  final String? customText;

  const IdWatermarkOverlay({
    super.key,
    this.showBadge = true,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Diagonal repeating watermark pattern
          CustomPaint(
            painter: _WatermarkPainter(
              text: customText ?? 'FOR PETTRACE VERIFICATION ONLY',
            ),
          ),

          // Anti-Fraud Protection Pill Badge
          if (showBadge)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCC0F172A), // 80% slate-900
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 11,
                      color: Color(0xFF34D399),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Watermarked • Anti-Fraud Protection',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;

  const _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.45); // ~ -26 degrees

    const fontSize = 11.0;
    const spacing = 38.0;
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final count = (diag / spacing).ceil() + 2;

    // Toned-down highlighted watermark with subtle dark outline shadow
    final tp = TextPainter(
      text: TextSpan(
        text: '$text   •   ',
        style: TextStyle(
          color: Colors.white.withOpacity(0.50), // Balanced, readable & non-intrusive
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          shadows: const [
            Shadow(color: Color(0x99000000), offset: Offset(-0.8, -0.8), blurRadius: 1.0),
            Shadow(color: Color(0x99000000), offset: Offset(0.8, -0.8), blurRadius: 1.0),
            Shadow(color: Color(0x99000000), offset: Offset(-0.8, 0.8), blurRadius: 1.0),
            Shadow(color: Color(0x99000000), offset: Offset(0.8, 0.8), blurRadius: 1.0),
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final itemWidth = tp.width;

    for (int i = -count; i <= count; i++) {
      final y = i * spacing;
      final rowOffset = (i % 2 == 0) ? 0.0 : (itemWidth * 0.5);
      for (double x = -diag - itemWidth; x <= diag + itemWidth; x += itemWidth) {
        tp.paint(canvas, Offset(x + rowOffset, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) =>
      oldDelegate.text != text;
}
