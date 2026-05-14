import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meditime/services/gemini_service.dart';
import 'package:provider/provider.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  static const String routeName = '/chatbot';

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  static const List<Color> _chatGradient = <Color>[
    Color(0xFF2296F3),
    Color(0xFF316AA7),
  ];
  static const double _composerRadius = 30;
  static const String _midiOpenAsset = 'assets/chatbot/midi_open.png';
  static const String _midiBlinkAsset = 'assets/chatbot/midi_blink.png';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Hola, soy tu asistente MediTime. You can ask me in Spanish or English.',
      isUser: false,
    ),
  ];

  bool _isGenerating = false;
  bool _hasText = false;
  bool _isBlinking = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    // Keep send button state in sync with user input.
    _messageController.addListener(_handleInputChanged);
    _scheduleBlink();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _messageController.removeListener(_handleInputChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  /// Schedules occasional icon blinking to give Midi a subtle alive effect.
  void _scheduleBlink() {
    final waitMs = 2200 + _random.nextInt(3800);
    _blinkTimer = Timer(Duration(milliseconds: waitMs), () {
      if (!mounted) {
        return;
      }
      setState(() => _isBlinking = true);
      _blinkTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) {
          return;
        }
        setState(() => _isBlinking = false);
        _scheduleBlink();
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) {
      return;
    }

    _messageController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(
        const _ChatMessage(text: '', isUser: false, isStreaming: true),
      );
      _isGenerating = true;
    });
    _scrollToBottom();

    final geminiService = context.read<GeminiService>();
    final botMessageIndex = _messages.length - 1;

    try {
      // Stream chunks and progressively paint them in the last assistant bubble.
      await for (final partialText in geminiService.streamResponse(text)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _messages[botMessageIndex] = _messages[botMessageIndex].copyWith(
            text: partialText,
            isStreaming: true,
          );
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages[botMessageIndex] = _ChatMessage(
          text: _buildUserFriendlyError(error),
          isUser: false,
          isStreaming: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _messages[botMessageIndex] = _messages[botMessageIndex].copyWith(
            isStreaming: false,
          );
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// Converts provider/API errors into concise user-facing guidance.
  String _buildUserFriendlyError(Object error) {
    final errorText = error.toString();
    final normalized = errorText.toLowerCase();

    if (normalized.contains('missing groq api key')) {
      return 'Falta la clave de Groq. Ejecuta con --dart-define=GROQ_API_KEY=TU_CLAVE.';
    }

    if (normalized.contains('401') || normalized.contains('invalid api key')) {
      return 'La clave de Groq no es válida o fue revocada. Genera una nueva clave e inténtalo de nuevo.';
    }

    if (normalized.contains('429') ||
        normalized.contains('rate limit') ||
        normalized.contains('quota')) {
      return 'Se alcanzó el límite gratuito temporal de solicitudes. Espera unos minutos e inténtalo nuevamente.';
    }

    return 'No fue posible generar una respuesta. Detalle técnico: $errorText';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildComposer() {
    final isEnabled = _hasText && !_isGenerating;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_composerRadius),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(24, 0, 0, 0),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_composerRadius),
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Pregunta lo que necesitas...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_composerRadius),
                        borderSide: const BorderSide(
                          color: Color(0xFFC7CCD5),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_composerRadius),
                        borderSide: const BorderSide(
                          color: Color(0xFFC7CCD5),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_composerRadius),
                        borderSide: const BorderSide(
                          color: Color(0xFF2296F3),
                          width: 1.6,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isEnabled ? _sendMessage : null,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      isEnabled
                          ? const LinearGradient(
                            colors: _chatGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  color: isEnabled ? null : const Color(0xFFC0C5CF),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromARGB(28, 0, 0, 0),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Image.asset(
                _isBlinking ? _midiBlinkAsset : _midiOpenAsset,
                key: ValueKey<bool>(_isBlinking),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Midi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
            ),
            const SizedBox(width: 6),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF59C156),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              // Eliminamos el ShaderMask y dejamos el ListView directamente
              child: ListView.builder(
                controller: _scrollController,
                // Mantenemos un padding para que el primer y último mensaje no toquen los bordes
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _ChatBubble(message: message);
                },
              ),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final textColor = isUser ? Colors.white : const Color(0xFF222222);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        decoration: BoxDecoration(
          color: isUser ? null : const Color(0xFFF0F0F2),
          gradient:
              isUser
                  ? const LinearGradient(
                    colors: _ChatBotScreenState._chatGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          borderRadius:
              isUser
                  ? const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(4),
                  )
                  : const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                    bottomLeft: Radius.circular(4),
                  ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(28, 0, 0, 0),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child:
            message.isStreaming && message.text.isEmpty
                ? const _AnimatedTypingDots()
                : Text(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    height: 1.25,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
      ),
    );
  }
}

class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots> {
  int _activeDot = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Cycles opacity across 3 dots to mimic an animated ellipsis typing state.
    _timer = Timer.periodic(const Duration(milliseconds: 260), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _activeDot = (_activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final targetOpacity = _activeDot == index ? 1.0 : 0.25;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedOpacity(
            opacity: targetOpacity,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF6A7485),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  final String text;
  final bool isUser;
  final bool isStreaming;

  _ChatMessage copyWith({String? text, bool? isUser, bool? isStreaming}) {
    return _ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
