import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/screens/reports/progreso_page.dart';
import 'package:meditime/widgets/reports/streak_celebration_sheet.dart';

void main() {
  group('StreakCelebrationSheet Tests', () {
    testWidgets('renders streak celebration sheet with 7 days and milestone',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakCelebrationSheet(
              racha: 7,
              tratamientos: [
                Tratamiento(
                  id: 't1',
                  nombreMedicamento: 'Ibuprofeno',
                  presentacion: 'Pastilla',
                  duracion: '7 días',
                  horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
                  intervaloDosis: const Duration(hours: 8),
                  prescriptionAlarmId: 101,
                  fechaInicioTratamiento: DateTime.now().subtract(const Duration(days: 7)),
                  fechaFinTratamiento: DateTime.now().add(const Duration(days: 7)),
                  doseStatus: {
                    DateTime.now().toIso8601String(): DoseStatus.tomada,
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7 DÍAS'), findsOneWidget);
      expect(find.text('¡Tu racha está que arde!'), findsOneWidget);
      expect(find.text('Cadena de esta semana'), findsOneWidget);
      expect(find.text('¡CONTINUAR!'), findsOneWidget);
    });

    testWidgets('renders streak celebration sheet with 0 days racha',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakCelebrationSheet(
              racha: 0,
              tratamientos: [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0 DÍAS'), findsOneWidget);
      expect(find.text('SIN RACHA'), findsOneWidget);
      expect(find.text('¡Hoy es el día ideal para iniciar tu racha!'), findsOneWidget);
    });
  });

  group('SegmentRingPainter Glow & Dim Tests', () {
    test('paints with selected glowing segment and dimmed segments without error', () {
      final painter = SegmentRingPainter(
        segments: const [
          RingSegment(
            value: 10,
            color: Colors.green,
            status: DoseStatus.tomada,
            isSelected: true,
          ),
          RingSegment(
            value: 2,
            color: Colors.red,
            status: DoseStatus.omitida,
            isDimmed: true,
          ),
        ],
        trackColor: Colors.grey.shade200,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(105, 105);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('shouldRepaint returns true when isSelected changes', () {
      final painter1 = SegmentRingPainter(
        segments: const [
          RingSegment(value: 5, color: Colors.green, isSelected: false),
        ],
        trackColor: Colors.grey,
      );
      final painter2 = SegmentRingPainter(
        segments: const [
          RingSegment(value: 5, color: Colors.green, isSelected: true),
        ],
        trackColor: Colors.grey,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });
}
