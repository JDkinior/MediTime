// lib/widgets/pill_icon.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget que dibuja un icono vectorial de una cápsula medicinal inclinada a 45 grados.
class PillIcon extends StatelessWidget {
  final double size;
  final Color color;

  const PillIcon({super.key, this.size = 14, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PillPainter(color: color)),
    );
  }
}

class _PillPainter extends CustomPainter {
  final Color color;

  _PillPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);

    final w = size.width * 0.95;
    final h = size.height * 0.48;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(rrect, paint);
    canvas.drawLine(Offset(0, -h / 2), Offset(0, h / 2), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) =>
      oldDelegate.color != color;
}
