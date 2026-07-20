import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:meditime/models/tratamiento.dart';

/// Result of a function call that the chat screen should handle.
class ToolCallResult {
  const ToolCallResult({
    required this.functionName,
    required this.arguments,
    required this.result,
  });

  final String functionName;
  final Map<String, dynamic> arguments;
  final String result;
}

/// Service responsible for chat interactions using Groq API with function calling.
///
/// Note: The class name is kept for backward compatibility with the existing
/// Provider wiring in the app.
class GeminiService {
  GeminiService({String? apiKey})
    : _apiKey = (apiKey ?? const String.fromEnvironment('GROQ_API_KEY')).trim();

  final String _apiKey;

  // Model chosen for 15,000 TPM on free tier (2.5x more than llama models).
  static const String _model = 'llama-3.3-70b-versatile';
  static const String _fallbackModel = 'llama-3.1-8b-instant';
  static const String _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxHistoryMessages = 6;
  static const int _maxCompletionTokens = 400;
  final List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  /// Compact system prompt — focused on behavior rules and tool usage.
  static const String _systemInstruction = '''
You are Midi, a warm health assistant for MediTime.
RULES:
1. Respond in user's language. Friendly & concise. Advise doctor when needed.
2. NEVER mention tool/function names (e.g. get_today_medications). Speak naturally.
3. Capabilities: "Puedo consultar tus dosis del día, tratamientos activos, agendar recordatorios o ver tu adherencia."
4. Use tools for data. DO NOT invent.
5. Format meds in bold **nombre**.
''';

