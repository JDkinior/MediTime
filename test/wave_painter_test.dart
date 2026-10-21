import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/widgets/medication/wave_painter.dart';

void main() {
  group('WavePainter Tests', () {
    test('paints wave paths successfully on a Canvas', () {
      final painter = WavePainter(animationValue: 0.25);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(350, 180);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('paints without error at phase boundaries (0.0 and 1.0)', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(350, 180);

      final painterStart = WavePainter(animationValue: 0.0);
      final painterEnd = WavePainter(animationValue: 1.0);

      expect(() => painterStart.paint(canvas, size), returnsNormally);
      expect(() => painterEnd.paint(canvas, size), returnsNormally);
    });

    test('shouldRepaint returns true when animationValue changes', () {
      final painter1 = WavePainter(animationValue: 0.1);
      final painter2 = WavePainter(animationValue: 0.2);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when animationValue is the same', () {
      final painter1 = WavePainter(animationValue: 0.5);
      final painter2 = WavePainter(animationValue: 0.5);

      expect(painter1.shouldRepaint(painter2), isFalse);
    });
  });
}
