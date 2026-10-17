import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/widgets/markdown_message_body.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(String text) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownMessageBody(text: text),
        ),
      ),
    );
  }

  group('MarkdownMessageBody - Table Parsing & Rendering', () {
    testWidgets('Renders Markdown tables with headers and data rows', (tester) async {
      const tableMarkdown = '''
| Mascota | Medicamento | Fecha de fin | Días restantes |
| :--- | :--- | :--- | :--- |
| max (Bovino) | NexGard | 18 octubre 2026 | 2 días |
| joli (Felino) | Credelio | 17 diciembre 2026 | 62 días |
''';

      await tester.pumpWidget(buildTestWidget(tableMarkdown));
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Mascota'), findsOneWidget);
      expect(find.text('Medicamento'), findsOneWidget);
      expect(find.text('Fecha de fin'), findsOneWidget);
      expect(find.text('Días restantes'), findsOneWidget);
      expect(find.text('max (Bovino)'), findsOneWidget);
      expect(find.text('NexGard'), findsOneWidget);
      expect(find.text('joli (Felino)'), findsOneWidget);
    });

    testWidgets('Gracefully handles incomplete or streaming table chunks without crashing', (tester) async {
      const partialTable = '| Mascota | Medicamento |';

      await tester.pumpWidget(buildTestWidget(partialTable));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('MarkdownMessageBody - Callouts & Alerts', () {
    testWidgets('Renders blockquote note (> Nota:) as a callout card', (tester) async {
      const calloutMarkdown = '> 💡 **Nota:** Ambos tratamientos están programados para continuar.';

      await tester.pumpWidget(buildTestWidget(calloutMarkdown));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(find.textContaining('Ambos tratamientos están programados'), findsOneWidget);
    });

    testWidgets('Renders warning/toxic alert with warning icon', (tester) async {
      const warningMarkdown = '> ⚠️ **Alerta:** Medicamento tóxico en felinos.';

      await tester.pumpWidget(buildTestWidget(warningMarkdown));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('tóxico'), findsOneWidget);
    });
  });

  group('MarkdownMessageBody - Lists & Hierarchies', () {
    testWidgets('Renders bullet items and nested sub-items cleanly', (tester) async {
      const listMarkdown = '''
- max (Bovino)
  - NexGard: comprimidos
    - Periodo: 18 oct 2026 (2 días restantes)
- joli (Felino)
''';

      await tester.pumpWidget(buildTestWidget(listMarkdown));
      await tester.pumpAndSettle();

      expect(find.textContaining('max (Bovino)'), findsOneWidget);
      expect(find.textContaining('NexGard: comprimidos'), findsOneWidget);
      expect(find.textContaining('joli (Felino)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders numbered lists', (tester) async {
      const numberedMarkdown = '''
1. Primer paso
2. Segundo paso
''';

      await tester.pumpWidget(buildTestWidget(numberedMarkdown));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('Primer paso'), findsOneWidget);
      expect(find.textContaining('Segundo paso'), findsOneWidget);
    });
  });

  group('MarkdownMessageBody - Headers & Badges', () {
    testWidgets('Renders section headers (###)', (tester) async {
      const headerMarkdown = '### 🐾 Tratamiento de max';

      await tester.pumpWidget(buildTestWidget(headerMarkdown));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tratamiento de max'), findsOneWidget);
    });

    testWidgets('Renders countdown badges for ¡Finaliza HOY! and remaining days', (tester) async {
      const badgeMarkdown = 'El antibiótico ¡Finaliza HOY! y quedan 2 días restantes.';

      await tester.pumpWidget(buildTestWidget(badgeMarkdown));
      await tester.pumpAndSettle();

      expect(find.text('¡Finaliza HOY!'), findsOneWidget);
      expect(find.text('quedan 2 días restantes'), findsOneWidget);
    });
  });
}
