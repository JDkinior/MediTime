import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:meditime/models/caregiver_profile.dart';
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
      : _explicitApiKey = apiKey?.trim();

  final String? _explicitApiKey;

  Future<String> getEffectiveApiKey() async {
    if (_explicitApiKey != null && _explicitApiKey.isNotEmpty) {
      return _explicitApiKey;
    }
    return const String.fromEnvironment('GROQ_API_KEY').trim();
  }

  // Production chat models supported across Groq accounts on LPU platform.
  static const String _model = 'openai/gpt-oss-20b';
  static const String _fallbackModel = 'llama-3.3-70b-versatile';
  // Vision model supported by Groq
  static const String _visionModel = 'qwen/qwen3.8-27b';
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
2. CRITICAL: NEVER write function/tool calls as text. Do NOT output JSON like {"function": "..."} or XML like <function>. Tool calls happen invisibly in the background.
3. When you need data, call the tool silently. Then respond naturally using the result.
4. Capabilities: "Puedo consultar tus dosis del día, tratamientos activos, agendar recordatorios o ver tu adherencia."
5. Use tools for data. DO NOT invent.
6. Format meds in bold **nombre**.
''';

  @visibleForTesting
  static List<Map<String, dynamic>> get tools => _tools;

  /// Tool definitions for Groq function calling.
  static const List<Map<String, dynamic>> _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'get_today_medications',
        'description': 'Get today\'s medications and statuses.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_tomorrow_medications',
        'description': 'Get tomorrow\'s medications.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_active_treatments',
        'description': 'Get summary of active treatments.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
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
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
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

    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      throw StateError(
        'Falta la clave de Groq API. Configúrala en la app o ejecuta con --dart-define=GROQ_API_KEY=TU_CLAVE.',
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
    final initialResponse = await _sendChatRequest(
      messages,
      apiKey: apiKey,
      useTools: true,
    );

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
      yield* _streamFinalResponse(messages, prompt, apiKey: apiKey);
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
    required String apiKey,
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
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if ((response.statusCode == 429 || response.statusCode == 400 || response.statusCode == 404) && !isRetry) {
      debugPrint('GeminiService: ${response.statusCode} Error. Retrying with $_fallbackModel without tools');
      return _sendChatRequest(messages, apiKey: apiKey, useTools: false, isRetry: true);
    }

    if (response.statusCode != 200) {
      final errorBody = response.body;
      debugPrint('Groq API error (${response.statusCode}): $errorBody');
      if (response.statusCode == 401 || errorBody.contains('invalid_api_key')) {
        throw StateError('Error de autenticación (401): La clave de Groq API es inválida o expiró. Verifica tu clave en console.groq.com.');
      } else if (response.statusCode == 404 || errorBody.contains('model_not_found') || errorBody.contains('does not exist')) {
        throw StateError('El modelo de IA solicitado no está disponible en tu cuenta de Groq (Error 404).');
      } else if (response.statusCode == 413 || errorBody.contains('too large')) {
        throw StateError('El mensaje es demasiado extenso para el modelo (413).');
      } else if (response.statusCode == 429 || errorBody.contains('rate_limit')) {
        throw StateError('Límite de solicitudes alcanzado (429). Espera unos segundos e intenta nuevamente.');
      }
      throw StateError('Error al procesar la solicitud (${response.statusCode}): ${response.reasonPhrase ?? "Error de conexión"}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Streams the final response after tool results have been added.
  Stream<String> _streamFinalResponse(
    List<Map<String, dynamic>> messages,
    String originalPrompt, {
    required String apiKey,
    bool isRetry = false,
  }) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl))
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $apiKey',
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
      
      if ((response.statusCode == 429 || response.statusCode == 400 || response.statusCode == 404) && !isRetry) {
        debugPrint('GeminiService: ${response.statusCode} Error on Stream. Retrying with $_fallbackModel');
        yield* _streamFinalResponse(messages, originalPrompt, apiKey: apiKey, isRetry: true);
        return;
      }

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        debugPrint('Groq API error (${response.statusCode}): $errorBody');
        if (response.statusCode == 401 || errorBody.contains('invalid_api_key')) {
          throw StateError('Error de autenticación (401): La clave de Groq API es inválida o expiró. Verifica tu clave en console.groq.com.');
        } else if (response.statusCode == 404 || errorBody.contains('model_not_found') || errorBody.contains('does not exist')) {
          throw StateError('El modelo de IA solicitado no está disponible en tu cuenta de Groq (Error 404).');
        } else if (response.statusCode == 429 || errorBody.contains('rate_limit')) {
          throw StateError('Límite de solicitudes alcanzado (429). Espera un momento e intenta de nuevo.');
        }
        throw StateError('Error temporal (${response.statusCode}). Por favor, intenta de nuevo.');
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
          // Apply real-time filter before yielding to prevent artifacts appearing in UI
          yield _sanitizeModelOutput(fullText.toString());
        } catch (_) {
          // Skip malformed SSE lines
          continue;
        }
      }

      if (fullText.isEmpty) {
        yield 'Acción completada.';
      } else {
        // Final pass: strip all hallucinated function output patterns
        final cleanText = _sanitizeModelOutput(fullText.toString()).trim();
        // If after sanitizing nothing remains, yield a fallback
        if (cleanText.isEmpty) {
          yield 'Acción completada.';
        }
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

  /// Strips hallucinated function call patterns from model text output.
  /// Handles: JSON {"function": "..."}, XML function tags, and similar artifacts.
  static String _sanitizeModelOutput(String text) {
    // Remove JSON-style function calls: {"function": "name", ...} or {"function":"name"}
    // This catches single-line and multi-line JSON function blobs
    var clean = text.replaceAll(
      RegExp(r'\{[^{}]*"function"[^{}]*\}', multiLine: true),
      '',
    );

    // Remove XML-style function tags: <function=name> or <function>...</function>
    clean = clean.replaceAll(RegExp(r'</?function[^>]*>', caseSensitive: false), '');

    // Remove leftover tool call markers that some models emit
    clean = clean.replaceAll(RegExp(r'<\|[^|]*\|>', caseSensitive: false), '');

    // Remove <think>...</think> reasoning blocks that reasoning models may emit
    clean = clean.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');

    // Clean up multiple consecutive blank lines left behind by removed blocks
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return clean;
  }


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
    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      throw StateError(
        'Falta la clave de Groq API. Configúrala en la app o ejecuta con --dart-define=GROQ_API_KEY=TU_CLAVE.',
      );
    }

    final messages = <Map<String, dynamic>>[
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
    ];

    // Direct query to Groq vision model with timeout and fallback handling
    final visionModels = [
      _visionModel,
    ];
    http.Response? lastResponse;
    Object? lastException;

    for (final model in visionModels) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': model,
            'temperature': 0.1,
            'max_completion_tokens': 1024,
            'messages': messages,
          }),
        ).timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          lastResponse = response;
          break;
        }

        lastResponse = response;
        debugPrint('Vision model $model failed (${response.statusCode}): ${response.body}');

        // If 401 (auth error), don't keep trying models
        if (response.statusCode == 401) {
          break;
        }
      } catch (e) {
        lastException = e;
        debugPrint('Exception querying vision model $model: $e');
      }
    }

    if (lastResponse == null || lastResponse.statusCode != 200) {
      final errorBody = lastResponse?.body ?? '';
      final statusCode = lastResponse?.statusCode ?? 0;
      debugPrint('Groq Vision API error ($statusCode): $errorBody');

      String? apiErrorMessage;
      try {
        if (errorBody.isNotEmpty) {
          final errJson = jsonDecode(errorBody) as Map<String, dynamic>;
          if (errJson['error'] is Map && errJson['error']['message'] != null) {
            apiErrorMessage = errJson['error']['message'].toString();
          }
        }
      } catch (_) {}

      String errorMsg;
      if (statusCode == 401 || errorBody.contains('invalid_api_key')) {
        errorMsg = 'Error de autenticación (401): La clave de Groq API es inválida o expiró. Verifica tu clave en console.groq.com.';
      } else if (statusCode == 413 || errorBody.contains('too large') || errorBody.contains('request_entity_too_large')) {
        errorMsg = 'La imagen es demasiado pesada para el modelo de visión (413). Toma una foto más cercana o comprimida.';
      } else if (statusCode == 404 || errorBody.contains('model_not_found') || errorBody.contains('do not have access')) {
        errorMsg = 'El modelo de visión no está disponible en tu cuenta de Groq (Error 404)${apiErrorMessage != null ? ": $apiErrorMessage" : ""}.';
      } else if (statusCode == 429 || errorBody.contains('rate_limit')) {
        errorMsg = 'Se alcanzó el límite de peticiones de Groq (Error 429). Espera unos segundos e intenta nuevamente.';
      } else if (lastException != null && lastResponse == null) {
        errorMsg = 'No se pudo conectar con el servicio de visión. Comprueba tu conexión a internet e inténtalo de nuevo.';
      } else if (apiErrorMessage != null && apiErrorMessage.isNotEmpty) {
        errorMsg = 'Error al analizar la imagen ($statusCode): $apiErrorMessage';
      } else {
        errorMsg = 'No se pudo analizar la imagen en este momento. Intenta de nuevo o ingresa los datos manualmente.';
      }
      throw StateError(errorMsg);
    }

    final decoded = jsonDecode(lastResponse.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    if (choices.isEmpty) return null;
    final messageData = choices.first['message'] as Map<String, dynamic>;
    final rawContent = messageData['content'] as String;

    // Strip <think>...</think> reasoning blocks (Qwen and other reasoning models)
    // Strip markdown code fences (```json ... ```)
    // Then extract the first { ... } JSON object
    String jsonStr = rawContent
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // If still not starting with {, find the first { character
    final braceStart = jsonStr.indexOf('{');
    final braceEnd = jsonStr.lastIndexOf('}');
    if (braceStart != -1 && braceEnd != -1 && braceEnd > braceStart) {
      jsonStr = jsonStr.substring(braceStart, braceEnd + 1);
    }

    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to parse prescription JSON: $jsonStr, error: $e');
      throw const FormatException('No se pudo interpretar el formato de los datos de la receta. Intenta tomar una foto más nítida.');
    }
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

    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      return {'hasInteraction': false};
    }

    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': _model,
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
          'messages': <Map<String, dynamic>>[
            <String, String>{
              'role': 'system',
              'content':
                  'Eres un experto en farmacología clínica. Analiza si existen interacciones medicamentosas reales y clínicamente relevantes entre el nuevo fármaco y los tratamientos activos. '
                  'REGLA CRÍTICA: Si alguno de los fármacos no existe, es inventado, es desconocido, o NO hay interacción comprobada, DEBES retornar estrictamente {"hasInteraction": false, "severity": "", "warningMessage": ""}. '
                  'Si SÍ hay interacción comprobada médica y científicamente, retorna {"hasInteraction": true, "severity": "mild"|"moderate"|"severe", "warningMessage": "Advertencia breve y empática explicando el posible efecto."}. '
                  'IMPORTANTE: Responde ÚNICAMENTE con el objeto JSON. No inventes interacciones ni asumas similitudes.',
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
        response = await http.post(
          Uri.parse(_baseUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
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
                    'Eres un experto en farmacología clínica. Analiza si existen interacciones medicamentosas reales y clínicamente relevantes entre el nuevo fármaco y los tratamientos activos. '
                    'REGLA CRÍTICA: Si alguno de los fármacos no existe, es inventado, es desconocido, o NO hay interacción comprobada, DEBES retornar estrictamente {"hasInteraction": false, "severity": "", "warningMessage": ""}. '
                    'Si SÍ hay interacción comprobada médica y científicamente, retorna {"hasInteraction": true, "severity": "mild"|"moderate"|"severe", "warningMessage": "Advertencia breve y empática explicando el posible efecto."}. '
                    'IMPORTANTE: Responde ÚNICAMENTE con el objeto JSON. No inventes interacciones ni asumas similitudes.',
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
      }

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

  /// Generates 2-3 short, personalized tips based on active treatments, adherence, and active profile/mode.
  Future<List<Map<String, String>>> generateTreatmentTips({
    required List<Tratamiento> treatments,
    required int pendingCount,
    required int takenCount,
    required double adherenceRate,
    bool isAnimalMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? profile,
    String language = 'es',
  }) async {
    // Filtrar estrictamente solo tratamientos activos (excluyendo historial médico finalizado)
    final activeTreatments = treatments.where((t) => t.isActivo).toList();
    final effectiveTreatments = activeTreatments.isNotEmpty
        ? activeTreatments
        : treatments.where((t) => !t.isFinalizado).toList();

    final isAnimal = isAnimalMode || (profile != null && profile.isAnimal);

    if (effectiveTreatments.isEmpty) {
      if (isAnimal) {
        if (language == 'en') {
          return [
            {
              'title': '🐾 Pet Up to Date',
              'content': 'Add your pet\'s medications with the "+" button to receive reminders and veterinary tips.',
              'isAi': 'false',
            },
            {
              'title': '🐾 Animal Wellness',
              'content': 'Keeping their doses on schedule prevents relapses and ensures a stress-free recovery.',
              'isAi': 'false',
            },
          ];
        } else if (language == 'pt') {
          return [
            {
              'title': '🐾 Pet em Dia',
              'content': 'Adicione os medicamentos do seu pet com o botão "+" para receber lembretes e dicas veterinárias.',
              'isAi': 'false',
            },
            {
              'title': '🐾 Bem-estar Animal',
              'content': 'Manter as doses no horário evita recaídas e garante uma recuperação tranquila.',
              'isAi': 'false',
            },
          ];
        }
        return [
          {
            'title': '🐾 Mascota al Día',
            'content': 'Agrega los medicamentos de tu mascota con el botón "+" para recibir recordatorios y tips veterinarios.',
            'isAi': 'false',
          },
          {
            'title': '🐾 Bienestar Animal',
            'content': 'Mantener sus dosis a tiempo previene recaídas y asegura una recuperación sin estrés.',
            'isAi': 'false',
          },
        ];
      } else if (caregiverModeType == CaregiverModeType.clinico) {
        if (language == 'en') {
          return [
            {
              'title': '🩺 Clinical Record',
              'content': 'Add the patient\'s prescription with the "+" button to begin dosing and traceability.',
              'isAi': 'false',
            },
            {
              'title': '🩺 Clinical Safety',
              'content': 'MediTime assists you in following the 5 rights and safe medication administration.',
              'isAi': 'false',
            },
          ];
        } else if (language == 'pt') {
          return [
            {
              'title': '🩺 Registro Clínico',
              'content': 'Adicione a prescrição do paciente com o botão "+" para iniciar a dosagem e rastreabilidade.',
              'isAi': 'false',
            },
            {
              'title': '🩺 Segurança Clínica',
              'content': 'O MediTime auxilia no cumprimento dos 5 certos e na administração segura.',
              'isAi': 'false',
            },
          ];
        }
        return [
          {
            'title': '🩺 Registro Clínico',
            'content': 'Añade la prescripción del paciente con el botón "+" para iniciar la dosificación y trazabilidad.',
            'isAi': 'false',
          },
          {
            'title': '🩺 Seguridad Clínica',
            'content': 'MediTime te asiste en el cumplimiento de los 5 correctos y la administración segura.',
            'isAi': 'false',
          },
        ];
      } else if (caregiverModeType == CaregiverModeType.familiar) {
        if (language == 'en') {
          return [
            {
              'title': '👨‍👩‍👧 Family Care',
              'content': 'Add your family member\'s medications with the "+" button to organize their daily schedule with care.',
              'isAi': 'false',
            },
            {
              'title': '👨‍👩‍👧 Peace of Mind',
              'content': 'Receive timely alerts and practical advice to accompany your loved one with every dose.',
              'isAi': 'false',
            },
          ];
        } else if (language == 'pt') {
          return [
            {
              'title': '👨‍👩‍👧 Cuidado Familiar',
              'content': 'Adicione os medicamentos do seu familiar com o botão "+" para organizar o calendário com carinho.',
              'isAi': 'false',
            },
            {
              'title': '👨‍👩‍👧 Tranquilidade em Casa',
              'content': 'Receba alertas pontuais e dicas práticas para acompanhar seu familiar em cada dose.',
              'isAi': 'false',
            },
          ];
        }
        return [
          {
            'title': '👨‍👩‍👧 Cuidado Familiar',
            'content': 'Agrega los medicamentos de tu familiar con el botón "+" para organizar su calendario diario con amor.',
            'isAi': 'false',
          },
          {
            'title': '👨‍👩‍👧 Tranquilidad en Casa',
            'content': 'Recibe alertas puntuales y consejos prácticos para acompañar a tu familiar en cada toma.',
            'isAi': 'false',
          },
        ];
      }

      if (language == 'en') {
        return [
          {
            'title': 'Start your Record',
            'content': 'Add your medications with the "+" button to receive reminders and AI tips.',
            'isAi': 'false',
          },
          {
            'title': 'Wellness and Health',
            'content': 'Keeping your treatments on schedule prevents complications and ensures your recovery.',
            'isAi': 'false',
          },
        ];
      } else if (language == 'pt') {
        return [
          {
            'title': 'Comece seu Registro',
            'content': 'Adicione seus medicamentos com o botão "+" para receber lembretes e dicas com IA.',
            'isAi': 'false',
          },
          {
            'title': 'Bem-estar e Saúde',
            'content': 'Manter seus tratamentos em dia evita complicações e garante sua recuperação.',
            'isAi': 'false',
          },
        ];
      }

      return [
        {
          'title': 'Comienza tu Registro',
          'content': 'Agrega tus medicamentos con el botón "+" para recibir recordatorios y tips con IA.',
          'isAi': 'false',
        },
        {
          'title': 'Bienestar y Salud',
          'content': 'Mantener tus tratamientos al día previene complicaciones y asegura tu recuperación.',
          'isAi': 'false',
        },
      ];
    }

    final fallbackTips = getFallbackTips(
      treatments: effectiveTreatments,
      pendingCount: pendingCount,
      takenCount: takenCount,
      adherenceRate: adherenceRate,
      isAnimalMode: isAnimalMode,
      caregiverModeType: caregiverModeType,
      profile: profile,
      language: language,
    );

    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      return fallbackTips;
    }

    try {
      final medsSummary = effectiveTreatments.map((t) {
        final hours = t.intervaloDosis.inHours;
        final interval = hours > 0 ? '${hours}h' : '${t.intervaloDosis.inMinutes}min';
        return '- ${t.nombreMedicamento} (${t.presentacion}), cada $interval, dosis: ${t.dosisPorToma}'
            '${t.notas.isNotEmpty ? ', indicaciones: ${t.notas}' : ''}';
      }).join('\n');

      String modeContext;
      if (isAnimal) {
        final petName = profile?.name.isNotEmpty == true ? profile!.name : 'la mascota';
        final species = profile?.species?.isNotEmpty == true ? profile!.species! : 'mascota';
        final breed = profile?.breed?.isNotEmpty == true ? ', raza: ${profile!.breed}' : '';
        final weight = profile?.weight?.isNotEmpty == true ? ', peso: ${profile!.weight}' : '';
        modeContext = 'MODO MASCOTAS / VETERINARIO (Paciente animal: $petName, especie: $species$breed$weight). '
            'Los consejos deben ser estrictamente veterinarios: pautas amigables para dar pastillas a mascotas (envolver en snack o comida húmeda permitida, uso de jeringa sin aguja en la comisura bucal para líquidos, refuerzo positivo con caricias tras la toma, JAMÁS dar fármacos humanos como paracetamol o ibuprofeno que son letales para mascotas, vigilar apetito o vómitos).';
      } else if (caregiverModeType == CaregiverModeType.clinico) {
        final patientName = profile?.name.isNotEmpty == true ? profile!.name : 'el paciente';
        final room = profile?.roomNumber?.isNotEmpty == true ? ', Hab/Cama: ${profile!.roomNumber}' : '';
        final blood = profile?.bloodType?.isNotEmpty == true ? ', Info clínica: ${profile!.bloodType}' : '';
        modeContext = 'MODO CUIDADOR CLÍNICO PROFESIONAL (Atención hospitalaria/institucional a: $patientName$room$blood). '
            'Consejos de enfermería y farmacología clínica: verificar los 5 correctos (paciente, fármaco, dosis, vía, horario), control de constantes vitales o glucemia antes de dosis críticas, registro estricto en la ficha clínica, vigilancia de interacciones o efectos adversos.';
      } else if (caregiverModeType == CaregiverModeType.familiar) {
        final famName = profile?.name.isNotEmpty == true ? profile!.name : 'el familiar';
        final rel = profile?.relationship.isNotEmpty == true ? ' (${profile!.relationship})' : '';
        modeContext = 'MODO CUIDADOR FAMILIAR (Cuidador en el hogar para: $famName$rel). '
            'Consejos empáticos para la familia: rutinas diarias conectadas a momentos agradables (desayuno, descanso), acompañamiento afectivo y paciencia, supervisión de la deglución con un buen vaso de agua, observación de mareos, somnolencia o cambios de humor.';
      } else {
        modeContext = 'MODO PACIENTE PERSONAL. El usuario gestiona su propia medicación diaria y bienestar.';
      }

      final String prompt;
      final String systemInstruction;
      if (language == 'en') {
        systemInstruction = 'You are an expert physician and pharmacologist delivering concise health micro-tips in JSON format.';
        prompt = '''
