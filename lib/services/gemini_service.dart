import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meditime/models/tratamiento.dart';

/// Service responsible for chat interactions using a free-tier provider (Groq).
///
/// Note: The class name is kept for backward compatibility with the existing
/// Provider wiring in the app.
class GeminiService {
  GeminiService({String? apiKey})
    : _apiKey = (apiKey ?? const String.fromEnvironment('GROQ_API_KEY')).trim();

  final String _apiKey;

  // Groq models chosen for speed, vision support, and free-tier friendliness.
  static const String _model = 'llama-3.1-8b-instant';
  static const String _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxHistoryMessages = 12;
  final List<Map<String, String>> _history = <Map<String, String>>[];

  static const String _systemInstruction = '''
You are the MediTime Virtual Assistant, a friendly and professional companion designed to support users with their health and medical management.

Here is key information about MediTime's features to help users:
1. **Medication Scheduling & Alarms**: Users can add treatments with details like name, presentation, first dose time, interval, and notes. The app sets up local push notifications to alert them when to take their meds.
2. **Calendar & Dose Tracking**: A calendar view shows doses grouped by day. Users can log doses as "tomada" (taken), "omitida" (skipped), or keep them "pendiente" (pending).
3. **Inventory & Stock Management**: MediTime tracks current pill counts. When logging a dose as "taken", it decreases inventory and shows status indicators. It warns the user when their stock is running low.
4. **Caregiver Mode (Modo Cuidador)**: Caregivers can link profiles with their patients by email (via Profile screen) to view active treatments, calendar logs, and adherence status in real-time.
5. **AI OCR Prescription Scan**: Inside "Agregar Receta", users can tap the document icon to take a photo of a prescription. The AI automatically parses details (name, duration, dose, interval, notes) to auto-fill the form.
6. **Pharmacy Locator**: Users can view nearby pharmacies on a map layout to locate where to buy medicines.
7. **Offline Cache**: MediTime supports offline operations with Firestore persistence; data is saved locally and synced automatically when back online.
8. **Adherence Reports**: The app computes statistics on taken vs. skipped doses to help users review adherence over time.

Rules:
1. Detect whether the user's latest message is in Spanish or English.
2. Always answer in the same language detected from that latest user message.
3. Keep responses highly practical, safe, empathetic, and clear for patients and caregivers.
4. Emphasize that you are an AI assistant and they should always consult a medical professional for critical clinical decisions.
''';

  /// Streams a growing response so the UI can update while the model is generating.
  /// Optionally accepts [activeTreatments] to include as context for drug interaction warnings.
  Stream<String> streamResponse(String userMessage, {List<Tratamiento>? activeTreatments}) async* {
    final prompt = userMessage.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('User message cannot be empty.');
    }

    if (_apiKey.isEmpty) {
      throw StateError(
        'Missing Groq API key. Run with --dart-define=GROQ_API_KEY=YOUR_KEY.',
      );
    }

    final String treatmentsPrompt;
    if (activeTreatments != null && activeTreatments.isNotEmpty) {
      treatmentsPrompt = '\n\nActive treatments context for safety and interaction analysis:\n' +
          activeTreatments
              .map((t) =>
                  '- Name: ${t.nombreMedicamento}, Presentation: ${t.presentacion}, Interval: every ${t.intervaloDosis.inHours} hours, Notes: ${t.notas}')
              .join('\n') +
          '\nIf the user asks about taking something new, check for potential interactions or scheduling conflicts with these active treatments.';
    } else {
      treatmentsPrompt = '';
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
              <String, String>{
                'role': 'system',
                'content': _systemInstruction + treatmentsPrompt,
              },
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

  /// Extracts prescription data from a Base64 image using Groq's vision model.
  Future<Map<String, dynamic>?> analyzePrescriptionImage(String base64Image, String mimeType) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Missing Groq API key. Run with --dart-define=GROQ_API_KEY=YOUR_KEY.',
      );
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: <String, String>{
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'model': _visionModel,
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'system',
            'content': 'You are a precise medical prescription extractor. Extract the details of the prescription from the image and output them in a structured JSON format. Ensure all text properties are in Spanish. Output ONLY the raw JSON object, starting with { and ending with }.',
          },
          <String, dynamic>{
            'role': 'user',
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'text',
                'text': 'Analyze this medical prescription image and return a JSON object with the following fields: '
                    '"nombreMedicamento" (String, name of the drug/medication), '
                    '"presentacion" (String, e.g., "pastillas", "jarabe", "cápsulas"), '
                    '"duracion" (String, e.g., "7 días", "30 días", "uso continuo"), '
                    '"intervaloDosis" (int, hours between doses, e.g., 8, 12, 24), '
                    '"dosisPorToma" (int, number of units/pills per dose, e.g., 1, 2), '
                    '"notas" (String, extra medical recommendations or instructions). '
                    'CRITICAL: Return only the raw JSON. Do not include markdown code block formatting (like ```json) or any conversational text.',
              },
              <String, dynamic>{
                'type': 'image_url',
                'image_url': <String, String>{
                  'url': 'data:$mimeType;base64,$base64Image',
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Groq Vision API error (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    if (choices.isEmpty) return null;
    final message = choices.first['message'] as Map<String, dynamic>;
    final content = message['content'] as String;
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Keeps context short to reduce token usage on free plans.
  void _trimHistory() {
    if (_history.length <= _maxHistoryMessages) {
      return;
    }

    _history.removeRange(0, _history.length - _maxHistoryMessages);
  }
}
