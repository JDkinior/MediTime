import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/chat_message.dart';
import 'package:meditime/widgets/chat/chat_bubble.dart';
import 'package:meditime/widgets/chat/animated_typing_dots.dart';
import 'package:meditime/widgets/markdown_message_body.dart';

void main() {
  Widget buildTestBubble({required ChatMessage message, VoidCallback? onEdit}) {
    return MaterialApp(
      home: Scaffold(body: ChatBubble(message: message, onEdit: onEdit)),
    );
  }

  group('ChatBubble Widget Tests', () {
    testWidgets('renders user message with right alignment and TextSpan', (
      tester,
    ) async {
      final msg = ChatMessage(
        text: 'Hola MediTime',
        isUser: true,
        timestamp: DateTime(2026, 1, 1, 10, 30),
      );

      await tester.pumpWidget(buildTestBubble(message: msg));
      await tester.pumpAndSettle();

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Hola MediTime'),
      );
      expect(richTextFinder, findsOneWidget);

      final alignFinder = find.byWidgetPredicate(
        (w) => w is Align && w.alignment == Alignment.centerRight,
      );
      expect(alignFinder, findsOneWidget);
    });

    testWidgets(
      'renders assistant message with left alignment and MarkdownMessageBody',
      (tester) async {
        final msg = ChatMessage(
          text: 'Buenos días, ¿en qué puedo ayudarte hoy?',
          isUser: false,
          timestamp: DateTime(2026, 1, 1, 10, 31),
        );

        await tester.pumpWidget(buildTestBubble(message: msg));
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownMessageBody), findsOneWidget);

        final alignFinder = find.byWidgetPredicate(
          (w) => w is Align && w.alignment == Alignment.centerLeft,
        );
        expect(alignFinder, findsOneWidget);
      },
    );

    testWidgets(
      'renders AnimatedTypingDots when message is streaming and text is empty',
      (tester) async {
        final msg = ChatMessage(
          text: '',
          isUser: false,
          isStreaming: true,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(buildTestBubble(message: msg));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedTypingDots), findsOneWidget);
      },
    );

    testWidgets('triggers onEdit callback on long press for user messages', (
      tester,
    ) async {
      bool editCalled = false;
      final msg = ChatMessage(
        text: 'Mensaje para editar',
        isUser: true,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestBubble(
          message: msg,
          onEdit: () {
            editCalled = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      final richTextFinder = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('Mensaje para editar'),
      );
      expect(richTextFinder, findsOneWidget);

      await tester.longPress(richTextFinder);
      expect(editCalled, isTrue);
    });
  });
}
