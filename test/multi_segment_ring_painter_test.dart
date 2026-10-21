import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/widgets/reports/multi_segment_ring_painter.dart';

void main() {
  group('MultiSegmentRingPainter Tests', () {
    test('paints without error on a standard size canvas', () {
      final painter = MultiSegmentRingPainter(
        tomadas: 5,
        omitidas: 2,
        notificadas: 1,
        aplazadas: 1,
        trackColor: Colors.grey.shade200,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(200, 200);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test(
      'handles empty state (total = 0) gracefully without dividing by zero',
      () {
        final painter = MultiSegmentRingPainter(
          tomadas: 0,
          omitidas: 0,
          notificadas: 0,
          aplazadas: 0,
          trackColor: Colors.grey.shade200,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(200, 200);

        expect(() => painter.paint(canvas, size), returnsNormally);
      },
    );

    test('paints a single segment full ring correctly', () {
      final painter = MultiSegmentRingPainter(
        tomadas: 10,
        omitidas: 0,
        notificadas: 0,
        aplazadas: 0,
        trackColor: Colors.grey.shade200,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(200, 200);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('shouldRepaint returns true when properties change', () {
      final painter1 = MultiSegmentRingPainter(
        tomadas: 5,
        omitidas: 2,
        notificadas: 1,
        aplazadas: 0,
        trackColor: Colors.grey,
      );

      final painter2 = MultiSegmentRingPainter(
        tomadas: 6,
        omitidas: 2,
        notificadas: 1,
        aplazadas: 0,
        trackColor: Colors.grey,
      );

      final painter3 = MultiSegmentRingPainter(
        tomadas: 5,
        omitidas: 2,
        notificadas: 1,
        aplazadas: 0,
        trackColor: Colors.blue,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });

    test('shouldRepaint returns false when properties are identical', () {
      final painter1 = MultiSegmentRingPainter(
        tomadas: 5,
        omitidas: 2,
        notificadas: 1,
        aplazadas: 0,
        trackColor: Colors.grey,
      );

      final painter2 = MultiSegmentRingPainter(
        tomadas: 5,
        omitidas: 2,
        notificadas: 1,
        aplazadas: 0,
        trackColor: Colors.grey,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });
  });
}