You are MediTime's medical and pharmacological assistant. Generate exactly 2 or 3 very brief, practical, and motivating tips in English for this user.

CONTEXT:
$modeContext

ACTIVE TREATMENTS:
$medsSummary

TODAY'S ADHERENCE STATUS:
${adherenceRate.toStringAsFixed(0)}% ($takenCount taken, $pendingCount pending).

KEY GUIDELINES:
1. AT LEAST ONE TIP MUST BE SPECIFIC to the listed active medications (food interactions, administration guidelines, or precautions: e.g. empty stomach for PPIs, NSAIDs with food, finish full antibiotic cycle, rinse mouth after inhaler).
2. AT LEAST ONE TIP MUST ADAPT TO THE ACTIVE MODE (${isAnimal ? 'pets/veterinary' : caregiverModeType == CaregiverModeType.clinico ? 'clinical' : caregiverModeType == CaregiverModeType.familiar ? 'family caregiver' : 'personal'}).
3. You may include general high-value tips like hydration with a full glass of water, punctuality, or praise for adherence.
4. STRICT FORMAT RULES:
   - 'title': Maximum 3 to 5 words, clear and engaging (e.g. '🐾 Treat Technique', '🩺 The 5 Rights', 'Take on Empty Stomach', 'Key Hydration', 'Great Consistency!').
   - 'content': Between 70 and 135 characters (1 or 2 concise sentences, easy to read on mobile screen).
   - Respond ONLY in JSON with the key "tips":
   {"tips": [{"title": "...", "content": "..."}, {"title": "...", "content": "..."}]}
