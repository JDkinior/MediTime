import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Services, Notifiers, Theme
import 'package:meditime/services/gemini_service.dart';
import 'package:meditime/services/voice_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/treatment_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:intl/intl.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  static const String routeName = '/chatbot';

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  static const List<Color> _chatGradient = <Color>[
    Color(0xFF2F6DB4),
    Color(0xFF49C2FF),
  ];
  static const double _composerRadius = 30;
  static const String _midiOpenAsset = 'assets/chatbot/midi_open.png';
  static const String _midiBlinkAsset = 'assets/chatbot/midi_blink.png';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          '¡Hola! Soy tu asistente virtual de MediTime. Estoy aquí para ayudarte a organizar tus medicamentos, recordarte tus dosis o responder cualquier duda que tengas sobre la aplicación. ¿En qué te puedo ayudar hoy?',
      isUser: false,
    ),
  ];

  String? _currentChatId;
  Stream<QuerySnapshot>? _chatSessionsStream;
  String? _lastStreamUserId;

  bool _isGenerating = false;
  bool _hasText = false;
  bool _isBlinking = false;
  bool _isRecording = false;
  bool _wasLastInputVoice = false;
  Timer? _blinkTimer;
  VoiceService? _voiceService;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleInputChanged);
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_midiOpenAsset), context);
    precacheImage(const AssetImage(_midiBlinkAsset), context);

    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    if (user != null && user.uid != _lastStreamUserId) {
      _lastStreamUserId = user.uid;
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      _chatSessionsStream = firestoreService.getChatSessionsStream(user.uid);
    } else if (user == null) {
      _lastStreamUserId = null;
      _chatSessionsStream = null;
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _voiceService?.dispose();
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

  static Shader _sparklesGradientShader(Rect bounds) {
    return const LinearGradient(
      colors: [Color(0xFF2F6DB4), Color(0xFF49C2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds);
  }

  Future<void> _scanPrescription() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar Foto de la Receta'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Seleccionar de la Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _messages.add(const _ChatMessage(
        text: 'Analizando la foto de tu receta médica... 🔍 Un momento por favor.',
        isUser: false,
        isStreaming: true,
      ));
    });
    _scrollToBottom();

    final loadingMessageIndex = _messages.length - 1;

    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

      final geminiService = context.read<GeminiService>();
      final result = await geminiService.analyzePrescriptionImage(base64Image, mimeType);

      if (result != null) {
        final parsedData = {
          'nombreMedicamento': result['nombreMedicamento'] ?? '',
          'presentacion': result['presentacion'] ?? '',
          'dosisPorToma': int.tryParse(result['dosisPorToma']?.toString() ?? '') ?? 1,
          'intervaloDosis': int.tryParse(result['intervaloDosis']?.toString() ?? '') ?? 8,
          'duracion': int.tryParse(result['duracion']?.toString() ?? '') ?? 7,
          'notas': result['notas'] ?? '',
          'isSaved': false,
        };

        setState(() {
          _messages.removeAt(loadingMessageIndex);
          _messages.add(_ChatMessage(
            text: 'He analizado tu receta. Por favor, confirma los datos extraídos para poder guardarla:',
            isUser: false,
            prescriptionData: parsedData,
          ));
        });
      } else {
        throw Exception('No se pudo extraer información.');
      }
    } catch (e) {
      setState(() {
        _messages[loadingMessageIndex] = _ChatMessage(
          text: 'No logré extraer la información de la receta. Por favor, asegúrate de que la foto sea clara e inténtalo de nuevo, o escribe los datos.',
          isUser: false,
        );
      });
    }
    _scrollToBottom();
  }

  void _sendSuggestion(String promptText) {
    _messageController.text = promptText;
    _sendMessage();
  }

  Future<void> _sendMessage({bool fromVoice = false}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) {
      return;
    }

    _messageController.clear();
    FocusScope.of(context).unfocus();

    _wasLastInputVoice = fromVoice;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(
        const _ChatMessage(text: '', isUser: false, isStreaming: true),
      );
      _isGenerating = true;
    });
    _scrollToBottom();

    final geminiService = context.read<GeminiService>();
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;

    List<Tratamiento>? activeTreatments;
    if (user != null) {
      try {
        final allTreatments = await firestoreService.getMedicamentosStream(user.uid).first;
        final now = DateTime.now();
        activeTreatments = allTreatments.where((t) => t.fechaFinTratamiento.isAfter(now)).toList();
      } catch (_) {}
    }

    final botMessageIndex = _messages.length - 1;

    // Variables to collect tool-call actions for the UI
    Map<String, dynamic>? prescriptionData;
    bool showAdherenceChart = false;
    final List<Map<String, dynamic>> updateDoseActions = [];

    try {
      await for (final partialText in geminiService.streamResponse(
        text,
        activeTreatments: activeTreatments,
        onToolCalls: (toolCalls) {
          // Process UI-level tool calls from function calling
          for (final tc in toolCalls) {
            switch (tc.functionName) {
              case 'create_treatment':
                prescriptionData = Map<String, dynamic>.from(tc.arguments);
                prescriptionData!['isSaved'] = false;
                break;
              case 'update_dose_status':
                updateDoseActions.add(tc.arguments);
                break;
              case 'show_adherence_chart':
                showAdherenceChart = true;
                break;
            }
          }
        },
      )) {
        if (!mounted) return;
        setState(() {
          _messages[botMessageIndex] = _messages[botMessageIndex].copyWith(
            text: partialText,
            isStreaming: true,
          );
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages[botMessageIndex] = _ChatMessage(
          text: _buildUserFriendlyError(error),
          isUser: false,
          isStreaming: false,
        );
      });
    } finally {
      if (mounted) {
        final botMsg = _messages[botMessageIndex];

        setState(() {
          _messages[botMessageIndex] = botMsg.copyWith(
            text: botMsg.text.trim(),
            isStreaming: false,
            prescriptionData: prescriptionData,
            showAdherenceChart: showAdherenceChart,
          );
          _isGenerating = false;
        });

        // Execute dose update actions from function calling
        for (final action in updateDoseActions) {
          final med = action['medicamento']?.toString() ?? '';
          final status = action['status']?.toString() ?? 'tomada';
          final mins = int.tryParse(action['minutosAplazo']?.toString() ?? '') ?? 30;
          final updateAll = action['updateAll'] == true || action['updateAll'] == 'true';
          _executeUpdateDose(med, status, mins, updateAll);
        }

        // TTS: speak response if message came from voice input
        if (fromVoice && botMsg.text.isNotEmpty) {
          _voiceService ??= VoiceService();
          _voiceService!.speak(botMsg.text);
        }

        _scrollToBottom();
      }
      await _saveChatToFirestore();
    }
  }

  // ─── Voice Chat Methods ───

  void _editMessageDialog(int index, String oldText) {
    final controller = TextEditingController(text: oldText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editMessage(index, controller.text);
            },
            child: const Text('Guardar y re-enviar'),
          ),
        ],
      ),
    );
  }

  void _editMessage(int index, String newText) {
    if (newText.trim().isEmpty) return;

    setState(() {
      _messages.removeRange(index, _messages.length);
      final List<Map<String, dynamic>> newHistory = [];
      for (final msg in _messages) {
        if (msg.text.isNotEmpty && !msg.isStreaming) {
          newHistory.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
      }
      context.read<GeminiService>().syncHistory(newHistory);
    });

    _messageController.text = newText;
    _sendMessage();
  }

  Future<void> _startVoiceRecording() async {
    if (_isGenerating || _isRecording) return;
    
    if (_voiceService == null) {
      _voiceService = VoiceService();
      _voiceService!.onTtsComplete = () {
        if (!mounted || _isRecording || _isGenerating || !_wasLastInputVoice || _messages.isEmpty) return;
        final lastMsg = _messages.last.text.trim();
        if (lastMsg.endsWith('?') || lastMsg.endsWith(':')) {
          _startVoiceRecording();
        }
      };
    }

    try {
      await _voiceService!.startRecordingAndTranscribe(
        onSilence: () {
          if (mounted) _stopVoiceRecordingAndSend();
        }
      );
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar grabación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording || _voiceService == null) return;
    await _voiceService!.cancelRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _stopVoiceRecordingAndSend() async {
    if (!_isRecording || _voiceService == null) return;

    setState(() => _isRecording = false);

    try {
      final transcribedText = await _voiceService!.stopRecordingAndTranscribe();
      if (transcribedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se detectó audio. Intenta de nuevo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      _messageController.text = transcribedText;
      _sendMessage(fromVoice: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al transcribir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _executeUpdateDose(String medName, String statusStr, int minutes, bool updateAll) async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null || medName.isEmpty) return;

    try {
      final treatments = await firestoreService.getMedicamentosStream(user.uid).first;
      final now = DateTime.now();
      // Filter out finished treatments
      final runningTreatments = treatments.where((t) => t.fechaFinTratamiento.isAfter(now)).toList();

      final DoseStatus status = DoseStatus.fromString(statusStr);

      final isAll = medName.toLowerCase() == 'todos' ||
          medName.toLowerCase() == 'todas' ||
          medName.toLowerCase() == 'todo' ||
          medName.toLowerCase() == 'all';

      if (isAll) {
        int updatedCount = 0;
        for (final treatment in runningTreatments) {
          final doseTime = _findClosestDose(treatment);
          if (doseTime != null) {
            if (status == DoseStatus.aplazada) {
              final newDoseTime = doseTime.add(Duration(minutes: minutes));
              final docRef = firestoreService.getMedicamentoDocRef(user.uid, treatment.id);
              await FirebaseFirestore.instance.runTransaction((transaction) async {
                final snapshot = await transaction.get(docRef);
                if (!snapshot.exists) return;
                final t = Tratamiento.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
                final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
                final oldKey = doseTime.toIso8601String();
                updatedMap.remove(oldKey);
                updatedMap[newDoseTime.toIso8601String()] = DoseStatus.aplazada;
                transaction.update(docRef, {'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value))});
              });
              final doc = await docRef.get();
              if (doc.exists) {
                final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                await NotificationService.rescheduleNextPendingDose(updatedTratamiento, user.uid);
              }
            } else {
              await firestoreService.updateDoseStatus(
                user.uid,
                treatment.id,
                doseTime,
                status,
              );
            }
            updatedCount++;
          }
        }

        setState(() {
          _messages.add(_ChatMessage(
            text: updatedCount > 0
                ? '¡Se actualizaron **$updatedCount** dosis de tus medicamentos activos a **${status.displayName}** con éxito!'
                : 'No encontré ninguna dosis programada o pendiente cercana para actualizar.',
            isUser: false,
          ));
        });
      } else {
        final treatment = runningTreatments.firstWhere(
          (t) => t.nombreMedicamento.toLowerCase().contains(medName.toLowerCase()),
          orElse: () => throw Exception('No se encontró el medicamento "$medName".'),
        );

        if (updateAll) {
          final now = DateTime.now();
          final limitTime = now.add(const Duration(hours: 4));
          final List<DateTime> pendingDoses = [];
          
          treatment.doseStatus.forEach((key, doseStat) {
            if (doseStat == DoseStatus.pendiente || doseStat == DoseStatus.aplazada || doseStat == DoseStatus.notificada) {
              final time = DateTime.tryParse(key);
              if (time != null && time.isBefore(limitTime)) {
                pendingDoses.add(time);
              }
            }
          });

          if (pendingDoses.isEmpty) {
            setState(() {
              _messages.add(_ChatMessage(
                text: 'No encontré ninguna dosis pendiente o programada cercana para **${treatment.nombreMedicamento}**.',
                isUser: false,
              ));
            });
            _scrollToBottom();
            return;
          }

          int updatedCount = 0;
          for (final doseTime in pendingDoses) {
            if (status == DoseStatus.aplazada) {
              final newDoseTime = doseTime.add(Duration(minutes: minutes));
              final docRef = firestoreService.getMedicamentoDocRef(user.uid, treatment.id);
              await FirebaseFirestore.instance.runTransaction((transaction) async {
                final snapshot = await transaction.get(docRef);
                if (!snapshot.exists) return;
                final t = Tratamiento.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
                final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
                final oldKey = doseTime.toIso8601String();
                updatedMap.remove(oldKey);
                updatedMap[newDoseTime.toIso8601String()] = DoseStatus.aplazada;
                transaction.update(docRef, {'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value))});
              });
              final doc = await docRef.get();
              if (doc.exists) {
                final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                await NotificationService.rescheduleNextPendingDose(updatedTratamiento, user.uid);
              }
            } else {
              await firestoreService.updateDoseStatus(
                user.uid,
                treatment.id,
                doseTime,
                status,
              );
            }
            updatedCount++;
          }

          setState(() {
            _messages.add(_ChatMessage(
              text: '¡Se actualizaron **$updatedCount** dosis de **${treatment.nombreMedicamento}** a **${status.displayName}** con éxito!',
              isUser: false,
            ));
          });
        } else {
          final doseTime = _findClosestDose(treatment);
          if (doseTime == null) {
            setState(() {
              _messages.add(_ChatMessage(
                text: 'No encontré ninguna dosis pendiente o programada cercana para **${treatment.nombreMedicamento}**.',
                isUser: false,
              ));
            });
            _scrollToBottom();
            return;
          }

          if (status == DoseStatus.aplazada) {
            final newDoseTime = doseTime.add(Duration(minutes: minutes));
            final docRef = firestoreService.getMedicamentoDocRef(user.uid, treatment.id);
            
            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final snapshot = await transaction.get(docRef);
              if (!snapshot.exists) return;
              final t = Tratamiento.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
              final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
              final oldKey = doseTime.toIso8601String();
              updatedMap.remove(oldKey);
              updatedMap[newDoseTime.toIso8601String()] = DoseStatus.aplazada;
              transaction.update(docRef, {'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value))});
            });

            final doc = await docRef.get();
            if (doc.exists) {
              final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
              await NotificationService.rescheduleNextPendingDose(updatedTratamiento, user.uid);
            }

            setState(() {
              _messages.add(_ChatMessage(
                text: '¡Dosis de **${treatment.nombreMedicamento}** aplazada por **$minutes minutos** con éxito!',
                isUser: false,
              ));
            });
          } else {
            final inventoryResult = await firestoreService.updateDoseStatus(
              user.uid,
              treatment.id,
              doseTime,
              status,
            );

            String successMsg = '¡Dosis de **${treatment.nombreMedicamento}** marcada como **${status.displayName}** con éxito!';
            if (status == DoseStatus.tomada && inventoryResult?.stockBajo == true) {
              successMsg += '\n⚠️ *Advertencia: Stock bajo de este medicamento. Te quedan ${inventoryResult!.dosisRestantes} dosis.*';
            }

            setState(() {
              _messages.add(_ChatMessage(
                text: successMsg,
                isUser: false,
              ));
            });
          }
        }
      }
      _scrollToBottom();
      _saveChatToFirestore();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'No pude realizar la acción de actualización: ${e.toString()}',
          isUser: false,
        ));
      });
      _scrollToBottom();
      _saveChatToFirestore();
    }
  }

  DateTime? _findClosestDose(Tratamiento t) {
    final now = DateTime.now();
    DateTime? closest;
    Duration? minDiff;

    t.doseStatus.forEach((key, status) {
      final time = DateTime.tryParse(key);
      if (time != null) {
        final diff = time.difference(now).abs();
        if (minDiff == null || diff < minDiff!) {
          minDiff = diff;
          closest = time;
        }
      }
    });
    return closest;
  }

  Future<void> _saveChatToFirestore() async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null || _messages.isEmpty) return;

    final userMessages = _messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;

    final firstUserMsg = userMessages.first.text;
    final title = firstUserMsg.length > 30 ? '${firstUserMsg.substring(0, 27)}...' : firstUserMsg;

    _currentChatId ??= FirebaseFirestore.instance.collection('dummy').doc().id;

    final messagesData = _messages
        .where((m) => !m.isStreaming)
        .map((m) => {
              'text': m.text,
              'isUser': m.isUser,
              if (m.prescriptionData != null) 'prescriptionData': m.prescriptionData,
              if (m.showAdherenceChart) 'showAdherenceChart': true,
            })
        .toList();

    try {
      await firestoreService.saveChatSession(
        user.uid,
        _currentChatId!,
        title,
        messagesData,
      );
    } catch (e) {
      debugPrint("Error saving chat session: $e");
    }
  }

  void _loadChatSession(String chatId, String title, List<dynamic> messagesData) {
    // Clear AI memory to prevent stale medication context from previous sessions
    final geminiService = context.read<GeminiService>();
    geminiService.clearHistory();

    setState(() {
      _currentChatId = chatId;
      _messages.clear();
      for (final m in messagesData) {
        if (m is Map) {
          _messages.add(_ChatMessage(
            text: m['text'] as String? ?? '',
            isUser: m['isUser'] as bool? ?? false,
            prescriptionData: m['prescriptionData'] != null
                ? Map<String, dynamic>.from(m['prescriptionData'] as Map)
                : null,
            showAdherenceChart: m['showAdherenceChart'] as bool? ?? false,
          ));
        }
      }
      _isGenerating = false;
    });
    _scrollToBottom();
  }

  void _startNewChat() {
    // Clear AI memory to start fresh without stale treatment context
    final geminiService = context.read<GeminiService>();
    geminiService.clearHistory();

    setState(() {
      _currentChatId = null;
      _messages.clear();
      _messages.add(
        const _ChatMessage(
          text: '¡Hola! Soy tu asistente virtual de MediTime. Estoy aquí para ayudarte a organizar tus medicamentos, recordarte tus dosis o responder cualquier duda que tengas sobre la aplicación. ¿En qué te puedo ayudar hoy?',
          isUser: false,
        ),
      );
      _isGenerating = false;
    });
    _scrollToBottom();
  }

  String _buildUserFriendlyError(Object error) {
    final errorText = error.toString();
    final normalized = errorText.toLowerCase();

    if (normalized.contains('missing groq api key')) {
      return 'Falta la clave de Groq. Ejecuta con --dart-define=GROQ_API_KEY=TU_CLAVE.';
    }

    if (normalized.contains('401') || normalized.contains('invalid api key')) {
      return 'La clave de Groq no es válida o fue revocada. Genera una nueva clave e inténtalo de nuevo.';
    }

    if (normalized.contains('413') || normalized.contains('request too large')) {
      return 'El mensaje fue demasiado largo. Intenta con una pregunta más corta o inicia un nuevo chat para limpiar el contexto.';
    }

    if (normalized.contains('429') ||
        normalized.contains('rate limit') ||
        normalized.contains('quota') ||
        normalized.contains('rate_limit_exceeded')) {
      return 'Se alcanzó el límite gratuito temporal de solicitudes. Espera un minuto e inténtalo nuevamente.';
    }

    if (normalized.contains('timeout') || normalized.contains('timed out')) {
      return 'La respuesta tardó demasiado. Verifica tu conexión a internet e inténtalo de nuevo.';
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

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Midi no reemplaza la opinión médica profesional. Ante cualquier duda de salud, consulta a tu médico.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryTextColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'Puedes preguntarme sobre:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickActionCard(
              title: 'Mis medicamentos',
              subtitle: 'Info, dosis y horarios',
              icon: Icons.medication_rounded,
              color: const Color(0xFF2F6DB4),
              onTap: () => _sendSuggestion('Háblame de mis medicamentos activos'),
            ),
            _buildQuickActionCard(
              title: 'Recordatorios',
              subtitle: 'Alarmas y notificaciones',
              icon: Icons.notifications_active_rounded,
              color: Colors.green,
              onTap: () => _sendSuggestion('¿Cuáles son mis próximos recordatorios para hoy?'),
            ),
          ],
        ),
        Row(
          children: [
            _buildQuickActionCard(
              title: 'Mi progreso',
              subtitle: 'Adherencia y estadísticas',
              icon: Icons.bar_chart_rounded,
              color: Colors.purple,
              onTap: () => _sendSuggestion('Muéstrame mi reporte de progreso y estadísticas de adherencia'),
            ),
            _buildQuickActionCard(
              title: 'Dudas frecuentes',
              subtitle: 'Resuelve tus preguntas',
              icon: Icons.help_outline_rounded,
              color: Colors.orange,
              onTap: () => _sendSuggestion('¿Cuáles son las dudas frecuentes sobre el uso de la aplicación?'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDisclaimerCard(),
      ],
    );
  }

  Widget _buildComposer() {
    final isEnabled = (_hasText || _isGenerating == false) && !_isGenerating;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording indicator
          if (_isRecording)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.3, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    builder: (context, value, child) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(value),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Grabando... Toca el mic para enviar',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: _cancelVoiceRecording,
                    tooltip: 'Cancelar grabación',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(_composerRadius),
                      border: Border.all(color: _isRecording ? Colors.red.withOpacity(0.4) : AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_composerRadius),
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_isRecording,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: AppTheme.primaryTextColor),
                        decoration: InputDecoration(
                          hintText: _isRecording ? 'Escuchando...' : 'Pregunta lo que necesitas...',
                          hintStyle: TextStyle(
                            color: _isRecording ? Colors.red.withOpacity(0.6) : AppTheme.secondaryTextColor.withOpacity(0.6),
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: InkWell(
                              onTap: _isGenerating || _isRecording ? null : _scanPrescription,
                              child: const ShaderMask(
                                shaderCallback: _sparklesGradientShader,
                                child: Icon(
                                  Icons.auto_awesome_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: (!isEnabled || !_hasText)
                      ? // Mic button
                        GestureDetector(
                          key: const ValueKey('mic_button'),
                          onTap: _isGenerating
                              ? null
                              : (_isRecording ? _stopVoiceRecordingAndSend : _startVoiceRecording),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? Colors.red
                                  : AppTheme.primaryColor.withOpacity(0.08),
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: _isRecording ? Colors.white : AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                        )
                      : // Send button
                        GestureDetector(
                          key: const ValueKey('send_button'),
                          onTap: _sendMessage,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: _chatGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHistoryDrawer(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: _chatGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Historial de Chats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: AppTheme.primaryColor),
            title: const Text(
              'Nuevo Chat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            onTap: () {
              _startNewChat();
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
          Expanded(
            child: user == null
                ? const Center(child: Text('Inicia sesión para ver tu historial.'))
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatSessionsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay chats anteriores.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final title = data['title'] as String? ?? 'Sin título';
                          final messages = data['messages'] as List<dynamic>? ?? [];
                          final isSelected = _currentChatId == doc.id;

                          return ListTile(
                            leading: Icon(
                              Icons.chat_rounded,
                              color: isSelected ? AppTheme.primaryColor : Colors.grey,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar chat'),
                                    content: const Text('¿Estás seguro de que quieres eliminar esta conversación?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await firestoreService.deleteChatSession(user.uid, doc.id);
                                  if (_currentChatId == doc.id) {
                                    _startNewChat();
                                  }
                                }
                              },
                            ),
                            onTap: () {
                              _loadChatSession(doc.id, title, messages);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmRecipe(
    String name,
    String pres,
    int interval,
    int dosis,
    int duration,
    String notas,
    Map<String, dynamic> prescriptionData,
  ) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Guardando tratamiento en MediTime...')),
          ],
        ),
      ),
    );

    try {
      final treatmentService = TreatmentService(context.read<FirestoreService>());
      await treatmentService.saveTreatment(
        userId: user.uid,
        formData: TreatmentFormData(
          nombreMedicamento: name,
          presentacion: pres,
          cantidadActual: 100,
          cantidadTotalCaja: 100,
          dosisPorToma: dosis,
          horaPrimeraDosis: TimeOfDay.now(),
          intervaloDosis: interval,
          duracionNumero: duration,
          duracionUnidad: DurationUnit.days,
          esIndefinido: false,
          notas: notas,
        ),
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        setState(() {
          prescriptionData['isSaved'] = true;
          _messages.add(_ChatMessage(
            text: '¡Tratamiento de **$name** agregado con éxito a tu cuenta de MediTime! Las alarmas y notificaciones han sido configuradas.',
            isUser: false,
          ));
        });
        _scrollToBottom();
        _saveChatToFirestore();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: _buildHistoryDrawer(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
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
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isFirstGreeting = index == 0 && _messages.length == 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChatBubble(
                      message: message,
                      onEdit: message.isUser ? () => _editMessageDialog(index, message.text) : null,
                      onConfirmRecipe: (name, pres, interval, dosis, duration, notas, pData) {
                        _handleConfirmRecipe(name, pres, interval, dosis, duration, notas, pData);
                      },
                    ),
                    if (isFirstGreeting) _buildInitialOptions(),
                  ],
                );
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final void Function(
    String name,
    String pres,
    int interval,
    int dosis,
    int duration,
    String notas,
    Map<String, dynamic> prescriptionData,
  )? onConfirmRecipe;

  final void Function()? onEdit;

  const _ChatBubble({
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
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isUser ? null : Theme.of(context).cardColor,
          border: isUser ? null : Border.all(color: AppTheme.borderColor),
          gradient: isUser
              ? const LinearGradient(
                  colors: _ChatBotScreenState._chatGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: isUser
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
              color: Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: message.isStreaming && message.text.isEmpty
            ? const _AnimatedTypingDots()
            : RichText(
                text: TextSpan(
                  children: _buildTextSpans(message.text, textColor),
                ),
              ),
      ),
    );

    if (isUser && onEdit != null) {
      bubble = GestureDetector(
        onLongPress: onEdit,
        child: bubble,
      );
    }

    if (message.prescriptionData != null || message.showAdherenceChart) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text.isNotEmpty) bubble,
          if (message.prescriptionData != null && onConfirmRecipe != null)
            _PrescriptionFormCard(
              prescriptionData: message.prescriptionData!,
              onSaved: (name, pres, interval, dosis, duration, notas) {
                onConfirmRecipe!(name, pres, interval, dosis, duration, notas, message.prescriptionData!);
              },
            ),
          if (message.showAdherenceChart)
            const _AdherenceChartCard(),
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
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: baseColor, fontSize: 15, height: 1.35),
        ));
      }

      final boldText = match.group(1) ?? '';
      final isMediTime = boldText.toLowerCase().contains('meditime');

      spans.add(TextSpan(
        text: boldText,
        style: TextStyle(
          color: isMediTime ? AppTheme.primaryColor : baseColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
          height: 1.35,
        ),
      ));

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: baseColor, fontSize: 15, height: 1.35),
      ));
    }

    return spans;
  }
}

