import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VoiceService {
  final String _apiKey;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSpeaking = false;
  final String _whisperModel = 'whisper-large-v3-turbo';
  final String _whisperUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  VoiceService({String? apiKey})
      : _apiKey = apiKey ??
            const String.fromEnvironment('GROQ_API_KEY') {
    _initTts();
  }

  void Function()? onTtsComplete;

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('es-MX');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      onTtsComplete?.call();
    });
  }

  bool get isRecording => _isRecording;
  bool get isSpeaking => _isSpeaking;

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _silenceTimer;
  void Function()? _onSilence;

  Future<String> startRecordingAndTranscribe({void Function()? onSilence}) async {
    _onSilence = onSilence;
    await _flutterTts.stop();
    _isSpeaking = false;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw Exception(
            'No se concedió permiso para acceder al micrófono.');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/meditime_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _audioRecorder.start(config, path: filePath);
      _isRecording = true;

      _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        if (amp.current < -35.0) {
          _silenceTimer ??= Timer(const Duration(seconds: 2), () {
            _onSilence?.call();
          });
        } else {
          _silenceTimer?.cancel();
          _silenceTimer = null;
        }
      });

      return filePath;
    } catch (e) {
      _isRecording = false;
      rethrow;
    }
  }

  void _cleanupSilenceDetection() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  Future<void> cancelRecording() async {
    _cleanupSilenceDetection();
    final path = await _audioRecorder.stop();
    _isRecording = false;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<String> stopRecordingAndTranscribe() async {
    _cleanupSilenceDetection();
    String? path;
    try {
      path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        throw Exception(
            'No se pudo obtener la ruta del archivo de audio grabado.');
      }

      final file = File(path);
      if (!await file.exists()) {
        throw Exception(
            'El archivo de audio grabado no existe: $path');
      }

      final request =
          http.MultipartRequest('POST', Uri.parse(_whisperUrl));
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.files
          .add(await http.MultipartFile.fromPath('file', path));
      request.fields['model'] = _whisperModel;
      request.fields['language'] = 'es';
      request.fields['response_format'] = 'json';

      final streamedResponse = await request.send();
      final response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
            'Error en la API de Whisper (${response.statusCode}): ${response.body}');
      }

      final jsonResponse =
          jsonDecode(response.body) as Map<String, dynamic>;
      final transcribedText = jsonResponse['text'] as String? ?? '';

      // Clean up temporary file
      try {
        await file.delete();
      } catch (_) {
        // Ignore deletion errors
      }

      return transcribedText;
    } catch (e) {
      _isRecording = false;
      // Clean up temporary file on error
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      rethrow;
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    _isSpeaking = true;

    // Remove markdown bold markers
    String cleanedText = text.replaceAll('**', '');
    // Remove emoji characters (Unicode emoji ranges)
    cleanedText = cleanedText.replaceAll(
        RegExp(
            r'[\u{1F600}-\u{1F64F}'
            r'\u{1F300}-\u{1F5FF}'
            r'\u{1F680}-\u{1F6FF}'
            r'\u{1F1E0}-\u{1F1FF}'
            r'\u{2600}-\u{26FF}'
            r'\u{2700}-\u{27BF}'
            r'\u{FE00}-\u{FE0F}'
            r'\u{1F900}-\u{1F9FF}'
            r'\u{1FA00}-\u{1FA6F}'
            r'\u{1FA70}-\u{1FAFF}'
            r'\u{200D}'
            r'\u{20E3}'
            r'\u{E0020}-\u{E007F}]',
            unicode: true),
        '');
    cleanedText = cleanedText.trim();

    if (cleanedText.isEmpty) {
      _isSpeaking = false;
      return;
    }

    await _flutterTts.speak(cleanedText);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
      }
    } catch (_) {
      // Ignore errors during cleanup
    }

    try {
      await _flutterTts.stop();
    } catch (_) {
      // Ignore errors during cleanup
    }

    try {
      _audioRecorder.dispose();
    } catch (_) {
      // Ignore errors during cleanup
    }
  }
}