''';
      } else if (language == 'pt') {
        systemInstruction = 'Você é um médico e farmacologista especialista que fornece microdicas concisas de saúde em formato JSON.';
        prompt = '''
Você é o assistente médico e farmacológico do MediTime. Gere exatamente 2 ou 3 dicas muito breves, práticas e motivadoras em português para este usuário.

CONTEXTO:
$modeContext

TRATAMENTOS ATIVOS:
$medsSummary

STATUS DE ADESÃO HOJE:
${adherenceRate.toStringAsFixed(0)}% ($takenCount tomadas, $pendingCount pendentes).

DIRETRIZES:
1. PELO MENOS UMA DICA DEVE SER ESPECÍFICA sobre os medicamentos ativos listados (interações com alimentos, modo de tomar ou precauções: ex. protetores em jejum, AINEs com comida, antibiótico ciclo completo, inalador enxaguar a boca).
2. PELO MENOS UMA DICA DEVE ADAPTAR-SE AO MODO ATIVO (${isAnimal ? 'pets/veterinário' : caregiverModeType == CaregiverModeType.clinico ? 'clínico' : caregiverModeType == CaregiverModeType.familiar ? 'cuidador familiar' : 'pessoal'}).
3. Você pode incluir dicas gerais valiosas como hidratação com um copo d'água, pontualidade ou felicitações por adesão.
4. REGRAS ESTRITAS DE FORMATO:
   - 'title': Máximo 3 a 5 palavras, claro e atrativo (ex: '🐾 Dica com petisco', '🩺 Os 5 certos', 'Tome em jejum', 'Hidratação chave', 'Excelente constância!').
   - 'content': Entre 70 e 135 caracteres (1 ou 2 frases concisas, fáceis de ler na tela).
   - Responda APENAS em JSON com a chave "tips":
   {"tips": [{"title": "...", "content": "..."}, {"title": "...", "content": "..."}]}
