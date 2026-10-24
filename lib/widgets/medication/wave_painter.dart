// lib/widgets/medication/wave_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter que dibuja múltiples capas de ondas senoidales fluidas
/// animadas para fondos dinámicos de tarjetas médicas.
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;

    final paint2 =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final paint3 =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    final paint4 =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final path1 = Path();
    final path2 = Path();
    final path3 = Path();
    final path4 = Path();

    final yOffset1 = size.height * 0.6;
    final yOffset2 = size.height * 0.45;
    final yOffset3 = size.height * 0.75;
    final yOffset4 = size.height * 0.35;

    const amplitude1 = 12.0;
    const amplitude2 = 8.0;
    const amplitude3 = 10.0;
    const amplitude4 = 6.0;

    final wavelength1 = size.width * 1.2;
    final wavelength2 = size.width * 0.9;
    final wavelength3 = size.width * 1.5;
    final wavelength4 = size.width * 0.7;

    path1.moveTo(0, yOffset1);
    path2.moveTo(0, yOffset2);
    path3.moveTo(0, yOffset3);
    path4.moveTo(0, yOffset4);

    // Step by 3px instead of 1px to cut trigonometric overhead by 3x without visual difference
    for (double x = 0; x <= size.width; x += 3) {
      // First wave (moving left to right)
      final relativeX1 = x / wavelength1;
      final y1 =
          yOffset1 +
          math.sin(
                (relativeX1 * 2 * math.pi) + (animationValue * 2 * math.pi),
              ) *
              amplitude1;
      path1.lineTo(x, y1);

      // Second wave (moving right to left)
      final relativeX2 = x / wavelength2;
      final y2 =
          yOffset2 +
          math.sin(
                (relativeX2 * 2 * math.pi) -
                    (animationValue * 2 * math.pi) +
                    (math.pi / 3),
              ) *
              amplitude2;
      path2.lineTo(x, y2);

      // Third wave (slower / wider)
      final relativeX3 = x / wavelength3;
      final y3 =
          yOffset3 +
          math.sin(
                (relativeX3 * 2 * math.pi) +
                    (animationValue * 2 * math.pi) -
                    (math.pi / 4),
              ) *
              amplitude3;
      path3.lineTo(x, y3);

      // Fourth wave (faster / narrower)
      final relativeX4 = x / wavelength4;
      final y4 =
          yOffset4 +
          math.sin(
                (relativeX4 * 2 * math.pi) -
                    (animationValue * 4 * math.pi) +
                    (math.pi / 6),
              ) *
              amplitude4;
      path4.lineTo(x, y4);
    }

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
    canvas.drawPath(path3, paint3);
    canvas.drawPath(path4, paint4);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
