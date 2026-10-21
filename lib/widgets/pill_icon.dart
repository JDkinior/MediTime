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

/// Widget que dibuja un icono vectorial de un comprimido/gragea circular con ranura divisoria.
class TabletIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TabletIcon({super.key, this.size = 14, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TabletPainter(color: color)),
    );
  }
}

class _TabletPainter extends CustomPainter {
  final Color color;

  _TabletPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width * 0.85) / 2;

    // Contorno circular de la pastilla / comprimido
    canvas.drawCircle(center, radius, paint);

    // Ranura divisoria central
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);
    canvas.drawLine(Offset(0, -radius), Offset(0, radius), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TabletPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Widget que dibuja un icono vectorial de un sobre o sachet con sellos superior e inferior.
class SachetIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SachetIcon({super.key, this.size = 14, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SachetPainter(color: color)),
    );
  }
}

class _SachetPainter extends CustomPainter {
  final Color color;

  _SachetPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;

    final w = size.width * 0.75;
    final h = size.height * 0.95;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2.0));
    canvas.drawRRect(rrect, paint);

    // Sello superior
    final topY = rect.top + h * 0.22;
    canvas.drawLine(Offset(rect.left, topY), Offset(rect.right, topY), paint);

    // Sello inferior
    final bottomY = rect.bottom - h * 0.18;
    canvas.drawLine(
      Offset(rect.left, bottomY),
      Offset(rect.right, bottomY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SachetPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Widget inteligente que renderiza el icono representativo de cada tipo de medicamento.
///
/// Soporta:
/// - Comprimidos / Grageas / Tablets: TabletIcon
/// - Cápsulas / Capsules: PillIcon
/// - Sobres / Sachets / Envelopes: SachetIcon
/// - Jarabes / Syrups: Icons.medication_liquid_rounded
/// - Gotas / Drops: Icons.water_drop_outlined
/// - Suspensiones / Suspensions: Icons.science_outlined
/// - Emulsiones / Emulsions: Icons.opacity_rounded
class MedicationPresentationIcon extends StatelessWidget {
  final String presentation;
  final double size;
  final Color color;

  const MedicationPresentationIcon({
    super.key,
    required this.presentation,
    this.size = 13,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clean = presentation.toLowerCase().trim();

    if (clean.contains('capsul') || clean.contains('cápsul')) {
      return PillIcon(size: size, color: color);
    } else if (clean.contains('comprim') ||
        clean.contains('gragea') ||
        clean.contains('tablet') ||
        clean.contains('pastill') ||
        clean.contains('dragee')) {
      return TabletIcon(size: size, color: color);
    } else if (clean.contains('sobre') ||
        clean.contains('sachet') ||
        clean.contains('envelope') ||
        clean.contains('pouch') ||
        clean.contains('packet')) {
      return SachetIcon(size: size, color: color);
    } else if (clean.contains('jarabe') ||
        clean.contains('syrup') ||
        clean.contains('xarope')) {
      return Icon(Icons.medication_liquid_rounded, size: size, color: color);
    } else if (clean.contains('gota') || clean.contains('drop')) {
      return Icon(Icons.water_drop_outlined, size: size, color: color);
    } else if (clean.contains('suspens')) {
      return Icon(Icons.science_outlined, size: size, color: color);
    } else if (clean.contains('emuls')) {
      return Icon(Icons.opacity_rounded, size: size, color: color);
    } else {
      return PillIcon(size: size, color: color);
    }
  }
}