''';
      } else {
        systemInstruction = 'Eres un médico y farmacólogo experto que entrega micro-consejos de salud concisos en formato JSON.';
        prompt = '''
Eres el asistente médico y farmacológico de MediTime. Genera exactamente 2 o 3 consejos muy breves, prácticos y motivadores en español para este usuario.

CONTEXTO:
$modeContext

TRATAMIENTOS ACTIVOS:
$medsSummary

ESTADO DE ADHERENCIA HOY:
${adherenceRate.toStringAsFixed(0)}% ($takenCount tomadas, $pendingCount pendientes).

DIRECTRICES CLAVE:
1. AL MENOS UN CONSEJO DEBE SER ESPECÍFICO sobre los medicamentos activos listados (interacciones con alimentos, pautas de toma o precauciones según el principio activo o forma farmacéutica: p.ej. protectores en ayunas, AINEs con comida, antibiótico ciclo completo, inhalador enjuagar boca, etc.).
2. AL MENOS UN CONSEJO DEBE ADAPTARSE AL MODO ACTIVO (${isAnimal ? 'mascotas/veterinario' : caregiverModeType == CaregiverModeType.clinico ? 'clínico' : caregiverModeType == CaregiverModeType.familiar ? 'cuidador familiar' : 'personal'}).
3. Puedes incluir también consejos habituales de gran valor como hidratación con un vaso de agua, constancia de horario, o felicitación por adherencia.
4. REGLAS ESTRICTAS DE FORMATO:
   - 'title': Máximo 3 a 5 palabras, claro y atractivo (ej: '🐾 Toma con premio', '🩺 Los 5 correctos', 'Omeprazol en ayunas', 'Hidratación clave', '¡Gran constancia!').
   - 'content': Entre 70 y 135 caracteres (1 o 2 oraciones concisas y fáciles de leer en pantalla).
   - Responde ÚNICAMENTE en JSON con la clave "tips":
   {"tips": [{"title": "...", "content": "..."}, {"title": "...", "content": "..."}]}
