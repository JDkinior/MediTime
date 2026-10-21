// lib/widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/chat_message.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/markdown_message_body.dart';
import 'package:meditime/widgets/chat/animated_typing_dots.dart';
import 'package:meditime/widgets/chat/prescription_form_card.dart';
import 'package:meditime/widgets/chat/adherence_chart_card.dart';

class ChatBubble extends StatelessWidget {
  static const List<Color> chatGradient = <Color>[
    Color(0xFF004AC6),
    Color(0xFF1B6BF3),
  ];
  final ChatMessage message;
  final void Function(
    String name,
    String pres,
    int interval,
    int dosis,
    int duration,
    String notas,
    Map<String, dynamic> prescriptionData, {
    CaregiverProfile? targetProfile,
  })?
  onConfirmRecipe;

  final void Function()? onEdit;

  const ChatBubble({
    super.key,
    required this.message,
    this.onConfirmRecipe,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final textColor = isUser ? Colors.white : AppTheme.primaryTextColor;

    Widget bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        constraints: BoxConstraints(
          maxWidth:
              isUser
                  ? MediaQuery.of(context).size.width * 0.78
                  : MediaQuery.of(context).size.width * 0.90,
        ),
        decoration: BoxDecoration(
          color: isUser ? null : Theme.of(context).cardColor,
          border: isUser ? null : Border.all(color: AppTheme.borderColor),
          gradient:
              isUser
                  ? const LinearGradient(
                    colors: ChatBubble.chatGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          borderRadius:
              isUser
                  ? const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(4),
                  )
                  : const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                    bottomLeft: Radius.circular(4),
                  ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            message.isStreaming && message.text.isEmpty
                ? const AnimatedTypingDots()
                : Column(
                  crossAxisAlignment:
                      isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUser)
                      RichText(
                        text: TextSpan(
                          children: _buildTextSpans(message.text, textColor),
                        ),
                      )
                    else
                      MarkdownMessageBody(
                        text: message.text,
                        textColor: textColor,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('h:mm a').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isUser
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
      ),
    );

    if (isUser && onEdit != null) {
      bubble = GestureDetector(onLongPress: onEdit, child: bubble);
    }

    if (message.prescriptionData != null || message.showAdherenceChart) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text.isNotEmpty) bubble,
          if (message.prescriptionData != null && onConfirmRecipe != null)
            PrescriptionFormCard(
              prescriptionData: message.prescriptionData!,
              onSaved: (
                name,
                pres,
                interval,
                dosis,
                duration,
                notas, [
                targetProfile,
              ]) {
                onConfirmRecipe!(
                  name,
                  pres,
                  interval,
                  dosis,
                  duration,
                  notas,
                  message.prescriptionData!,
                  targetProfile: targetProfile,
                );
              },
            ),
          if (message.showAdherenceChart)
            AdherenceChartCard(arguments: message.adherenceChartData),
        ],
      );
    }

    return bubble;
  }

  List<TextSpan> _buildTextSpans(String text, Color baseColor) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(color: baseColor, fontSize: 15, height: 1.35),
          ),
        );
      }

      final boldText = match.group(1) ?? '';
      final isMediTime = boldText.toLowerCase().contains('meditime');

      spans.add(
        TextSpan(
          text: boldText,
          style: TextStyle(
            color: isMediTime ? AppTheme.primaryColor : baseColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(color: baseColor, fontSize: 15, height: 1.35),
        ),
      );
    }

    return spans;
  }
}