class _AdherenceChartCard extends StatelessWidget {
  const _AdherenceChartCard();

  /// Calculates statistics for a treatment using the same logic as reportes_page.dart
  Map<String, int> _calcularEstadisticas(Tratamiento tratamiento) {
    int tomadas = 0;
    int omitidas = 0;
    int notificadas = 0;
    int programadasPasadas = 0;

    final now = DateTime.now();
    final todasLasDosis = TratamientoService().generarDosisTotales(tratamiento);

    final Map<int, DoseStatus> statusMap = {};
    tratamiento.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null) {
        statusMap[parsedTime.millisecondsSinceEpoch] = status;
      }
    });

    for (var doseTime in todasLasDosis) {
      if (doseTime.isBefore(now)) {
        programadasPasadas++;
        final status = statusMap[doseTime.millisecondsSinceEpoch];
        if (status == null) {
          omitidas++;
        } else {
          switch (status) {
            case DoseStatus.tomada:
              tomadas++;
              break;
            case DoseStatus.omitida:
              omitidas++;
              break;
            case DoseStatus.notificada:
              notificadas++;
              break;
            case DoseStatus.aplazada:
            case DoseStatus.pendiente:
              omitidas++;
              break;
          }
        }
      }
    }

    return {
      'tomadas': tomadas,
      'omitidas': omitidas,
      'notificadas': notificadas,
      'programadasPasadas': programadasPasadas,
    };
  }

  /// Gets recent dose history entries
  List<Map<String, dynamic>> _getRecentHistory(List<Tratamiento> tratamientos) {
    final List<Map<String, dynamic>> history = [];
    final now = DateTime.now();
    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.tryParse(dateString);
        if (doseTime != null &&
            doseTime.isBefore(now) &&
            (status == DoseStatus.tomada || status == DoseStatus.omitida || status == DoseStatus.notificada)) {
          history.add({
            'treatment': t,
            'time': doseTime,
            'status': status,
          });
        }
      });
    }
    history.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
    return history.take(4).toList();
  }

  /// Analyzes omission patterns by time of day
  Map<String, String> _analyzeOmissionsPattern(List<Tratamiento> tratamientos) {
    int morningOmissions = 0;
    int afternoonOmissions = 0;
    int nightOmissions = 0;
    int earlyOmissions = 0;

    final now = DateTime.now();
    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(dateString);
          if (doseTime != null && doseTime.isBefore(now)) {
            final hour = doseTime.hour;
            if (hour >= 6 && hour < 12) {
              morningOmissions++;
            } else if (hour >= 12 && hour < 18) {
              afternoonOmissions++;
            } else if (hour >= 18 && hour < 24) {
              nightOmissions++;
            } else {
              earlyOmissions++;
            }
          }
        }
      });
    }

    final maxVal = [morningOmissions, afternoonOmissions, nightOmissions, earlyOmissions]
        .reduce((a, b) => a > b ? a : b);

    if (maxVal == 0) {
      return {
        'icon': '🎉',
        'title': '¡Gran constancia!',
        'subtitle': 'No presentas omisiones registradas.',
      };
    }

    if (maxVal == morningOmissions) {
      return {
        'icon': '🌅',
        'title': 'Mayor omisión: Mañana',
        'subtitle': 'Tip: Deja tu pastillero cerca del desayuno.',
      };
    } else if (maxVal == afternoonOmissions) {
      return {
        'icon': '☀️',
        'title': 'Mayor omisión: Tarde',
        'subtitle': 'Tip: Activa recordatorios extra en ese horario.',
      };
    } else if (maxVal == nightOmissions) {
      return {
        'icon': '🌙',
        'title': 'Mayor omisión: Noche',
        'subtitle': 'Tip: Alarma 15 min antes de dormir.',
      };
    } else {
      return {
        'icon': '🌃',
        'title': 'Mayor omisión: Madrugada',
        'subtitle': 'Tip: Ajusta horarios para no interrumpir el sueño.',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Text('Inicia sesión para ver tu progreso.'),
      );
    }

    return StreamBuilder<List<Tratamiento>>(
      stream: firestoreService.getMedicamentosStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Text(
              'Aún no tienes medicamentos registrados para calcular tu progreso de adherencia.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }

        final tratamientos = snapshot.data!;

        // Calculate global stats
        int totalTomadas = 0;
        int totalOmitidas = 0;
        int totalNotificadas = 0;
        int totalProgramadas = 0;

        final List<Map<String, dynamic>> perTreatmentStats = [];

        for (var t in tratamientos) {
          final stats = _calcularEstadisticas(t);
          totalTomadas += stats['tomadas']!;
          totalOmitidas += stats['omitidas']!;
          totalNotificadas += stats['notificadas']!;
          totalProgramadas += stats['programadasPasadas']!;
          perTreatmentStats.add({
            'treatment': t,
            'stats': stats,
          });
        }

        final double overallAdherence = totalProgramadas > 0
            ? (totalTomadas / totalProgramadas) * 100
            : 0.0;

        final recentHistory = _getRecentHistory(tratamientos);
        final omissionsInfo = _analyzeOmissionsPattern(tratamientos);

        final bool isGoodAdherence = overallAdherence >= 80;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. HEADER: Overall Adherence ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.insights_rounded, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Reporte de Adherencia',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGoodAdherence
                            ? AppTheme.successColor.withValues(alpha: 0.12)
                            : AppTheme.errorColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isGoodAdherence ? '✓ Buena' : '⚠ Mejorable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isGoodAdherence ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── 2. CIRCULAR PROGRESS + LEGEND ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Circular progress
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: overallAdherence / 100,
                              strokeWidth: 8,
                              backgroundColor: AppTheme.borderColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                overallAdherence >= 80
                                    ? AppTheme.successColor
                                    : overallAdherence >= 50
                                        ? Colors.orange
                                        : AppTheme.errorColor,
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '${overallAdherence.toInt()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Legend
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(AppTheme.successColor, 'Tomadas', totalTomadas),
                          const SizedBox(height: 6),
                          _buildLegendItem(AppTheme.errorColor, 'Omitidas', totalOmitidas),
                          const SizedBox(height: 6),
                          _buildLegendItem(Colors.amber, 'Notificadas', totalNotificadas),
                          const SizedBox(height: 6),
                          _buildLegendItem(AppTheme.primaryColor, 'Programadas', totalProgramadas),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── 3. QUICK STATS ROW ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.check_circle_outline,
                      color: AppTheme.successColor,
                      value: totalTomadas.toString(),
                      label: 'Tomadas',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildStatChip(
                      icon: Icons.cancel_outlined,
                      color: AppTheme.errorColor,
                      value: totalOmitidas.toString(),
                      label: 'Omitidas',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildStatChip(
                      icon: Icons.notifications_outlined,
                      color: Colors.amber[700]!,
                      value: totalNotificadas.toString(),
                      label: 'Notificadas',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildStatChip(
                      icon: Icons.percent,
                      color: AppTheme.primaryColor,
                      value: '${overallAdherence.toInt()}%',
                      label: 'Total',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: AppTheme.borderColor, indent: 16, endIndent: 16),
              const SizedBox(height: 14),

              // ─── 4. PER-TREATMENT BREAKDOWN ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Desglose por tratamiento',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              ...perTreatmentStats.map((entry) {
                final t = entry['treatment'] as Tratamiento;
                final stats = entry['stats'] as Map<String, int>;
                final tomadas = stats['tomadas']!;
                final omitidas = stats['omitidas']!;
                final notificadas = stats['notificadas']!;
                final programadas = stats['programadasPasadas']!;
                final double adherence = programadas > 0 ? (tomadas / programadas) * 100 : 100.0;

                final Color color = adherence >= 80
                    ? AppTheme.successColor
                    : adherence >= 50
                        ? Colors.orange
                        : AppTheme.errorColor;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              t.nombreMedicamento,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${adherence.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Segmented bar: tomadas | omitidas | notificadas | remaining
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 8,
                          child: programadas > 0
                              ? Row(
                                  children: [
                                    if (tomadas > 0)
                                      Expanded(flex: tomadas, child: Container(color: AppTheme.successColor)),
                                    if (omitidas > 0)
                                      Expanded(flex: omitidas, child: Container(color: AppTheme.errorColor)),
                                    if (notificadas > 0)
                                      Expanded(flex: notificadas, child: Container(color: Colors.amber)),
                                    if (programadas - tomadas - omitidas - notificadas > 0)
                                      Expanded(
                                        flex: programadas - tomadas - omitidas - notificadas,
                                        child: Container(color: AppTheme.borderColor),
                                      ),
                                  ],
                                )
                              : Container(color: AppTheme.borderColor),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tomadas $tomadas · Omitidas $omitidas · Notif. $notificadas',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }),

              // ─── 5. RECENT HISTORY ───
              if (recentHistory.isNotEmpty) ...[
                Divider(height: 1, color: AppTheme.borderColor, indent: 16, endIndent: 16),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Historial reciente',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ...recentHistory.map((item) {
                  final date = item['time'] as DateTime;
                  final status = item['status'] as DoseStatus;
                  final t = item['treatment'] as Tratamiento;

                  Color statusColor;
                  IconData statusIcon;
                  String statusText;

                  switch (status) {
                    case DoseStatus.tomada:
                      statusColor = AppTheme.successColor;
                      statusIcon = Icons.check_circle_rounded;
                      statusText = 'Tomada';
                      break;
                    case DoseStatus.omitida:
                      statusColor = AppTheme.errorColor;
                      statusIcon = Icons.cancel_rounded;
                      statusText = 'Omitida';
                      break;
                    case DoseStatus.notificada:
                      statusColor = Colors.amber;
                      statusIcon = Icons.notifications_rounded;
                      statusText = 'Notificada';
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusIcon = Icons.hourglass_empty;
                      statusText = 'Pendiente';
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 14),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.nombreMedicamento,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                DateFormat('dd MMM, hh:mm a').format(date),
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // ─── 6. OMISSION PATTERN INSIGHT ───
              const SizedBox(height: 4),
              Divider(height: 1, color: AppTheme.borderColor, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primaryColor.withValues(alpha: 0.06)
                        : AppTheme.primaryColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(omissionsInfo['icon']!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              omissionsInfo['title']!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              omissionsInfo['subtitle']!,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── 7. SUGGESTION BANNER ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isGoodAdherence
                        ? (isDark ? const Color(0xFF0F2918) : const Color(0xFFF0FDF4))
                        : (isDark ? const Color(0xFF1E1A12) : const Color(0xFFFFFBEB)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGoodAdherence
                          ? (isDark ? const Color(0xFF1A4028) : const Color(0xFFBBF7D0))
                          : (isDark ? const Color(0xFF3E3018) : const Color(0xFFFDE68A)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGoodAdherence ? Icons.emoji_events_rounded : Icons.lightbulb_outline,
                        color: isGoodAdherence ? AppTheme.successColor : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isGoodAdherence
                              ? '¡Excelente trabajo! Mantén esta constancia con tus medicamentos.'
                              : 'Tu adherencia puede mejorar. Intenta activar recordatorios 15 min antes de cada dosis.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isGoodAdherence
                                ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))
                                : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, int value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 8, color: Colors.grey[500], fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionFormCard extends StatefulWidget {
  final Map<String, dynamic> prescriptionData;
  final void Function(String name, String pres, int interval, int dosis, int duration, String notas) onSaved;

  const _PrescriptionFormCard({
    required this.prescriptionData,
    required this.onSaved,
  });

  @override
  State<_PrescriptionFormCard> createState() => _PrescriptionFormCardState();
}

class _PrescriptionFormCardState extends State<_PrescriptionFormCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosisController;
  late final TextEditingController _intervaloController;
  late final TextEditingController _duracionController;
  late final TextEditingController _notasController;
  late String _selectedPresentacion;

  final List<String> _presentaciones = [
    'Comprimidos',
    'Grageas',
    'Cápsulas',
    'Sobres',
    'Jarabes',
    'Gotas',
    'Suspensiones',
    'Emulsiones',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.prescriptionData;
    _nameController = TextEditingController(text: data['nombreMedicamento']);
    _dosisController = TextEditingController(text: data['dosisPorToma']?.toString());
    _intervaloController = TextEditingController(text: data['intervaloDosis']?.toString());
    _duracionController = TextEditingController(text: data['duracion']?.toString());
    _notasController = TextEditingController(text: data['notas']);

    final rawPres = data['presentacion']?.toString() ?? 'Comprimidos';
    _selectedPresentacion = _normalizePresentacion(rawPres);
  }

  String _normalizePresentacion(String rawValue) {
    final clean = rawValue.trim().toLowerCase();
    if (clean.contains('comprimido') || clean.contains('pastilla') || clean.contains('tableta')) {
      return 'Comprimidos';
    } else if (clean.contains('gragea')) {
      return 'Grageas';
    } else if (clean.contains('cápsula') || clean.contains('capsula')) {
      return 'Cápsulas';
    } else if (clean.contains('sobre')) {
      return 'Sobres';
    } else if (clean.contains('jarabe')) {
      return 'Jarabes';
    } else if (clean.contains('gota')) {
      return 'Gotas';
    } else if (clean.contains('suspension') || clean.contains('suspensión')) {
      return 'Suspensiones';
    } else if (clean.contains('emulsion') || clean.contains('emulsión')) {
      return 'Emulsiones';
    }
    return 'Comprimidos';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosisController.dispose();
    _intervaloController.dispose();
    _duracionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = widget.prescriptionData['isSaved'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSaved ? Colors.green.withOpacity(0.4) : AppTheme.primaryColor.withOpacity(0.2),
          width: isSaved ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSaved ? Icons.check_circle : Icons.receipt_long_rounded,
                color: isSaved ? Colors.green : AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSaved ? 'Receta Guardada' : 'Datos Extraídos de la Receta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSaved ? Colors.green : AppTheme.primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Nombre del Medicamento',
            controller: _nameController,
            enabled: !isSaved,
          ),
          const SizedBox(height: 12),
          Text(
            'Presentación',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _selectedPresentacion,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(color: AppTheme.primaryTextColor, fontWeight: FontWeight.w600),
            items: _presentaciones.map((p) {
              return DropdownMenuItem<String>(
                value: p,
                child: Text(p),
              );
            }).toList(),
            onChanged: isSaved
                ? null
                : (val) {
                    if (val != null) {
                      setState(() => _selectedPresentacion = val);
                    }
                  },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  label: 'Dosis por toma',
                  controller: _dosisController,
                  keyboardType: TextInputType.number,
                  enabled: !isSaved,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  label: 'Intervalo (horas)',
                  controller: _intervaloController,
                  keyboardType: TextInputType.number,
                  enabled: !isSaved,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Duración (días)',
            controller: _duracionController,
            keyboardType: TextInputType.number,
            enabled: !isSaved,
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Notas adicionales',
            controller: _notasController,
            enabled: !isSaved,
          ),
          const SizedBox(height: 16),
          if (!isSaved)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final name = _nameController.text.trim();
                  final pres = _selectedPresentacion;
                  final interval = int.tryParse(_intervaloController.text) ?? 8;
                  final dosis = int.tryParse(_dosisController.text) ?? 1;
                  final duration = int.tryParse(_duracionController.text) ?? 7;
                  final notas = _notasController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre del medicamento es requerido.')),
                    );
                    return;
                  }

                  widget.onSaved(name, pres, interval, dosis, duration, notas);
                },
                child: const Text('Confirmar y Guardar'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.primaryTextColor : AppTheme.secondaryTextColor,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
      ],
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
    this.prescriptionData,
    this.showAdherenceChart = false,
  });

  final String text;
  final bool isUser;
  final bool isStreaming;
  final Map<String, dynamic>? prescriptionData;
  final bool showAdherenceChart;

  _ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isStreaming,
    Map<String, dynamic>? prescriptionData,
    bool? showAdherenceChart,
  }) {
    return _ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isStreaming: isStreaming ?? this.isStreaming,
      prescriptionData: prescriptionData ?? this.prescriptionData,
      showAdherenceChart: showAdherenceChart ?? this.showAdherenceChart,
    );
  }
}
