import 'dart:async';
import 'package:meditime/models/chat_message.dart';
import 'package:meditime/widgets/chat/chat_bubble.dart';
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
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/widgets/drug_interaction_dialog.dart';
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/core/subscription_guard.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/services/ai_quota_service.dart';
import 'package:meditime/screens/subscription/subscription_page.dart';

CaregiverProfile? _getActiveCaregiverProfile(BuildContext context) {
  try {
    final prefNotifier = context.read<PreferenceNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    return (caregiverNotifier.isCaregiverModeActive || isAnimal)
        ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal)
        : null;
  } catch (_) {
    return null;
  }
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  static const String routeName = '/chatbot';

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  static const List<Color> _chatGradient = <Color>[
    Color(0xFF004AC6),
    Color(0xFF2563EB),
  ];
  static const double _composerRadius = 30;
  static const String _midiOpenAsset = 'assets/chatbot/midi_open.png';
  static const String _midiBlinkAsset = 'assets/chatbot/midi_blink.png';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    _ChatMessage(
      text:
          '¡Hola! Soy Midi, tu asistente virtual de MediTime. Estoy aquí para ayudarte a organizar tus medicamentos, recordarte tus dosis o responder cualquier duda que tengas sobre la aplicación. ¿En qué te puedo ayudar hoy?',
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
  bool _isTranscribing = false;
  bool _wasLastInputVoice = false;
  Timer? _blinkTimer;
  VoiceService? _voiceService;
  String? _activeModeKey;

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

    final prefNotifier = Provider.of<PreferenceNotifier>(context, listen: false);
    final caregiverNotifier = Provider.of<CaregiverNotifier>(context, listen: false);
    final isAnimal = prefNotifier.isAnimalMode;
    final isCaregiver = caregiverNotifier.isCaregiverModeActive;
    final activeProfile = _getActiveProfile();

    final currentModeKey = isAnimal
        ? 'animal_${activeProfile?.id ?? "general"}'
        : (isCaregiver
            ? 'caregiver_${caregiverNotifier.modeType.name}_${activeProfile?.id ?? "general"}'
            : 'personal');

    final bool modeChanged = _activeModeKey != null && _activeModeKey != currentModeKey;
    if (modeChanged) {
      // Clear conversation and AI history when switching modes to prevent cross-mode leakage
      final geminiService = context.read<GeminiService>();
      geminiService.clearHistory();
      _currentChatId = null;
      _messages.clear();
      _messages.add(_ChatMessage(text: '', isUser: false));
    }
    _activeModeKey = currentModeKey;

    final l10n = AppLocalizations.of(context);
    if ((_messages.length == 1 && !_messages[0].isUser) || modeChanged) {
      String welcomeText;
      if (isAnimal) {
        if (activeProfile != null) {
          final petName = activeProfile.name.trim();
          final species = activeProfile.species?.trim().isNotEmpty == true ? ' (${activeProfile.species!.trim()})' : '';
          welcomeText = '¡Hola! Soy Midi, tu asistente veterinario de MediTime 🐾. Te ayudo a organizar los tratamientos de **$petName**$species, consultar cuándo finaliza cada medicación, recordar las dosis prescritas por su veterinario y prevenir intoxicaciones con alimentos o fármacos humanos peligrosos. ¿En qué te ayudo hoy?';
        } else {
          final petCount = caregiverNotifier.managedProfiles.where((p) => p.isAnimal).length;
          final petsStr = petCount > 0 ? ' ($petCount mascotas registradas)' : '';
          welcomeText = '¡Hola! Soy Midi, tu asistente veterinario en la **vista general** 🐾$petsStr. Te ayudo a supervisar los tratamientos de todas tus mascotas, saber cuándo termina el tratamiento de cada una y cuidar su salud sin confusiones. ¿Sobre qué mascota o dosis deseas consultar?';
        }
      } else if (isCaregiver) {
        if (activeProfile != null) {
          final patientName = activeProfile.name.trim();
          final room = activeProfile.roomNumber?.trim().isNotEmpty == true ? ' (Hab. ${activeProfile.roomNumber!.trim()})' : '';
          welcomeText = '¡Hola! Soy Midi, tu asistente de cuidado de MediTime 🩺. Estoy enfocado en los tratamientos y seguridad de **$patientName**$room. Te asisto verificando dosis según los 5 correctos, alertándote de alergias y consultando cuándo termina cada tratamiento. ¿En qué te colaboro hoy?';
        } else {
          final patientCount = caregiverNotifier.managedProfiles.where((p) => !p.isAnimal).length;
          final patientsStr = patientCount > 0 ? ' ($patientCount pacientes asignados)' : '';
          welcomeText = '¡Hola! Soy Midi, tu asistente de cuidado en la **vista general de pacientes** 🩺$patientsStr. Supervisas múltiples pacientes y te ayudo a organizar sus tomas, revisar qué dosis tocan hoy por paciente y saber cuándo finalizan sus tratamientos. ¿En qué te asisto hoy?';
        }
      } else {
        welcomeText = l10n?.chatBotWelcome ??
            '¡Hola! Soy Midi, tu asistente virtual de MediTime. Estoy aquí para ayudarte a organizar tus medicamentos, recordarte tus dosis, saber cuándo termina tu tratamiento o responder cualquier duda que tengas sobre tu salud. ¿En qué te puedo ayudar hoy?';
      }

      _messages[0] = _ChatMessage(
        text: welcomeText,
        isUser: false,
      );
    }

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
    final l10n = AppLocalizations.of(context);
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
              title: Text(l10n?.chatBotTakeRecipePhoto ?? 'Tomar Foto de la Receta'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n?.chatBotSelectFromGallery ?? 'Seleccionar de la Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;
    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(
        text: 'Analizando la foto de tu receta médica... 🔍 Un momento por favor.',
        isUser: false,
        isStreaming: true,
      ));
    });
    _scrollToBottom();

    final loadingMessageIndex = _messages.length - 1;

    try {
      final geminiService = context.read<GeminiService>();
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
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

  CaregiverProfile? _getActiveProfile() => _getActiveCaregiverProfile(context);

  CaregiverProfile? _resolveCaregiverProfile({String? name, String? id}) {
    try {
      final caregiverNotifier = context.read<CaregiverNotifier>();
      final prefNotifier = context.read<PreferenceNotifier>();
      final isAnimal = prefNotifier.isAnimalMode;
      final profiles = caregiverNotifier.managedProfiles;

      // 1. Direct ID match
      if (id != null && id.isNotEmpty && id != 'general') {
        final match = profiles.where((p) => p.id == id);
        if (match.isNotEmpty) return match.first;
      }

      // 2. Name match
      if (name != null && name.trim().isNotEmpty) {
        final cleanName = name.trim().toLowerCase();
        // Personal profile keywords
        if (cleanName == 'yo' ||
            cleanName == 'mi perfil' ||
            cleanName == 'personal' ||
            cleanName == 'mí' ||
            cleanName == 'mi' ||
            cleanName == 'propio') {
          return null;
        }

        final modeProfiles = profiles.where((p) => isAnimal ? p.isAnimal : !p.isAnimal).toList();
        final pool = modeProfiles.isNotEmpty ? modeProfiles : profiles;

        // Exact match
        final exact = pool.where((p) => p.name.trim().toLowerCase() == cleanName);
        if (exact.isNotEmpty) return exact.first;

        // Contains match
        final contains = pool.where((p) =>
            p.name.trim().toLowerCase().contains(cleanName) ||
            cleanName.contains(p.name.trim().toLowerCase()));
        if (contains.isNotEmpty) return contains.first;
      }

      // 3. Fallback to active selected profile
      final active = _getActiveProfile();
      if (active != null) return active;

      // 4. Default for Animal mode if single animal
      if (isAnimal) {
        final pets = profiles.where((p) => p.isAnimal).toList();
        if (pets.length == 1) return pets.first;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _sendMessage({bool fromVoice = false}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) {
      return;
    }

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null) {
      final quotaService = context.read<AiQuotaService>();
      final isPremium = context.read<SubscriptionNotifier>().isPremium;

      // 1. Anti-burst cooldown check
      if (await quotaService.isCoolingDown(user.uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, espera un momento antes de enviar otra consulta.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 2. Daily quota limit check
      final canSend = await quotaService.canSendMessage(user.uid, isPremium: isPremium);
      if (!canSend) {
        if (mounted) {
          _showQuotaExceededDialog(isPremium: isPremium);
        }
        return;
      }

      await quotaService.recordMessageSent(user.uid);
    }
    if (!mounted) return;

    _messageController.clear();
    FocusScope.of(context).unfocus();

    _wasLastInputVoice = fromVoice;
    final now = DateTime.now();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: now));
      _messages.add(
        _ChatMessage(text: '', isUser: false, isStreaming: true, timestamp: now),
      );
      _isGenerating = true;
    });
    _scrollToBottom();

    final geminiService = context.read<GeminiService>();
    final firestoreService = context.read<FirestoreService>();
    final prefNotifier = context.read<PreferenceNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final profileNotifier = context.read<ProfileNotifier>();
    final userName = profileNotifier.userName ?? user?.displayName;
    final lang = prefNotifier.languageCode;
    final effectiveLang = lang == 'system' ? Localizations.localeOf(context).languageCode : lang;
    final isAnimalMode = prefNotifier.isAnimalMode;
    final isCaregiverMode = caregiverNotifier.isCaregiverModeActive;
    final caregiverModeType = caregiverNotifier.modeType;
    final allProfiles = caregiverNotifier.managedProfiles;
    final activeProfile = _getActiveProfile();

    List<Tratamiento>? activeTreatments;
    if (user != null) {
      try {
        if (activeProfile != null) {
          // Vista individual (paciente o mascota específico)
          final txs = await firestoreService.getMedicamentos(user.uid, activeProfile);
          activeTreatments = txs.where((t) => t.isActivo || !t.isFinalizado).toList();
        } else if (isAnimalMode) {
          // Vista general de animales: Cargar tratamientos de todas las mascotas registradas
          final petProfiles = allProfiles.where((p) => p.isAnimal).toList();
          final List<Tratamiento> combined = [];
          for (final pet in petProfiles) {
            final txs = await firestoreService.getMedicamentos(user.uid, pet);
            combined.addAll(txs);
          }
          activeTreatments = combined.where((t) => t.isActivo || !t.isFinalizado).toList();
        } else if (isCaregiverMode) {
          // Vista general de cuidadores: Cargar tratamientos de todos los pacientes asignados
          final patientProfiles = allProfiles.where((p) => !p.isAnimal).toList();
          final List<Tratamiento> combined = [];
          for (final patient in patientProfiles) {
            final txs = await firestoreService.getMedicamentos(user.uid, patient);
            combined.addAll(txs);
          }
          activeTreatments = combined.where((t) => t.isActivo || !t.isFinalizado).toList();
        } else {
          // Modo Base / Personal
          final txs = await firestoreService.getMedicamentos(user.uid, null);
          activeTreatments = txs.where((t) => t.isActivo || !t.isFinalizado).toList();
        }
      } catch (e) {
        assert(() { debugPrint('Error al obtener medicamentos para Midi: $e'); return true; }());
      }
    }

    final botMessageIndex = _messages.length - 1;

    // Variables to collect tool-call actions for the UI
    Map<String, dynamic>? prescriptionData;
    bool showAdherenceChart = false;
    Map<String, dynamic>? adherenceChartData;
    final List<Map<String, dynamic>> updateDoseActions = [];

    try {
      await for (final partialText in geminiService.streamResponse(
        text,
        activeTreatments: activeTreatments,
        activeProfile: activeProfile,
        allProfiles: allProfiles,
        isAnimalMode: isAnimalMode,
        isCaregiverMode: isCaregiverMode,
        caregiverModeType: caregiverModeType,
        userName: userName,
        language: effectiveLang,
        onToolCalls: (toolCalls) {
          // Process UI-level tool calls from function calling
          for (final tc in toolCalls) {
            switch (tc.functionName) {
              case 'create_treatment':
                prescriptionData = Map<String, dynamic>.from(tc.arguments);
                prescriptionData!['isSaved'] = false;
                final resolved = _resolveCaregiverProfile(
                  name: prescriptionData!['targetProfileName']?.toString(),
                  id: prescriptionData!['targetProfileId']?.toString(),
                );
                if (resolved != null) {
                  prescriptionData!['targetProfileId'] = resolved.id;
                  prescriptionData!['targetProfileName'] = resolved.name;
                }
                break;
              case 'update_dose_status':
                updateDoseActions.add(tc.arguments);
                break;
              case 'show_adherence_chart':
                showAdherenceChart = true;
                adherenceChartData = Map<String, dynamic>.from(tc.arguments);
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

        // Automatic fallback: ensure the interactive adherence chart card is ALWAYS rendered
        // if user asked for a report/progress or if the assistant provided an adherence report
        if (!showAdherenceChart && _isAdherenceReportRequest(text, botMsg.text)) {
          showAdherenceChart = true;
          adherenceChartData ??= _extractAdherencePeriod(text, botMsg.text);
        }

        // If adherence chart is shown and text caught an error, replace with a clean intro
        String finalText = botMsg.text.trim();
        if (showAdherenceChart &&
            (finalText.contains('Bad state') ||
             finalText.contains('No fue posible generar una respuesta') ||
             finalText.isEmpty)) {
          final args = adherenceChartData ?? {};
          final p = args['periodo']?.toString() ?? 'solicitado';
          final pText = p == 'dia'
              ? 'del día de hoy'
              : (p == 'mes'
                  ? 'del mes en curso'
                  : (p == 'anio' ? 'del año en curso' : 'del período consultado'));
          finalText = 'Aquí tienes tu reporte de adherencia $pText con el progreso de tus tratamientos y dosis:';
        }

        setState(() {
          _messages[botMessageIndex] = botMsg.copyWith(
            text: finalText,
            isStreaming: false,
            prescriptionData: prescriptionData,
            showAdherenceChart: showAdherenceChart,
            adherenceChartData: adherenceChartData,
          );
          _isGenerating = false;
        });

        // Execute dose update actions from function calling
        for (final action in updateDoseActions) {
          final med = action['medicamento']?.toString() ?? '';
          final status = action['status']?.toString() ?? 'tomada';
          final mins = int.tryParse(action['minutosAplazo']?.toString() ?? '') ?? 30;
          final updateAll = action['updateAll'] == true || action['updateAll'] == 'true';
          final targetProfileName = action['targetProfileName']?.toString();
          _executeUpdateDose(med, status, mins, updateAll, targetProfileName: targetProfileName);
        }

        // TTS: speak response if message came from voice input
        if (fromVoice && botMsg.text.isNotEmpty) {
          _voiceService ??= VoiceService();
          final lang = context.read<PreferenceNotifier>().languageCode;
          final effectiveLang = lang == 'system' ? Localizations.localeOf(context).languageCode : lang;
          _voiceService!.updateLanguage(effectiveLang);
          _voiceService!.speak(botMsg.text);
        }

        _scrollToBottom();
      }
      await _saveChatToFirestore();
    }
  }

  bool _isAdherenceReportRequest(String userText, String assistantText) {
    final u = userText.toLowerCase();
    final a = assistantText.toLowerCase();

    final userAskedReport = u.contains('reporte') ||
        u.contains('adherencia') ||
        u.contains('progreso') ||
        u.contains('estadistica') ||
        u.contains('estadística') ||
        u.contains('cumplimiento') ||
        u.contains('cómo voy') ||
        u.contains('como voy');

    final assistantHasReport = a.contains('reporte de adherencia') ||
        a.contains('informe de adherencia') ||
        (a.contains('cumplimiento global') && a.contains('dosis'));

    return userAskedReport || assistantHasReport;
  }

  Map<String, dynamic> _extractAdherencePeriod(String userText, String assistantText) {
    final combined = '$userText $assistantText'.toLowerCase();

    if (combined.contains('hoy') ||
        combined.contains('del día') ||
        combined.contains('del dia') ||
        combined.contains('de hoy') ||
        combined.contains('diario')) {
      return {'periodo': 'dia', 'dias': 1};
    }

    if (combined.contains('mes') ||
        combined.contains('mensual') ||
        combined.contains('30 días') ||
        combined.contains('30 dias')) {
      return {'periodo': 'mes', 'dias': 30};
    }

    if (combined.contains('año') ||
        combined.contains('ano') ||
        combined.contains('anual') ||
        combined.contains('365')) {
      return {'periodo': 'anio', 'dias': 365};
    }

    final regexDays = RegExp(r'(\d+)\s+d[ií]as');
    final match = regexDays.firstMatch(userText.toLowerCase());
    if (match != null) {
      final days = int.tryParse(match.group(1) ?? '');
      if (days != null && days > 0) {
        return {'periodo': 'personalizado', 'dias': days};
      }
    }

    return {'periodo': 'semana', 'dias': 7};
  }

  void _showQuotaExceededDialog({required bool isPremium}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Límite diario alcanzado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isPremium
              ? 'Has alcanzado el límite de seguridad de ${AiQuotaService.premiumDailyLimit} consultas diarias con Midi. Tu cuota se reiniciará automáticamente a las 00:00.'
              : 'Has completado tus ${AiQuotaService.freeDailyLimit} consultas diarias gratuitas con Midi. Tu cuota se renovará automáticamente a medianoche.\n\nPuedes actualizar a MediTime Premium para disfrutar de hasta ${AiQuotaService.premiumDailyLimit} consultas diarias y respuestas prioritarias.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Entendido'),
          ),
          if (!isPremium)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionPage(
                      sourceFeature: 'consultas ampliadas con el asistente de IA Midi',
                    ),
                  ),
                );
              },
              child: const Text('Ver Planes Premium'),
            ),
        ],
      ),
    );
  }

  void _showQuotaDetailsSheet(int remaining, bool isPremium) {
    final limit = isPremium ? AiQuotaService.premiumDailyLimit : AiQuotaService.freeDailyLimit;
    final used = limit - remaining;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isPremium ? Colors.purple : AppTheme.primaryColor).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPremium ? Icons.auto_awesome_rounded : Icons.chat_bubble_outline_rounded,
                      color: isPremium ? Colors.purple : AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'Midi • Plan Premium' : 'Midi • Plan Gratuito',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Cuota de uso inteligente de IA',
                          style: TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Consultas utilizadas hoy:', style: TextStyle(fontSize: 14)),
                        Text('$used / $limit', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0,
                        minHeight: 8,
                        backgroundColor: AppTheme.borderColor.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          remaining <= 3 ? Colors.amber : (isPremium ? Colors.purple : AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$remaining consultas disponibles',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.secondaryTextColor),
                        ),
                        Text(
                          'Reinicia a las 00:00',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!isPremium)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Ampliar límite con Premium', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionPage(
                            sourceFeature: 'hasta 120 consultas diarias con el asistente Midi',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaActionWidget() {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    final quotaService = context.read<AiQuotaService>();
    final isPremium = context.watch<SubscriptionNotifier>().isPremium;

    return FutureBuilder<int>(
      future: quotaService.getRemainingMessages(user.uid, isPremium: isPremium),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? (isPremium ? AiQuotaService.premiumDailyLimit : AiQuotaService.freeDailyLimit);
        final isLow = remaining <= 3;

        return Tooltip(
          message: isPremium
              ? 'Plan Premium: $remaining consultas restantes hoy'
              : '$remaining consultas restantes hoy (se renuevan a medianoche)',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showQuotaDetailsSheet(remaining, isPremium),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLow
                    ? Colors.amber.withValues(alpha: 0.2)
                    : (isPremium
                        ? Colors.purple.withValues(alpha: 0.15)
                        : AppTheme.primaryColor.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLow
                      ? Colors.amber
                      : (isPremium
                          ? Colors.purple.withValues(alpha: 0.4)
                          : AppTheme.primaryColor.withValues(alpha: 0.3)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPremium ? Icons.auto_awesome_rounded : Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: isLow
                        ? Colors.amber.shade800
                        : (isPremium ? Colors.purple : AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPremium ? 'PRO • $remaining' : '$remaining/${AiQuotaService.freeDailyLimit}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLow
                          ? Colors.amber.shade900
                          : (isPremium ? Colors.purple.shade700 : AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeContextBanner() {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final isCaregiver = caregiverNotifier.isCaregiverModeActive;

    if (!isAnimal && !isCaregiver) {
      return const SizedBox.shrink();
    }

    final activeProfile = _getActiveProfile();

    if (isAnimal) {
      if (activeProfile != null) {
        final petName = activeProfile.name.trim();
        final species = activeProfile.species?.trim().isNotEmpty == true ? activeProfile.species!.trim() : 'Mascota';
        final weight = activeProfile.weight?.trim().isNotEmpty == true ? ' • ${activeProfile.weight!.trim()}' : '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            border: Border(
              bottom: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.pets_rounded, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo Mascotas • Asistiendo a $petName ($species$weight)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      } else {
        final petCount = caregiverNotifier.managedProfiles.where((p) => p.isAnimal).length;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            border: Border(
              bottom: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.pets_rounded, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo Mascotas • Vista General ($petCount mascotas registradas)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico;
      final modeTitle = isClinico ? "Modo Clínico" : "Modo Cuidador";

      if (activeProfile != null) {
        final patientName = activeProfile.name.trim();
        final extra = activeProfile.relationship.trim().isNotEmpty == true
            ? ' • ${activeProfile.relationship.trim()}'
            : (activeProfile.roomNumber != null ? ' • Hab. ${activeProfile.roomNumber}' : '');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.10),
            border: Border(
              bottom: BorderSide(color: Colors.indigo.withValues(alpha: 0.25)),
            ),
          ),
          child: Row(
            children: [
              Icon(isClinico ? Icons.medical_services_rounded : Icons.family_restroom_rounded, size: 18, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$modeTitle • Paciente: $patientName$extra',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      } else {
        final patientCount = caregiverNotifier.managedProfiles.where((p) => !p.isAnimal).length;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.10),
            border: Border(
              bottom: BorderSide(color: Colors.indigo.withValues(alpha: 0.25)),
            ),
          ),
          child: Row(
            children: [
              Icon(isClinico ? Icons.medical_services_rounded : Icons.family_restroom_rounded, size: 18, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$modeTitle • Vista General ($patientCount pacientes a cargo)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
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
    
    final canProceed = await SubscriptionGuard.canUseVoiceAssistant(context);
    if (!canProceed || !mounted) return;

    if (_voiceService == null) {
      _voiceService = VoiceService();
      final lang = context.read<PreferenceNotifier>().languageCode;
      final effectiveLang = lang == 'system' ? Localizations.localeOf(context).languageCode : lang;
      _voiceService!.updateLanguage(effectiveLang);
      _voiceService!.onTtsComplete = () {
        if (!mounted || _isRecording || _isTranscribing || _isGenerating || !_wasLastInputVoice || _messages.isEmpty) return;
        final lastMsg = _messages.last.text.trim();
        if (lastMsg.endsWith('?') || lastMsg.endsWith(':')) {
          _startVoiceRecording();
        }
      };
    } else {
      final lang = context.read<PreferenceNotifier>().languageCode;
      final effectiveLang = lang == 'system' ? Localizations.localeOf(context).languageCode : lang;
      _voiceService!.updateLanguage(effectiveLang);
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
            backgroundColor: AppTheme.errorColor,
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

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

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
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  Future<void> _executeUpdateDose(
    String medName,
    String statusStr,
    int minutes,
    bool updateAll, {
    String? targetProfileName,
  }) async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null || medName.isEmpty) return;

    try {
      CaregiverProfile? targetProfile;
      if (targetProfileName != null && targetProfileName.isNotEmpty) {
        targetProfile = _resolveCaregiverProfile(name: targetProfileName);
      }
      targetProfile ??= _getActiveProfile();

      List<Tratamiento> treatments = [];

      // If profile is still null, but in Caregiver or Animal mode in Vista General,
      // search across managed profiles to find the one holding this medication
      if (targetProfile == null) {
        final prefNotifier = context.read<PreferenceNotifier>();
        final caregiverNotifier = context.read<CaregiverNotifier>();
        final isAnimal = prefNotifier.isAnimalMode;
        final isCaregiver = caregiverNotifier.isCaregiverModeActive;

        if (isCaregiver || isAnimal) {
          final candidates = caregiverNotifier.managedProfiles
              .where((p) => isAnimal ? p.isAnimal : !p.isAnimal)
              .toList();

          for (final candidate in candidates) {
            final txs = await firestoreService.getMedicamentos(user.uid, candidate);
            final match = txs.any((t) =>
                (t.isActivo || !t.isFinalizado) &&
                t.nombreMedicamento.toLowerCase().contains(medName.toLowerCase()));
            if (match) {
              targetProfile = candidate;
              treatments = txs;
              break;
            }
          }
        }
      }

      if (treatments.isEmpty) {
        treatments = await firestoreService.getMedicamentosStream(user.uid, targetProfile).first;
      }
      // Filter out finished treatments from medical history
      final runningTreatments = treatments.where((t) => t.isActivo || !t.isFinalizado).toList();

      final DoseStatus status = DoseStatus.fromString(statusStr);
      final profileLabel = targetProfile != null ? ' para **${targetProfile.name}**' : '';

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
                targetProfile,
              );
            }
            updatedCount++;
          }
        }

        setState(() {
          _messages.add(_ChatMessage(
            text: updatedCount > 0
                ? '¡Se actualizaron **$updatedCount** dosis de tus medicamentos activos$profileLabel a **${status.displayName}** con éxito!'
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
                text: 'No encontré ninguna dosis pendiente o programada cercana para **${treatment.nombreMedicamento}**$profileLabel.',
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
                targetProfile,
              );
            }
            updatedCount++;
          }

          setState(() {
            _messages.add(_ChatMessage(
              text: '¡Se actualizaron **$updatedCount** dosis de **${treatment.nombreMedicamento}**$profileLabel a **${status.displayName}** con éxito!',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        } else {
          final doseTime = _findClosestDose(treatment);
          if (doseTime == null) {
            setState(() {
              _messages.add(_ChatMessage(
                text: 'No encontré ninguna dosis pendiente o programada cercana para **${treatment.nombreMedicamento}**$profileLabel.',
                isUser: false,
                timestamp: DateTime.now(),
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
                text: '¡Dosis de **${treatment.nombreMedicamento}**$profileLabel aplazada por **$minutes minutos** con éxito!',
                isUser: false,
              ));
            });
          } else {
            final inventoryResult = await firestoreService.updateDoseStatus(
              user.uid,
              treatment.id,
              doseTime,
              status,
              targetProfile,
            );

            String successMsg = '¡Dosis de **${treatment.nombreMedicamento}**$profileLabel marcada como **${status.displayName}** con éxito!';
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
              'timestamp': m.timestamp.toIso8601String(),
              if (m.prescriptionData != null) 'prescriptionData': m.prescriptionData,
              if (m.showAdherenceChart) 'showAdherenceChart': true,
              if (m.adherenceChartData != null) 'adherenceChartData': m.adherenceChartData,
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
      assert(() { debugPrint("Error saving chat session: $e"); return true; }());
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
          final rawTime = m['timestamp'] as String?;
          final parsedTime = rawTime != null ? DateTime.tryParse(rawTime) : null;
          _messages.add(_ChatMessage(
            text: m['text'] as String? ?? '',
            isUser: m['isUser'] as bool? ?? false,
            timestamp: parsedTime,
            prescriptionData: m['prescriptionData'] != null
                ? Map<String, dynamic>.from(m['prescriptionData'] as Map)
                : null,
            showAdherenceChart: m['showAdherenceChart'] as bool? ?? false,
            adherenceChartData: m['adherenceChartData'] != null
                ? Map<String, dynamic>.from(m['adherenceChartData'] as Map)
                : null,
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
        _ChatMessage(
          text: AppLocalizations.of(context)?.chatBotWelcome ??
              '¡Hola! Soy Midi, tu asistente virtual de MediTime. Estoy aquí para ayudarte a organizar tus medicamentos, recordarte tus dosis o responder cualquier duda que tengas sobre la aplicación. ¿En qué te puedo ayudar hoy?',
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

    if (normalized.contains('falta la clave') ||
        normalized.contains('missing groq api key')) {
      return 'Falta configurar la clave de Groq API (--dart-define=GROQ_API_KEY=tu_clave).';
    }

    if (normalized.contains('401') ||
        normalized.contains('invalid api key') ||
        normalized.contains('autenticación') ||
        normalized.contains('invalid_api_key')) {
      return 'La clave de Groq no es válida o expiró (Error 401). Verifica tu clave en console.groq.com.';
    }

    if (normalized.contains('413') || normalized.contains('request too large') || normalized.contains('extenso')) {
      return 'El mensaje fue demasiado extenso (Error 413). Intenta con una pregunta más corta o inicia una nueva conversación para limpiar el contexto.';
    }

    if (normalized.contains('429') ||
        normalized.contains('rate limit') ||
        normalized.contains('quota') ||
        normalized.contains('rate_limit_exceeded')) {
      return 'Se alcanzó el límite gratuito temporal de Groq (Error 429). Espera un minuto e inténtalo nuevamente.';
    }

    if (normalized.contains('404') ||
        normalized.contains('model_not_found') ||
        normalized.contains('does not exist')) {
      return 'El modelo de IA solicitado no está disponible temporalmente en tu cuenta de Groq (Error 404).';
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
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
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
    final l10n = AppLocalizations.of(context);
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final isCaregiver = caregiverNotifier.isCaregiverModeActive;

    String disclaimerText;
    IconData icon = Icons.shield_outlined;
    Color color = AppTheme.primaryColor;

    if (isAnimal) {
      disclaimerText = 'Midi no reemplaza la consulta con un médico veterinario colegiado. Ante sospecha de intoxicación por fármacos humanos o emergencias, acude de inmediato a una clínica veterinaria.';
      icon = Icons.pets_outlined;
      color = Colors.green;
    } else if (isCaregiver) {
      disclaimerText = 'Midi es un asistente de apoyo al cuidado. La administración de medicamentos debe ser verificada según las prescripciones médicas y la regla de los 5 correctos.';
      icon = Icons.medical_services_outlined;
      color = Colors.indigo;
    } else {
      disclaimerText = l10n?.chatBotMedicalDisclaimer ??
          'Midi no reemplaza la opinión médica profesional. Ante cualquier duda de salud, consulta a tu médico.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimerText,
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
    final l10n = AppLocalizations.of(context);
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final isCaregiver = caregiverNotifier.isCaregiverModeActive;
    final activeProfile = _getActiveProfile();

    List<Widget> optionRows;

    if (isAnimal) {
      if (activeProfile != null) {
        final petName = activeProfile.name.trim();
        optionRows = [
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Plan de $petName',
                subtitle: 'Dosis y horarios',
                icon: Icons.medication_rounded,
                color: const Color(0xFF2F6DB4),
                onTap: () => _sendSuggestion('¿Cuáles son los tratamientos activos de $petName?'),
              ),
              _buildQuickActionCard(
                title: '¿Cuándo termina?',
                subtitle: 'Días restantes y fin',
                icon: Icons.event_available_rounded,
                color: Colors.teal,
                onTap: () => _sendSuggestion('¿Cuándo va a terminar el tratamiento de $petName y cuántos días faltan?'),
              ),
            ],
          ),
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Dosis por peso',
                subtitle: 'Cálculo para $petName',
                icon: Icons.pets_rounded,
                color: Colors.green,
                onTap: () => _sendSuggestion('¿Cómo se calculan las dosis por peso para $petName y por qué es peligroso asumir dosis humanas?'),
              ),
              _buildQuickActionCard(
                title: 'Fármacos tóxicos',
                subtitle: 'Peligros para mascotas',
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
                onTap: () => _sendSuggestion('¿Qué medicamentos humanos comunes son tóxicos o mortales para perros y gatos?'),
              ),
            ],
          ),
        ];
      } else {
        optionRows = [
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Tratamientos',
                subtitle: 'Ver todas las mascotas',
                icon: Icons.medication_rounded,
                color: const Color(0xFF2F6DB4),
                onTap: () => _sendSuggestion('¿Cuáles son los tratamientos activos de cada una de mis mascotas?'),
              ),
              _buildQuickActionCard(
                title: '¿Cuándo terminan?',
                subtitle: 'Fin por mascota',
                icon: Icons.event_available_rounded,
                color: Colors.teal,
                onTap: () => _sendSuggestion('¿Cuándo finaliza el tratamiento de cada una de mis mascotas y cuántos días le quedan a cada una?'),
              ),
            ],
          ),
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Fármacos tóxicos',
                subtitle: 'Peligros mortales',
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
                onTap: () => _sendSuggestion('¿Qué medicamentos humanos comunes son tóxicos o mortales para perros y gatos?'),
              ),
              _buildQuickActionCard(
                title: 'Alimentos prohibidos',
                subtitle: 'Comidas y plantas tóxicas',
                icon: Icons.no_food_rounded,
                color: Colors.orange,
                onTap: () => _sendSuggestion('¿Qué alimentos y plantas habituales en el hogar son tóxicos para perros y gatos?'),
              ),
            ],
          ),
        ];
      }
    } else if (isCaregiver) {
      if (activeProfile != null) {
        final patientName = activeProfile.name.trim();
        optionRows = [
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Plan de $patientName',
                subtitle: 'Medicamentos y horarios',
                icon: Icons.medical_services_rounded,
                color: Colors.indigo,
                onTap: () => _sendSuggestion('¿Cuáles son los tratamientos y horarios programados para $patientName?'),
              ),
              _buildQuickActionCard(
                title: '¿Cuándo termina?',
                subtitle: 'Fechas y días restantes',
                icon: Icons.event_available_rounded,
                color: Colors.teal,
                onTap: () => _sendSuggestion('¿Cuándo finaliza el tratamiento de $patientName y cuántos días le faltan?'),
              ),
            ],
          ),
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Los 5 correctos',
                subtitle: 'Seguridad en administración',
                icon: Icons.verified_user_rounded,
                color: Colors.teal,
                onTap: () => _sendSuggestion('Recuérdame la regla de los 5 correctos para la administración segura de medicamentos a $patientName.'),
              ),
              _buildQuickActionCard(
                title: 'Alertas y cuidados',
                subtitle: 'Alergias y notas',
                icon: Icons.warning_amber_rounded,
                color: Colors.amber.shade800,
                onTap: () => _sendSuggestion('¿Qué precauciones y posibles alergias debo vigilar con los tratamientos de $patientName?'),
              ),
            ],
          ),
        ];
      } else {
        optionRows = [
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Dosis de pacientes',
                subtitle: 'Resumen de hoy',
                icon: Icons.medical_services_rounded,
                color: Colors.indigo,
                onTap: () => _sendSuggestion('¿Cuáles son las dosis programadas para hoy agrupadas por paciente?'),
              ),
              _buildQuickActionCard(
                title: '¿Cuándo terminan?',
                subtitle: 'Fin de tratamiento por paciente',
                icon: Icons.event_available_rounded,
                color: Colors.teal,
                onTap: () => _sendSuggestion('¿Cuándo termina el tratamiento de cada paciente y cuántos días restan para cada uno?'),
              ),
            ],
          ),
          Row(
            children: [
              _buildQuickActionCard(
                title: 'Los 5 correctos',
                subtitle: 'Seguridad clínica',
                icon: Icons.verified_user_rounded,
                color: Colors.teal,
                onTap: () => _sendSuggestion('Recuérdame la regla de los 5 correctos para la administración segura de medicamentos.'),
              ),
              _buildQuickActionCard(
                title: 'Registro de tomas',
                subtitle: 'Pendientes por paciente',
                icon: Icons.checklist_rounded,
                color: Colors.purple,
                onTap: () => _sendSuggestion('¿Qué dosis de hoy están marcadas como tomadas o pendientes según cada paciente?'),
              ),
            ],
          ),
        ];
      }
    } else {
      optionRows = [
        Row(
          children: [
            _buildQuickActionCard(
              title: l10n?.chatBotQuickMeds ?? 'Mis medicamentos',
              subtitle: l10n?.chatBotQuickMedsSubtitle ?? 'Info, dosis y horarios',
              icon: Icons.medication_rounded,
              color: const Color(0xFF2F6DB4),
              onTap: () => _sendSuggestion('Háblame de mis medicamentos activos'),
            ),
            _buildQuickActionCard(
              title: '¿Cuándo termina?',
              subtitle: 'Fechas y días restantes',
              icon: Icons.event_available_rounded,
              color: Colors.teal,
              onTap: () => _sendSuggestion('¿Cuándo va a terminar mi tratamiento y cuántos días me faltan?'),
            ),
          ],
        ),
        Row(
          children: [
            _buildQuickActionCard(
              title: l10n?.chatBotQuickReminders ?? 'Recordatorios',
              subtitle: l10n?.chatBotQuickRemindersSubtitle ?? 'Alarmas y notificaciones',
              icon: Icons.notifications_active_rounded,
              color: Colors.green,
              onTap: () => _sendSuggestion('¿Cuáles son mis próximos recordatorios para hoy?'),
            ),
            _buildQuickActionCard(
              title: l10n?.chatBotQuickProgress ?? 'Mi progreso',
              subtitle: l10n?.chatBotQuickProgressSubtitle ?? 'Adherencia y estadísticas',
              icon: Icons.bar_chart_rounded,
              color: Colors.purple,
              onTap: () => _sendSuggestion('Muéstrame mi reporte de progreso y estadísticas de adherencia'),
            ),
          ],
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            l10n?.chatBotAskAbout ?? 'Puedes preguntarme sobre:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...optionRows,
        const SizedBox(height: 8),
        _buildDisclaimerCard(),
      ],
    );
  }

  Widget _buildComposer() {
    final l10n = AppLocalizations.of(context);
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
                color: AppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
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
                          color: AppTheme.errorColor.withValues(alpha: value),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n?.chatBotRecordingNotice ?? 'Grabando... Toca el mic para enviar',
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: AppTheme.errorColor),
                    onPressed: _cancelVoiceRecording,
                    tooltip: l10n?.chatBotCancelRecording ?? 'Cancelar grabación',
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
                      border: Border.all(color: _isRecording ? AppTheme.errorColor.withValues(alpha: 0.4) : AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
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
                          hintText: _isRecording
                              ? (l10n?.chatBotListening ?? 'Escuchando...')
                              : (l10n?.chatBotInputHint ?? 'Pregunta lo que necesitas...'),
                          hintStyle: TextStyle(
                            color: _isRecording ? AppTheme.errorColor.withValues(alpha: 0.6) : AppTheme.secondaryTextColor.withValues(alpha: 0.6),
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
                  child: _isTranscribing
                      ? Container(
                          key: const ValueKey('loading'),
                          width: 50,
                          height: 50,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        )
                      : (!isEnabled || !_hasText)
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
                                  ? AppTheme.errorColor
                                  : AppTheme.primaryColor.withValues(alpha: 0.08),
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
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
      backgroundColor: AppTheme.backgroundColor,
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
            leading: Icon(Icons.add, color: AppTheme.primaryColor),
            title: Text(
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

                      return ModernContentFade(
                        child: ListView.builder(
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
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
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
                      ),
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
    Map<String, dynamic> prescriptionData, {
    CaregiverProfile? targetProfile,
  }) async {
    final authService = context.read<AuthService>();
    final treatmentRepo = context.read<TreatmentRepository>();
    final geminiService = context.read<GeminiService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null) return;

    final canProceed = await SubscriptionGuard.canAddTreatment(context);
    if (!canProceed || !mounted) return;

    final CaregiverProfile? effectiveProfile = targetProfile ??
        _resolveCaregiverProfile(
          name: prescriptionData['targetProfileName']?.toString(),
          id: prescriptionData['targetProfileId']?.toString(),
        ) ??
        _getActiveProfile();

    // Verificar interacciones farmacológicas con IA
    try {
      final result = await treatmentRepo.getTreatments(user.uid);
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final profileTreatments = result.data!.where((t) {
          if (effectiveProfile == null) return t.profileId == null;
          return t.profileId == effectiveProfile.id;
        }).toList();

        if (profileTreatments.isNotEmpty) {
          final interactionResult = await geminiService.checkDrugInteractions(
            newDrugName: name,
            activeTreatments: profileTreatments,
          );
          if (interactionResult['hasInteraction'] == true && mounted) {
            final warningMessage = interactionResult['warningMessage'] as String? ??
                'Se ha detectado una posible interacción medicamentosa.';
            final proceed = await DrugInteractionDialog.show(
              context,
              warningMessage: warningMessage,
            );
            if (!proceed || !mounted) return;
          }
        }
      }
    } catch (e) {
      assert(() { debugPrint('Error comprobando interacciones en chat: $e'); return true; }());
    }

    if (!mounted) return;

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
      final treatmentService = TreatmentService(firestoreService);
      await treatmentService.saveTreatment(
        userId: user.uid,
        profile: effectiveProfile,
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

        final prefNotifier = context.read<PreferenceNotifier>();
        final caregiverNotifier = context.read<CaregiverNotifier>();
        final isAnimal = prefNotifier.isAnimalMode;
        final isCaregiver = caregiverNotifier.isCaregiverModeActive;

        String successMsg;
        if (isAnimal && effectiveProfile != null) {
          successMsg = '¡Tratamiento de **$name** asignado y registrado para **${effectiveProfile.name}** 🐾! Las alarmas y dosis han quedado programadas.';
        } else if (isCaregiver && effectiveProfile != null) {
          successMsg = '¡Tratamiento de **$name** asignado con éxito a **${effectiveProfile.name}** 🩺! Las alertas de administración están activas.';
        } else {
          successMsg = '¡Tratamiento de **$name** agregado con éxito a tu cuenta de MediTime! Las alarmas y notificaciones han sido configuradas.';
        }

        setState(() {
          prescriptionData['isSaved'] = true;
          if (effectiveProfile != null) {
            prescriptionData['targetProfileId'] = effectiveProfile.id;
            prescriptionData['targetProfileName'] = effectiveProfile.name;
          }
          _messages.add(_ChatMessage(
            text: successMsg,
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
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: _buildHistoryDrawer(context),
      appBar: ModernAppBar(
        child: AppBar(
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
            _buildQuotaActionWidget(),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Historial',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildModeContextBanner(),
          Expanded(
            child: ModernContentFade(
              enableTopFade: true,
              enableBottomFade: true,
              height: 24,
              bottomHeight: 24,
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
                        onConfirmRecipe: (name, pres, interval, dosis, duration, notas, pData, {targetProfile}) {
                          _handleConfirmRecipe(name, pres, interval, dosis, duration, notas, pData, targetProfile: targetProfile);
                        },
                      ),
                      if (isFirstGreeting) _buildInitialOptions(),
                    ],
                  );
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

// Typedefs para mantener compatibilidad interna tras modularización
typedef _ChatMessage = ChatMessage;
typedef _ChatBubble = ChatBubble;