  /// Tool definitions for Groq function calling.
  static const List<Map<String, dynamic>> _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'get_today_medications',
        'description': 'Get today\'s medications and statuses.',
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_tomorrow_medications',
        'description': 'Get tomorrow\'s medications.',
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_active_treatments',
        'description': 'Get summary of active treatments.',
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_treatment',
        'description': 'Create a new medication reminder.',
        'parameters': {
          'type': 'object',
          'properties': {
            'nombreMedicamento': {'type': 'string'},
            'presentacion': {'type': 'string'},
            'dosisPorToma': {'type': 'integer', 'default': 1},
            'intervaloDosis': {'type': 'integer', 'default': 8},
            'duracion': {'type': 'integer', 'default': 7},
            'notas': {'type': 'string'},
          },
          'required': ['nombreMedicamento'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_dose_status',
        'description': 'Mark dose as tomada, omitida, or aplazada.',
        'parameters': {
          'type': 'object',
          'properties': {
            'medicamento': {'type': 'string'},
            'status': {'type': 'string', 'enum': ['tomada', 'omitida', 'aplazada']},
            'minutosAplazo': {'type': 'integer', 'default': 30},
            'updateAll': {'type': 'boolean', 'default': false},
          },
          'required': ['medicamento', 'status'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'show_adherence_chart',
        'description': 'Show adherence chart and stats.',
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_treatment_inventory',
        'description': 'Check medication inventory.',
        'parameters': {
          'type': 'object',
          'properties': {
            'medicamento': {'type': 'string', 'default': ''},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_missed_doses',
        'description': 'Get missed/skipped doses.',
        'parameters': {
          'type': 'object',
          'properties': {
            'days': {'type': 'integer', 'default': 7},
          },
        },
      },
    },
  ];

  /// Executes a tool function locally and returns the result string.
  /// The [activeTreatments] must be pre-filtered to only active ones.
  String executeToolFunction(
    String functionName,
    Map<String, dynamic> arguments,
    List<Tratamiento> activeTreatments,
  ) {
    switch (functionName) {
      case 'get_today_medications':
        return _getScheduledMedications(activeTreatments, DateTime.now());
      case 'get_tomorrow_medications':
        return _getScheduledMedications(
          activeTreatments,
          DateTime.now().add(const Duration(days: 1)),
        );
      case 'get_active_treatments':
        return _getActiveTreatmentsSummary(activeTreatments);
      case 'get_treatment_inventory':
        final medName = arguments['medicamento']?.toString() ?? '';
        return _getInventory(activeTreatments, medName);
      case 'get_missed_doses':
        final days = (arguments['days'] as int?) ?? 7;
        return _getMissedDoses(activeTreatments, days);
      case 'create_treatment':
      case 'update_dose_status':
      case 'show_adherence_chart':
        // These are handled by the UI layer — return a confirmation
        return 'Action "$functionName" will be executed by the app.';
      default:
        return 'Unknown function: $functionName';
    }
  }

  /// Sends a message and handles the full function-calling loop.
  /// Returns a stream of progressive text updates for the final response.
  /// [onToolCalls] is invoked when the model requests tool calls that
  /// the UI needs to handle (create_treatment, update_dose_status, show_adherence_chart).
  Stream<String> streamResponse(
    String userMessage, {
    List<Tratamiento>? activeTreatments,
    void Function(List<ToolCallResult>)? onToolCalls,
  }) async* {
    final prompt = userMessage.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('User message cannot be empty.');
    }

    if (_apiKey.isEmpty) {
      throw StateError(
        'Missing Groq API key. Run with --dart-define=GROQ_API_KEY=YOUR_KEY.',
      );
    }

    final treatments = activeTreatments ?? <Tratamiento>[];

    // Build messages array
    final messages = <Map<String, dynamic>>[
      <String, String>{
        'role': 'system',
        'content': _systemInstruction,
      },
      ..._history,
      <String, String>{'role': 'user', 'content': prompt},
    ];

    // Step 1: Send initial request (non-streaming) to check for tool calls
    final initialResponse = await _sendChatRequest(messages, useTools: true);

    final choice = initialResponse['choices']?[0] as Map<String, dynamic>?;
    if (choice == null) {
      throw StateError('The model returned an empty response.');
    }

    final messageRaw = choice['message'];
    if (messageRaw is! Map<String, dynamic>) {
      throw StateError('Invalid API response format (missing message): $choice');
    }
    final message = messageRaw;
    if (message['content'] == null) {
      message['content'] = '';
    }
    final toolCalls = message['tool_calls'] as List<dynamic>?;

    if (toolCalls != null && toolCalls.isNotEmpty) {
      // Model wants to call tools — execute them
      final List<ToolCallResult> uiToolCalls = [];
      
      // Add assistant message with tool_calls to the messages
      messages.add(message);

      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final fnObj = tcMap['function'] as Map<String, dynamic>;
        final fnName = fnObj['name'] as String;
        final argsString = fnObj['arguments'] as String? ?? '{}';
        final dynamic decodedArgs = jsonDecode(argsString.isEmpty ? '{}' : argsString);
        final fnArgs = decodedArgs is Map<String, dynamic> ? decodedArgs : <String, dynamic>{};
        final toolCallId = tcMap['id'] as String;

        // Sanitize string-numbers to int to prevent UI crashes if Groq leaks them
        for (final key in fnArgs.keys.toList()) {
          final val = fnArgs[key];
          if (val is String && (key == 'dosisPorToma' || key == 'intervaloDosis' || key == 'duracion' || key == 'minutosAplazo' || key == 'days')) {
            final parsed = int.tryParse(val);
            if (parsed != null) fnArgs[key] = parsed;
          }
        }

        // Execute locally or flag for UI
        final isUiAction = fnName == 'create_treatment' ||
            fnName == 'update_dose_status' ||
            fnName == 'show_adherence_chart';

        final result = executeToolFunction(fnName, fnArgs, treatments);

        if (isUiAction) {
          uiToolCalls.add(ToolCallResult(
            functionName: fnName,
            arguments: fnArgs,
            result: result,
          ));
        }

        // Add tool result to messages
        messages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'name': fnName,
          'content': result,
        });
      }

      // Notify UI of actions that need handling
      if (uiToolCalls.isNotEmpty && onToolCalls != null) {
        onToolCalls(uiToolCalls);
      }

      // Step 2: Send follow-up with tool results (streaming for final response)
      yield* _streamFinalResponse(messages, prompt);
    } else {
      // No tool calls — stream the direct response
      final content = message['content'] as String? ?? '';
      if (content.isEmpty) {
        throw StateError('The model returned an empty response.');
      }
      
      // Save to history
      _history.add(<String, String>{'role': 'user', 'content': prompt});
      _history.add(<String, String>{'role': 'assistant', 'content': content});
      _trimHistory();

      yield content;
    }
  }

  /// Sends a non-streaming chat request (used for tool-call detection).
  Future<Map<String, dynamic>> _sendChatRequest(
    List<Map<String, dynamic>> messages, {
    bool useTools = false,
    bool isRetry = false,
  }) async {
    final body = <String, dynamic>{
      'model': isRetry ? _fallbackModel : _model,
      'messages': messages,
      'stream': false,
      'temperature': 0.3,
      'max_tokens': _maxCompletionTokens,
    };

    if (useTools) {
      body['tools'] = _tools;
      body['tool_choice'] = 'auto';
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: <String, String>{
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 429 && !isRetry) {
      debugPrint('GeminiService: 429 Rate Limit. Retrying with $_fallbackModel');
      return _sendChatRequest(messages, useTools: useTools, isRetry: true);
    }

    if (response.statusCode != 200) {
      throw StateError('Groq API error (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Streams the final response after tool results have been added.
  Stream<String> _streamFinalResponse(
    List<Map<String, dynamic>> messages,
    String originalPrompt, {
    bool isRetry = false,
  }) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl))
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(<String, dynamic>{
        'model': isRetry ? _fallbackModel : _model,
        'stream': true,
        'temperature': 0.3,
        'max_tokens': _maxCompletionTokens,
        'messages': messages,
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      
      if (response.statusCode == 429 && !isRetry) {
        debugPrint('GeminiService: 429 Rate Limit on Stream. Retrying with $_fallbackModel');
        yield* _streamFinalResponse(messages, originalPrompt, isRetry: true);
        return;
      }

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
        if (!line.startsWith('data: ')) continue;

        final payload = line.substring(6).trim();
        if (payload == '[DONE]') break;

        try {
          final dynamic decoded = jsonDecode(payload);
          final decodedMap = decoded is Map<String, dynamic> ? decoded : null;
          final choices = decodedMap?['choices'] as List<dynamic>? ?? const [];
          if (choices.isEmpty) continue;

          final firstChoice = choices.first;
          if (firstChoice is! Map<String, dynamic>) continue;
          final deltaMap = firstChoice['delta'] as Map<String, dynamic>?;
          final delta = deltaMap?['content'] as String?;
          if (delta == null || delta.isEmpty) continue;

          fullText.write(delta);
          yield fullText.toString();
        } catch (_) {
          // Skip malformed SSE lines
          continue;
        }
      }

      if (fullText.isEmpty) {
        yield 'Acción completada.';
      }

      // Save to history
      _history.add(<String, String>{'role': 'user', 'content': originalPrompt});
      _history.add(<String, String>{
        'role': 'assistant',
        'content': fullText.toString(),
      });
      _trimHistory();
    } finally {
      client.close();
    }
  }

  // ─── Tool Implementation Functions ───

  String _getScheduledMedications(List<Tratamiento> treatments, DateTime date) {
    if (treatments.isEmpty) {
      return 'No active treatments found.';
    }

    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));
    final now = DateTime.now();
    final lines = <String>[];

    for (final t in treatments) {
      final doses = <String>[];
      t.doseStatus.forEach((key, status) {
        final doseTime = DateTime.tryParse(key);
        if (doseTime != null &&
            doseTime.isAfter(dateStart) &&
            doseTime.isBefore(dateEnd)) {
          final timeStr =
              '${doseTime.hour.toString().padLeft(2, '0')}:${doseTime.minute.toString().padLeft(2, '0')}';
          final isPast = doseTime.isBefore(now);
          doses.add('  - $timeStr: ${status.displayName}${isPast ? ' (past)' : ''}');
        }
      });

      if (doses.isNotEmpty) {
        lines.add('${t.nombreMedicamento} (${t.presentacion}, ${t.dosisPorToma} per dose):');
        lines.addAll(doses);
      }
    }

    if (lines.isEmpty) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return 'No doses scheduled for $dateStr.';
    }

    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'Medications for $dateStr:\n${lines.join('\n')}';
  }

  String _getActiveTreatmentsSummary(List<Tratamiento> treatments) {
    if (treatments.isEmpty) {
      return 'No active treatments.';
    }

    final lines = treatments.map((t) {
      final endStr = '${t.fechaFinTratamiento.year}-${t.fechaFinTratamiento.month.toString().padLeft(2, '0')}-${t.fechaFinTratamiento.day.toString().padLeft(2, '0')}';
      return '- ${t.nombreMedicamento}: ${t.presentacion}, '
          '${t.dosisPorToma} per dose every ${t.intervaloDosis.inHours}h, '
          'ends $endStr'
          '${t.notas.isNotEmpty ? ', notes: ${t.notas}' : ''}';
    }).toList();

    return 'Active treatments (${treatments.length}):\n${lines.join('\n')}';
  }

  String _getInventory(List<Tratamiento> treatments, String medName) {
    if (treatments.isEmpty) {
      return 'No active treatments.';
    }

    final filtered = medName.isEmpty
        ? treatments
        : treatments
            .where((t) => t.nombreMedicamento.toLowerCase().contains(medName.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return 'No medication found matching "$medName".';
    }

    final lines = filtered.map((t) {
      final remaining = t.cantidadActual;
      final total = t.cantidadTotalCaja;
      final isLow = t.hasStockBajo;
      return '- ${t.nombreMedicamento}: $remaining/$total remaining${isLow ? ' ⚠️ LOW STOCK' : ''}';
    }).toList();

    return 'Medication inventory:\n${lines.join('\n')}';
  }

  String _getMissedDoses(List<Tratamiento> treatments, int days) {
    if (treatments.isEmpty) {
      return 'No active treatments.';
    }

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final missed = <String>[];

    for (final t in treatments) {
      t.doseStatus.forEach((key, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(key);
          if (doseTime != null && doseTime.isAfter(cutoff) && doseTime.isBefore(now)) {
            final dateStr = '${doseTime.year}-${doseTime.month.toString().padLeft(2, '0')}-${doseTime.day.toString().padLeft(2, '0')} ${doseTime.hour.toString().padLeft(2, '0')}:${doseTime.minute.toString().padLeft(2, '0')}';
            missed.add('- ${t.nombreMedicamento}: missed on $dateStr');
          }
        }
      });
    }

    if (missed.isEmpty) {
      return 'No missed doses in the last $days days. Great adherence!';
    }

    return 'Missed doses (last $days days):\n${missed.join('\n')}';
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
    final messageData = choices.first['message'] as Map<String, dynamic>;
    final content = messageData['content'] as String;
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Evaluates potential drug-drug interactions between a new medication and active treatments.
  /// Returns a map containing:
  /// - `hasInteraction`: bool
  /// - `severity`: 'mild' | 'moderate' | 'severe'
  /// - `warningMessage`: String (Empathetic warning in Spanish advising doctor consultation)
  Future<Map<String, dynamic>> checkDrugInteractions({
    required String newDrugName,
    required List<Tratamiento> activeTreatments,
  }) async {
    final cleanNewName = newDrugName.trim();
    if (cleanNewName.isEmpty || activeTreatments.isEmpty) {
      return {'hasInteraction': false};
    }

    final otherTreatments = activeTreatments
        .where((t) => t.nombreMedicamento.trim().toLowerCase() != cleanNewName.toLowerCase())
        .toList();

    if (otherTreatments.isEmpty) {
      return {'hasInteraction': false};
    }

    final activeMedsList = otherTreatments
        .map((t) => '${t.nombreMedicamento} (${t.presentacion})')
        .join(', ');

    if (_apiKey.isEmpty) {
      return {'hasInteraction': false};
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': _fallbackModel,
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
          'messages': <Map<String, dynamic>>[
            <String, String>{
              'role': 'system',
              'content':
                  'Eres un asistente de farmacología clínica. Analiza si existen interacciones medicamentosas clínicamente relevantes entre un nuevo fármaco que el usuario desea agregar y su lista de tratamientos activos actuales. '
                  'Formato JSON requerido de salida exclusivamente: '
                  '{"hasInteraction": boolean, "severity": "mild"|"moderate"|"severe", "warningMessage": "Mensaje en español con advertencia suave, empática y clara. Ejemplo: \'Tomar Ibuprofeno e Hidroclorotiazida juntos puede afectar la presión arterial; te sugiero consultarlo con tu médico.\' Retorna string vacío si hasInteraction es false."}',
            },
            <String, String>{
              'role': 'user',
              'content':
                  'Nuevo fármaco a agregar: "$cleanNewName".\n'
                  'Tratamientos activos del paciente: $activeMedsList.',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        return {'hasInteraction': false};
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return {'hasInteraction': false};
      final messageData = choices.first['message'] as Map<String, dynamic>?;
      final content = messageData?['content'] as String?;
      if (content == null || content.isEmpty) return {'hasInteraction': false};

      final parsed = jsonDecode(content) as Map<String, dynamic>;
      return <String, dynamic>{
        'hasInteraction': parsed['hasInteraction'] == true,
        'severity': parsed['severity'] ?? 'moderate',
        'warningMessage': parsed['warningMessage']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('Error checking drug interactions: $e');
      return {'hasInteraction': false};
    }
  }

  /// Keeps context short to reduce token usage on free plans.
  void _trimHistory() {
    if (_history.length <= _maxHistoryMessages) {
      return;
    }

    _history.removeRange(0, _history.length - _maxHistoryMessages);
  }

  /// Clears the in-memory conversation history.
  /// Call this when starting a new chat or switching chat sessions
  /// to prevent stale context from bleeding between conversations.
  void clearHistory() {
    _history.clear();
  }

  /// Synchronizes the internal history with a provided history state.
  /// Useful when rewriting chat history (e.g., editing past messages).
  void syncHistory(List<Map<String, dynamic>> newHistory) {
    _history.clear();
    _history.addAll(newHistory);
    _trimHistory();
  }
}