''';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': _fallbackModel,
          'response_format': {'type': 'json_object'},
          'max_tokens': 450,
          'temperature': 0.2,
          'messages': <Map<String, dynamic>>[
            {
              'role': 'system',
              'content': systemInstruction,
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
        }),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final contentStr = data['choices']?[0]?['message']?['content'];
        if (contentStr != null) {
          final parsed = jsonDecode(contentStr);
          if (parsed is Map && parsed['tips'] is List) {
            final List<Map<String, String>> tips = [];
            for (var item in parsed['tips']) {
              if (item is Map && item['title'] != null && item['content'] != null) {
                tips.add({
                  'title': item['title'].toString().trim(),
                  'content': item['content'].toString().trim(),
                  'isAi': 'true',
                });
              }
            }
            if (tips.isNotEmpty) {
              return tips;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating treatment tips via AI: $e');
    }

    return fallbackTips;
  }

  List<Map<String, String>> getFallbackTips({
    required List<Tratamiento> treatments,
    required int pendingCount,
    required int takenCount,
    required double adherenceRate,
    bool isAnimalMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? profile,
    String language = 'es',
  }) {
    // Filtrar estrictamente solo tratamientos activos (excluyendo historial médico finalizado)
    final activeTreatments = treatments.where((t) => t.isActivo).toList();
    final effectiveTreatments = activeTreatments.isNotEmpty
        ? activeTreatments
        : treatments.where((t) => !t.isFinalizado).toList();

    final List<Map<String, String>> medTips = [];
    final isAnimal = isAnimalMode || (profile != null && profile.isAnimal);
    final petName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (language == 'en' ? 'your pet' : (language == 'pt' ? 'seu pet' : 'tu mascota'));
    final famName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (language == 'en' ? 'your family member' : (language == 'pt' ? 'seu familiar' : 'tu familiar'));

    // ─── 1. Consejos Específicos por Medicamento ───
    for (var t in effectiveTreatments) {
      final name = t.nombreMedicamento.toLowerCase();
      final pres = t.presentacion.toLowerCase();

      // Protectores gástricos
      if (name.contains('omeprazol') || name.contains('pantoprazol') || name.contains('esomeprazol') || name.contains('lansoprazol')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 Gastric protector' : (language == 'pt' ? '🐾 Protetor gástrico' : '🐾 Protector gástrico');
          content = language == 'en'
              ? 'Administer the protector to $petName about 30 min before meals to protect their stomach.'
              : (language == 'pt'
                  ? 'Administre o protetor a $petName cerca de 30 min antes da ração para cuidar do estômago.'
                  : 'Administra el protector a $petName unos 30 min antes de su ración para cuidar su estómago.');
        } else {
          title = language == 'en' ? 'Take on empty stomach' : (language == 'pt' ? 'Tome em jejum' : 'Toma en ayunas');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} about 30 min before breakfast for maximum stomach protection.'
              : (language == 'pt'
                  ? 'Tome o ${t.nombreMedicamento} cerca de 30 min antes do café da manhã para máxima proteção gástrica.'
                  : 'Toma el ${t.nombreMedicamento} unos 30 min antes del desayuno para máxima protección gástrica.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // AINEs y analgésicos
      else if (name.contains('ibuprofeno') || name.contains('naproxeno') || name.contains('diclofenaco') || name.contains('ketorolaco') || name.contains('celecoxib') || name.contains('meloxicam')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 Caution with NSAIDs' : (language == 'pt' ? '🐾 Cuidado com AINEs' : '🐾 Cuidado con AINEs');
          content = language == 'en'
              ? 'Only use NSAIDs prescribed by your veterinarian and always give with food.'
              : (language == 'pt'
                  ? 'Use apenas anti-inflamatórios receitados pelo veterinário e sempre com alimento.'
                  : 'Usa solo antiinflamatorios recetados por el veterinario y siempre junto a su comida.');
        } else {
          title = language == 'en' ? 'Take with food' : (language == 'pt' ? 'Acompanhe com comida' : 'Acompaña con comida');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} with food or milk to protect your stomach lining.'
              : (language == 'pt'
                  ? 'Tome o ${t.nombreMedicamento} com alimentos ou leite para proteger a mucosa do estômago.'
                  : 'Toma el ${t.nombreMedicamento} con alimentos o leche para proteger la mucosa de tu estómago.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Paracetamol / Acetaminofén
      else if (name.contains('paracetamol') || name.contains('acetaminofen') || name.contains('acetaminofén') || name.contains('tylenol')) {
        if (isAnimal) {
          final title = language == 'en' ? '🐾 Toxicity alert!' : (language == 'pt' ? '🐾 Alerta de toxicidade!' : '🐾 ¡Alerta toxicidad!');
          final content = language == 'en'
              ? 'NEVER give paracetamol or acetaminophen to $petName; it is highly toxic and fatal to animals.'
              : (language == 'pt'
                  ? 'NUNCA dê paracetamol ou acetaminofeno a $petName; é altamente tóxico e mortal em animais.'
                  : 'NUNCA des paracetamol o acetaminofén a $petName; es altamente tóxico y mortal en animales.');
          medTips.add({'title': title, 'content': content});
        } else {
          final title = language == 'en' ? 'Safe interval' : (language == 'pt' ? 'Intervalo seguro' : 'Intervalo seguro');
          final content = language == 'en'
              ? 'Follow schedules for ${t.nombreMedicamento} without exceeding the maximum daily recommended dose.'
              : (language == 'pt'
                  ? 'Respeite os horários de ${t.nombreMedicamento} sem exceder a dose máxima diária recomendada.'
                  : 'Respeta los horarios de ${t.nombreMedicamento} sin exceder la dosis máxima diaria recomendada.');
          medTips.add({'title': title, 'content': content});
        }
      }
      // Antibióticos
      else if (name.contains('amoxicilina') || name.contains('azitromicina') || name.contains('ciprofloxacino') || name.contains('cefalexina') || name.contains('doxiciclina') || name.contains('claritromicina')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 Full course' : (language == 'pt' ? '🐾 Ciclo completo' : '🐾 Ciclo completo');
          content = language == 'en'
              ? 'Complete all antibiotic days prescribed for $petName even if they are active and seem better.'
              : (language == 'pt'
                  ? 'Complete todos os dias de antibiótico prescritos para $petName mesmo que já brinque e pareça bem.'
                  : 'Completa todos los días de antibiótico recetados a $petName aunque ya juegue y se vea mejor.');
        } else {
          title = language == 'en' ? 'Complete antibiotic' : (language == 'pt' ? 'Antibiótico regular' : 'Antibiótico regular');
          content = language == 'en'
              ? 'Complete the full duration of antibiotic ${t.nombreMedicamento} even if you feel better.'
              : (language == 'pt'
                  ? 'Complete a duração total do antibiótico ${t.nombreMedicamento} mesmo se já se sentir melhor.'
                  : 'Completa la duración total del antibiótico ${t.nombreMedicamento} aunque te sientas mejor.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Cardiovasculares / Antihipertensivos
      else if (name.contains('losartan') || name.contains('losartán') || name.contains('enalapril') || name.contains('amlodipino') || name.contains('atenolol') || name.contains('carvedilol') || name.contains('valsartan')) {
        String title;
        String content;
        if (caregiverModeType == CaregiverModeType.clinico) {
          title = language == 'en' ? '🩺 BP Check' : (language == 'pt' ? '🩺 Controle de PA' : '🩺 Control de TA');
          content = language == 'en'
              ? 'Evaluate blood pressure and pulse before administering ${t.nombreMedicamento}.'
              : (language == 'pt'
                  ? 'Avalie pressão arterial e pulso antes de administrar ${t.nombreMedicamento}.'
                  : 'Evalúa tensión arterial y pulso antes de suministrar ${t.nombreMedicamento}.');
        } else {
          title = language == 'en' ? 'Blood pressure' : (language == 'pt' ? 'Pressão arterial' : 'Presión arterial');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} at the same time each day to maintain stable cardiovascular control.'
              : (language == 'pt'
                  ? 'Tome ${t.nombreMedicamento} no mesmo horário todos os dias para manter o controle cardiovascular estável.'
                  : 'Toma ${t.nombreMedicamento} a la misma hora cada día para mantener un control cardiovascular estable.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Antidiabéticos orales
      else if (name.contains('metformina') || name.contains('glibenclamida') || name.contains('gliclazida')) {
        final title = language == 'en' ? 'Glucose and food' : (language == 'pt' ? 'Glicose e refeição' : 'Glucosa y comida');
        final content = language == 'en'
            ? 'Take ${t.nombreMedicamento} during or immediately after main meals.'
            : (language == 'pt'
                ? 'Tome a ${t.nombreMedicamento} durante ou logo após as principais refeições.'
                : 'Toma la ${t.nombreMedicamento} durante o inmediatamente después de las comidas principales.');
        medTips.add({'title': title, 'content': content});
      }
      // Insulina
      else if (name.contains('insulina') || name.contains('glargina') || name.contains('lantus') || name.contains('lispro')) {
        String title;
        String content;
        if (caregiverModeType == CaregiverModeType.clinico) {
          title = language == 'en' ? '🩺 Pre-dose glucose' : (language == 'pt' ? '🩺 Glicemia prévia' : '🩺 Glucemia previa');
          content = language == 'en'
              ? 'Check capillary blood glucose before administering the indicated dose of insulin.'
              : (language == 'pt'
                  ? 'Verifique a glicemia capilar antes de aplicar a dose prescrita de insulina.'
                  : 'Verifica la glucemia capilar antes de aplicar la dosis indicada de insulina.');
        } else {
          title = language == 'en' ? 'Insulin care' : (language == 'pt' ? 'Cuidados com insulina' : 'Cuidado de insulina');
          content = language == 'en'
              ? 'Keep in-use insulin at room temperature and rotate injection sites.'
              : (language == 'pt'
                  ? 'Mantenha a insulina em uso em temperatura ambiente e alterne os locais de aplicação.'
                  : 'Mantén la insulina en uso a temperatura ambiente y alterna los sitios de aplicación.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Levotiroxina
      else if (name.contains('levotiroxina') || name.contains('eutirox')) {
        final title = language == 'en' ? 'Strict fasting' : (language == 'pt' ? 'Jejum estrito' : 'Ayuno estricto');
        final content = language == 'en'
            ? 'Take levothyroxine with water only upon waking, and wait 30-60 min before breakfast.'
            : (language == 'pt'
                ? 'Tome a levotiroxina apenas com água ao acordar e aguarde 30-60 min antes do café.'
                : 'Toma la levotiroxina solo con agua al despertar y espera 30-60 min antes de desayunar.');
        medTips.add({'title': title, 'content': content});
      }
      // Inhaladores
      else if (pres.contains('inhalador') || name.contains('salbutamol') || name.contains('budesonida') || name.contains('fluticasona')) {
        final title = language == 'en' ? 'Rinse mouth' : (language == 'pt' ? 'Enxágue bucal' : 'Enjuague bucal');
        final content = language == 'en'
            ? 'After using ${t.nombreMedicamento} inhaler, rinse your mouth with water to prevent thrush.'
            : (language == 'pt'
                ? 'Após usar o inalador de ${t.nombreMedicamento}, enxágue a boca com água para evitar sapinho.'
                : 'Tras usar el inhalador de ${t.nombreMedicamento}, enjuágate la boca con agua para evitar aftas.');
        medTips.add({'title': title, 'content': content});
      }
      // Corticoides
      else if (name.contains('prednisona') || name.contains('prednisolona') || name.contains('dexametasona')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 With food' : (language == 'pt' ? '🐾 Com alimento' : '🐾 Con alimento');
          content = language == 'en'
              ? 'Give the corticosteroid to $petName always with their food to avoid stomach irritation.'
              : (language == 'pt'
                  ? 'Dê o corticoide a $petName sempre com a ração para não irritar o estômago.'
                  : 'Da el corticoide a $petName siempre con su comida para no irritar su estómago.');
        } else {
          title = language == 'en' ? 'Morning dose' : (language == 'pt' ? 'Dose matinal' : 'Toma matutina');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} in the morning with breakfast, respecting your body\'s hormone rhythm.'
              : (language == 'pt'
                  ? 'Tome ${t.nombreMedicamento} pela manhã com o café respeitando o ciclo hormonal.'
                  : 'Toma ${t.nombreMedicamento} en la mañana con el desayuno respetando el ciclo hormonal.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Gotas oftálmicas
      else if (pres.contains('gota') || pres.contains('colirio') || name.contains('gotas')) {
        final title = language == 'en' ? 'Drop hygiene' : (language == 'pt' ? 'Higiene nas gotas' : 'Higiene en gotas');
        final content = language == 'en'
            ? 'Wash your hands before applying drops and avoid touching the dropper tip to any surface.'
            : (language == 'pt'
                ? 'Lave as mãos antes de aplicar as gotas e evite encostar o bico dosador em qualquer superfície.'
                : 'Lava tus manos antes de aplicar las gotas y evita que la punta del gotero toque superficies.');
        medTips.add({'title': title, 'content': content});
      }
      // Jarabes y suspensiones
      else if (pres.contains('jarabe') || pres.contains('suspension') || pres.contains('suspensión')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 With syringe' : (language == 'pt' ? '🐾 Com seringa' : '🐾 Con jeringa');
          content = language == 'en'
              ? 'Give syrup to $petName slowly with a syringe through the corner of their mouth.'
              : (language == 'pt'
                  ? 'Aplique o xarope a $petName devagar com seringa pelo canto da boca.'
                  : 'Aplica el jarabe a $petName con jeringa despacio por la comisura lateral de su boca.');
        } else {
          title = language == 'en' ? 'Shake before use' : (language == 'pt' ? 'Agite antes de usar' : 'Agitar antes de usar');
          content = language == 'en'
              ? 'Shake the ${t.nombreMedicamento} bottle well before each dose to homogenize the medicine.'
              : (language == 'pt'
                  ? 'Agite bem o frasco de ${t.nombreMedicamento} antes de cada dose para homogeneizar o remédio.'
                  : 'Agita bien el frasco de ${t.nombreMedicamento} antes de cada toma para homogeneizar la dosis.');
        }
        medTips.add({'title': title, 'content': content});
      }
    }

    // ─── 2. Consejos Específicos por Modo (Mascotas, Familiar, Clínico) ───
    final List<Map<String, String>> modeTips = [];
    if (isAnimal) {
      modeTips.add({
        'title': language == 'en' ? '🐾 Praise & love' : (language == 'pt' ? '🐾 Carinho e reforço' : '🐾 Refuerzo y caricias'),
        'content': language == 'en'
            ? 'Pet and praise $petName after taking their dose to create a positive routine.'
            : (language == 'pt'
                ? 'Faça carinho e recompense $petName após a dose para associar o remédio a algo positivo.'
                : 'Acaricia y premia a $petName después de su toma para que asocie la medicación a algo positivo.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🐾 Food technique' : (language == 'pt' ? '🐾 Técnica na ração' : '🐾 Técnica en comida'),
        'content': language == 'en'
            ? 'For pills, you can hide the dose inside a treat or allowable wet food.'
            : (language == 'pt'
                ? 'Para comprimidos, você pode envolver a dose em um petisco ou alimento úmido permitido.'
                : 'Para comprimidos, puedes envolver la dosis en una bolita de comida húmeda o snack apto.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🐾 Warning signs' : (language == 'pt' ? '🐾 Sinais de alerta' : '🐾 Signos de alerta'),
        'content': language == 'en'
            ? 'If you notice loss of appetite, lethargy or vomiting after dosing, contact your veterinarian promptly.'
            : (language == 'pt'
                ? 'Se notar falta de apetite, letargia ou vômitos após a dose, contate o veterinário imediatamente.'
                : 'Si notas inapetencia, letargo o vómitos tras la dosis, contacta de inmediato con su veterinario.'),
      });
    } else if (caregiverModeType == CaregiverModeType.clinico) {
      modeTips.add({
        'title': language == 'en' ? '🩺 The 5 Rights' : (language == 'pt' ? '🩺 Os 5 certos' : '🩺 Los 5 correctos'),
        'content': language == 'en'
            ? 'Verify patient, drug, dose, route and time before administering any medication.'
            : (language == 'pt'
                ? 'Verifique paciente, medicamento, dose, via e horário antes de administrar qualquer fármaco.'
                : 'Comprueba paciente, medicamento, dosis, vía y horario antes de suministrar cualquier fármaco.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🩺 Vital signs' : (language == 'pt' ? '🩺 Sinais vitais' : '🩺 Signos vitales'),
        'content': language == 'en'
            ? 'Assess patient vital signs before and after administering controlled or sedative drugs.'
            : (language == 'pt'
                ? 'Avalie os sinais vitais do paciente antes e após administrar fármacos de controle ou sedativos.'
                : 'Evalúa las constantes del paciente antes y después de administrar fármacos de control o sedantes.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🩺 Immediate chart' : (language == 'pt' ? '🩺 Registro imediato' : '🩺 Registro inmediato'),
        'content': language == 'en'
            ? 'Record every administered or refused dose in the clinical chart to guarantee traceability.'
            : (language == 'pt'
                ? 'Anote no prontuário cada dose administrada ou recusada para garantir a rastreabilidade.'
                : 'Anota en la ficha clínica cada toma administrada o rechazada para garantizar la trazabilidad.'),
      });
    } else if (caregiverModeType == CaregiverModeType.familiar) {
      modeTips.add({
        'title': language == 'en' ? '👨‍👩‍👧 Shared routine' : (language == 'pt' ? '👨‍👩‍👧 Rotina compartilhada' : '👨‍👩‍👧 Rutina compartida'),
        'content': language == 'en'
            ? 'Pair $famName\'s doses with pleasant moments like breakfast or a calm conversation.'
            : (language == 'pt'
                ? 'Associe as doses de $famName a momentos agradáveis como o café ou uma conversa tranquila.'
                : 'Asocia las tomas de $famName a hábitos agradables como el desayuno o una charla tranquila.'),
      });
      modeTips.add({
        'title': language == 'en' ? '👨‍👩‍👧 Gentle care' : (language == 'pt' ? '👨‍👩‍👧 Supervisão gentil' : '👨‍👩‍👧 Supervisión suave'),
        'content': language == 'en'
            ? 'Accompany $famName with a glass of water and make sure with patience that they swallow the dose.'
            : (language == 'pt'
                ? 'Acompanhe $famName com um copo d\'água e certifique-se com paciência de que engoliu a dose.'
                : 'Acompaña a $famName con un vaso de agua y asegúrate con paciencia de que trague la dosis.'),
      });
      modeTips.add({
        'title': language == 'en' ? '👨‍👩‍👧 Daily observation' : (language == 'pt' ? '👨‍👩‍👧 Observação diária' : '👨‍👩‍👧 Observación diaria'),
        'content': language == 'en'
            ? 'Watch for changes in mood, balance or drowsiness after new doses and note them for their doctor.'
            : (language == 'pt'
                ? 'Observe mudanças de humor, locomoção ou sonolência após novas doses e anote para o médico.'
                : 'Observa cambios de ánimo, marcha o somnolencia tras nuevas tomas y anótalos para su médico.'),
      });
    }

    // ─── 3. Consejos Generales de Adherencia e Hidratación ───
    final List<Map<String, String>> generalTips = [];
    if (adherenceRate >= 100 && takenCount > 0) {
      generalTips.add({
        'title': language == 'en' ? 'Great consistency!' : (language == 'pt' ? 'Excelente constância!' : '¡Excelente constancia!'),
        'content': language == 'en'
            ? '100% of your doses are on track today. Punctuality ensures the best health outcomes.'
            : (language == 'pt'
                ? 'Você está com 100% das suas doses em dia. A disciplina nos horários garante os melhores resultados.'
                : 'Llevas el 100% de tus dosis al día. La disciplina en los horarios asegura los mejores resultados.'),
      });
    } else if (pendingCount > 0) {
      generalTips.add({
        'title': language == 'en' ? 'Pending doses' : (language == 'pt' ? 'Doses pendentes' : 'Dosis pendientes'),
        'content': language == 'en'
            ? 'You have $pendingCount dose${pendingCount > 1 ? 's' : ''} pending today. Remember to log them on time.'
            : (language == 'pt'
                ? 'Você tem $pendingCount dose${pendingCount > 1 ? 's' : ''} pendente${pendingCount > 1 ? 's' : ''} hoje. Lembre-se de registrá-las a tempo.'
                : 'Tienes $pendingCount toma${pendingCount > 1 ? 's' : ''} pendiente${pendingCount > 1 ? 's' : ''} hoy. Recuerda registrarlas a tiempo.'),
      });
    }

    generalTips.add({
      'title': isAnimal
          ? (language == 'en' ? '🐾 Fresh water' : (language == 'pt' ? '🐾 Água fresca' : '🐾 Agua fresca'))
          : (language == 'en' ? 'Hydration key' : (language == 'pt' ? 'Hidratação chave' : 'Hidratación clave')),
      'content': isAnimal
          ? (language == 'en'
              ? 'Ensure $petName has clean, fresh water readily available after taking medicine.'
              : (language == 'pt'
                  ? 'Certifique-se de que $petName tenha água limpa e fresca disponível após tomar o remédio.'
                  : 'Asegúrate de que $petName tenga agua limpia y fresca disponible tras tomar su medicina.'))
          : (language == 'en'
              ? 'Always accompany your pills with a full glass of water for optimal digestive absorption.'
              : (language == 'pt'
                  ? 'Acompanhe sempre seus comprimidos com um copo cheio de água para melhor absorção.'
                  : 'Acompaña siempre tus comprimidos con un vaso lleno de agua para una absorción digestiva óptima.')),
    });

    // ─── 4. Combinación balanceada de 2 a 3 consejos ───
    final List<Map<String, String>> selectedTips = [];

    // Prioridad 1: Al menos 1 consejo específico del medicamento
    if (medTips.isNotEmpty) {
      selectedTips.add(medTips.first);
    }

    // Prioridad 2: Al menos 1 consejo adaptado al modo
    if (modeTips.isNotEmpty) {
      selectedTips.add(modeTips.first);
    }

    // Prioridad 3: Añadir segundo tip de medicamento o tip general
    if (selectedTips.length < 3 && medTips.length > 1) {
      selectedTips.add(medTips[1]);
    }

    for (var gen in generalTips) {
      if (selectedTips.length >= 3) break;
      if (!selectedTips.any((t) => t['title'] == gen['title'])) {
        selectedTips.add(gen);
      }
    }

    while (selectedTips.length < 2) {
      selectedTips.add({
        'title': language == 'en' ? 'Daily wellness' : (language == 'pt' ? 'Bem-estar diário' : 'Bienestar diario'),
        'content': language == 'en'
            ? 'Taking your medications at the exact time prevents complications and speeds recovery.'
            : (language == 'pt'
                ? 'Tomar seus medicamentos no horário exato evita complicações e acelera a recuperação.'
                : 'Tomar tus medicamentos a la hora exacta previene complicaciones y acelera tu recuperación.'),
      });
    }

    return selectedTips.take(3).map((tip) {
      return {
        'title': tip['title'] ?? '',
        'content': tip['content'] ?? '',
        'isAi': 'false',
      };
    }).toList();
  }
}
