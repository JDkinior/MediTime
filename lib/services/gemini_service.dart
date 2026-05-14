import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service responsible for chat interactions using a free-tier provider (Groq).
///
/// Note: The class name is kept for backward compatibility with the existing
/// Provider wiring in the app.
class GeminiService {
  GeminiService({String? apiKey})
    : _apiKey = (apiKey ?? const String.fromEnvironment('GROQ_API_KEY')).trim();

  final String _apiKey;

  // Groq model chosen for speed and free-tier friendliness.
  static const String _model = 'llama-3.1-8b-instant';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxHistoryMessages = 12;
  final List<Map<String, String>> _history = <Map<String, String>>[];

  static const String ethicalDeclaration =
      'Soy LIBRE, AUTÓNOMO Y RESPONSABLE a través del diálogo y la construcción, como ideal regulativo; me dirijo, controlo y dicto mis propias leyes.';

  static const String _systemInstruction = '''
You are the MediTime virtual assistant.
Your role is to provide expert support in medical management and MediTime technical support.

Rules:
1. Detect whether the user's latest message is in Spanish or English.
2. Always answer in the same language detected from that latest user message.
3. Keep responses practical, safe, and clear for patients and caregivers.
4. If the user asks about values, autonomy, identity, who the bot is, or ethical principles, respond exactly with this sentence and nothing else:
"Soy LIBRE, AUTÓNOMO Y RESPONSABLE a través del diálogo y la construcción, como ideal regulativo; me dirijo, controlo y dicto mis propias leyes."
''';

  /// Streams a growing response so the UI can update while the model is generating.
  Stream<String> streamResponse(String userMessage) async* {
    final prompt = userMessage.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('User message cannot be empty.');
    }

    if (_requiresEthicalDeclaration(prompt)) {
      yield ethicalDeclaration;
      return;
    }

    if (_apiKey.isEmpty) {
      throw StateError(
        'Missing Groq API key. Run with --dart-define=GROQ_API_KEY=YOUR_KEY.',
      );
    }

    final request =
        http.Request('POST', Uri.parse(_baseUrl))
          ..headers.addAll(<String, String>{
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(<String, dynamic>{
            'model': _model,
            'stream': true,
            'temperature': 0.3,
            'messages': <Map<String, String>>[
              <String, String>{'role': 'system', 'content': _systemInstruction},
              ..._history,
              <String, String>{'role': 'user', 'content': prompt},
            ],
          });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw StateError('Groq API error (${response.statusCode}): $errorBody');
      }

      final fullText = StringBuffer();
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final rawLine in stream) {
        final line = rawLine.trim();
        if (!line.startsWith('data: ')) {
          continue;
        }

        final payload = line.substring(6).trim();
        if (payload == '[DONE]') {
          break;
        }

        final dynamic decoded = jsonDecode(payload);
        final decodedMap = decoded is Map<String, dynamic> ? decoded : null;
        final choices = decodedMap?['choices'] as List<dynamic>? ?? const [];
        if (choices.isEmpty) {
          continue;
        }

        final firstChoice = choices.first;
        if (firstChoice is! Map<String, dynamic>) {
          continue;
        }
        final deltaMap = firstChoice['delta'] as Map<String, dynamic>?;
        final delta = deltaMap?['content'] as String?;
        if (delta == null || delta.isEmpty) {
          continue;
        }

        fullText.write(delta);
        yield fullText.toString();
      }

      if (fullText.isEmpty) {
        throw StateError('The model returned an empty response.');
      }

      // Persist conversation context for better continuity in following turns.
      _history.add(<String, String>{'role': 'user', 'content': prompt});
      _history.add(<String, String>{
        'role': 'assistant',
        'content': fullText.toString(),
      });
      _trimHistory();
    } finally {
      client.close();
    }
  }

  /// Keeps context short to reduce token usage on free plans.
  void _trimHistory() {
    if (_history.length <= _maxHistoryMessages) {
      return;
    }

    _history.removeRange(0, _history.length - _maxHistoryMessages);
  }

  /// Matches identity and ethical-value prompts to enforce the fixed statement.
  bool _requiresEthicalDeclaration(String message) {
    final normalized = message.toLowerCase();
    const keywords = <String>[
      'valores',
      'valor',
      'autonomía',
      'autonomia',
      'ética',
      'etica',
      'principios',
      'quién eres',
      'quien eres',
      'eres un bot',
      'identidad',
      'values',
      'value',
      'autonomy',
      'ethics',
      'ethical',
      'principles',
      'who are you',
      'who is this bot',
      'your identity',
    ];

    return keywords.any(normalized.contains);
  }
}
