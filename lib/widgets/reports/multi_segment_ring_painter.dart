// lib/widgets/reports/multi_segment_ring_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

/// CustomPainter que dibuja un anillo circular segmentado con esquinas redondeadas
/// para representar la proporción de dosis tomadas, omitidas, notificadas y aplazadas.
class MultiSegmentRingPainter extends CustomPainter {
  final int tomadas;
  final int omitidas;
  final int notificadas;
  final int aplazadas;
  final Color trackColor;

  MultiSegmentRingPainter({
    required this.tomadas,
    required this.omitidas,
    required this.notificadas,
    required this.aplazadas,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;
    final radius = (size.width - strokeWidth) / 2;

    // Background track ring
    final trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final total = tomadas + omitidas + notificadas + aplazadas;
    if (total <= 0) return;

    final segments = <Map<String, dynamic>>[];
    if (tomadas > 0) {
      segments.add({'val': tomadas, 'color': AppTheme.successColor});
    }
    if (omitidas > 0) {
      segments.add({'val': omitidas, 'color': AppTheme.errorColor});
    }
    if (notificadas > 0) {
      segments.add({'val': notificadas, 'color': const Color(0xFFFFB703)});
    }
    if (aplazadas > 0) {
      segments.add({'val': aplazadas, 'color': Colors.orange});
    }

    if (segments.isEmpty) return;

    final n = segments.length;

    if (n == 1) {
      final paint =
          Paint()
            ..color = segments.first['color'] as Color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi,
        false,
        paint,
      );
      return;
    }

    // When there are multiple segments, compute the gap angle so rounded caps have a clear visible separation
    final capRadiusAngle = (strokeWidth / 2) / radius;
    final gapAngle = (2 * capRadiusAngle) + 0.08;
    final totalGap = n * gapAngle;
    final availableAngle = (2 * pi) - totalGap;

    double currentAngle = -pi / 2;

    for (final seg in segments) {
      final fraction = (seg['val'] as int) / total;
      final sweepAngle = (fraction * availableAngle).clamp(
        0.02,
        availableAngle,
      );

      final segmentPaint =
          Paint()
            ..color = seg['color'] as Color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle + (gapAngle / 2),
        sweepAngle,
        false,
        segmentPaint,
      );

      currentAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant MultiSegmentRingPainter oldDelegate) =>
      oldDelegate.tomadas != tomadas ||
      oldDelegate.omitidas != omitidas ||
      oldDelegate.notificadas != notificadas ||
      oldDelegate.aplazadas != aplazadas ||
      oldDelegate.trackColor != trackColor;
}
