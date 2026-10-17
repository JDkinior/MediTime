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
import 'package:meditime/widgets/drug_interaction_dialog.dart';
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/core/subscription_guard.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/services/ai_quota_service.dart';
import 'package:meditime/screens/subscription/subscription_page.dart';
import 'package:meditime/screens/reports/reportes_page.dart';
import 'package:meditime/widgets/markdown_message_body.dart';

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
        debugPrint('Error al obtener medicamentos para Midi: $e');
      }
    }

    final botMessageIndex = _messages.length - 1;

    // Variables to collect tool-call actions for the UI
    Map<String, dynamic>? prescriptionData;
    bool showAdherenceChart = false;
    Map<String, dynamic>? adherenceChartData;
    final List<Map<String, dynamic>> updateDoseActions = [];

    try {
      final profileNotifier = context.read<ProfileNotifier>();
      final userName = profileNotifier.userName ?? user?.displayName;
      final lang = prefNotifier.languageCode;
      final effectiveLang = lang == 'system' ? Localizations.localeOf(context).languageCode : lang;

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
                color: Colors.amber.withOpacity(0.15),
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
                      color: (isPremium ? Colors.purple : AppTheme.primaryColor).withOpacity(0.12),
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
                        backgroundColor: AppTheme.borderColor.withOpacity(0.3),
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
                    ? Colors.amber.withOpacity(0.2)
                    : (isPremium
                        ? Colors.purple.withOpacity(0.15)
                        : AppTheme.primaryColor.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLow
                      ? Colors.amber
                      : (isPremium
                          ? Colors.purple.withOpacity(0.4)
                          : AppTheme.primaryColor.withOpacity(0.3)),
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
            color: Colors.green.withOpacity(0.12),
            border: Border(
              bottom: BorderSide(color: Colors.green.withOpacity(0.3)),
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
            color: Colors.green.withOpacity(0.12),
            border: Border(
              bottom: BorderSide(color: Colors.green.withOpacity(0.3)),
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
            color: Colors.indigo.withOpacity(0.10),
            border: Border(
              bottom: BorderSide(color: Colors.indigo.withOpacity(0.25)),
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
            color: Colors.indigo.withOpacity(0.10),
            border: Border(
              bottom: BorderSide(color: Colors.indigo.withOpacity(0.25)),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
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
                color: AppTheme.errorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
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
                          color: AppTheme.errorColor.withOpacity(value),
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
                      border: Border.all(color: _isRecording ? AppTheme.errorColor.withOpacity(0.4) : AppTheme.borderColor),
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
                          hintText: _isRecording
                              ? (l10n?.chatBotListening ?? 'Escuchando...')
                              : (l10n?.chatBotInputHint ?? 'Pregunta lo que necesitas...'),
                          hintStyle: TextStyle(
                            color: _isRecording ? AppTheme.errorColor.withOpacity(0.6) : AppTheme.secondaryTextColor.withOpacity(0.6),
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
                            color: AppTheme.primaryColor.withOpacity(0.08),
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
      debugPrint('Error comprobando interacciones en chat: $e');
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
    Map<String, dynamic> prescriptionData, {
    CaregiverProfile? targetProfile,
  })? onConfirmRecipe;

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
          maxWidth: isUser
              ? MediaQuery.of(context).size.width * 0.78
              : MediaQuery.of(context).size.width * 0.90,
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
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: message.isStreaming && message.text.isEmpty
            ? const _AnimatedTypingDots()
            : Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                      color: isUser ? Colors.white.withValues(alpha: 0.75) : AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
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
              onSaved: (name, pres, interval, dosis, duration, notas, [targetProfile]) {
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
            _AdherenceChartCard(arguments: message.adherenceChartData),
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
  final Map<String, dynamic>? arguments;

  const _AdherenceChartCard({this.arguments});

  ({DateTime startDate, DateTime endDate, String label, ReportInterval targetInterval}) _resolvePeriodConfig() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    ReportInterval targetInterval = ReportInterval.semana;

    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final args = arguments ?? {};
    final String? periodoType = args['periodo']?.toString().toLowerCase().trim();
    final dynamic diasRaw = args['dias'];
    final int? daysCount = diasRaw is int
        ? diasRaw
        : (diasRaw is String ? int.tryParse(diasRaw) : (diasRaw is num ? diasRaw.toInt() : null));
    final String? inicioStr = args['fechaInicio']?.toString().trim();
    final String? finStr = args['fechaFin']?.toString().trim();

    DateTime? customStart = inicioStr != null ? DateTime.tryParse(inicioStr) : null;
    DateTime? customEnd = finStr != null ? DateTime.tryParse(finStr) : null;

    if (customEnd != null) {
      endDate = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999);
    }

    String label;
    if (customStart != null) {
      startDate = DateTime(customStart.year, customStart.month, customStart.day);
      targetInterval = ReportInterval.todo;
      label = '${startDate.day} ${months[startDate.month - 1]} - ${endDate.day} ${months[endDate.month - 1]} ${endDate.year}';
    } else if (periodoType == 'dia' || periodoType == 'hoy' || daysCount == 1) {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      targetInterval = ReportInterval.semana;
      label = '${now.day} ${months[now.month - 1]} ${now.year} (Hoy)';
    } else if (periodoType == 'mes' || daysCount == 30) {
      startDate = DateTime(now.year, now.month, 1);
      targetInterval = ReportInterval.mes;
      label = '${startDate.day} ${months[startDate.month - 1]} - ${now.day} ${months[now.month - 1]} ${now.year} (Mes en curso)';
    } else if (periodoType == 'anio' || periodoType == 'año' || daysCount == 365) {
      startDate = DateTime(now.year, 1, 1);
      targetInterval = ReportInterval.anio;
      label = '${now.year} (Año en curso)';
    } else if (daysCount != null && daysCount > 0) {
      startDate = now.subtract(Duration(days: daysCount - 1));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      targetInterval = daysCount <= 7
          ? ReportInterval.semana
          : (daysCount <= 31 ? ReportInterval.mes : ReportInterval.anio);
      label = '${startDate.day} ${months[startDate.month - 1]} - ${now.day} ${months[now.month - 1]} ${now.year} (Últimos $daysCount días)';
    } else {
      startDate = now.subtract(const Duration(days: 6));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      targetInterval = ReportInterval.semana;
      label = '${startDate.day} ${months[startDate.month - 1]} - ${now.day} ${months[now.month - 1]} ${now.year} (Últimos 7 días)';
    }

    return (
      startDate: startDate,
      endDate: endDate,
      label: label,
      targetInterval: targetInterval,
    );
  }

  /// Calculates statistics for a treatment in the given date range using tolerance matching
  Map<String, int> _calcularEstadisticas(Tratamiento tratamiento, DateTime startDate, DateTime endDate) {
    int tomadas = 0;
    int omitidas = 0;
    int notificadas = 0;
    int aplazadas = 0;

    final now = DateTime.now();
    final end = endDate.isBefore(now) ? endDate : now;

    // 1. Recopilar dosis registradas explícitamente en doseStatus dentro del rango [startDate, endDate]
    final List<DateTime> recordedTimes = [];
    tratamiento.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null &&
          !parsedTime.isBefore(startDate) &&
          !parsedTime.isAfter(endDate)) {
        recordedTimes.add(parsedTime);
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
            aplazadas++;
            break;
          case DoseStatus.pendiente:
            omitidas++;
            break;
        }
      }
    });

    // 2. Generar dosis programadas en el rango [startDate, endDate] y verificar las ya pasadas con tolerancia
    final todasLasDosis = TratamientoService.generarDosisEnRango(tratamiento, startDate, endDate);
    final intervaloMinutos = tratamiento.intervaloDosis.inMinutes > 0 ? tratamiento.intervaloDosis.inMinutes : 240;
    final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);

    for (final doseTime in todasLasDosis) {
      if (!doseTime.isBefore(startDate) && doseTime.isBefore(now)) {
        bool isRecorded = false;
        for (final rec in recordedTimes) {
          if (rec.difference(doseTime).inMinutes.abs() <= maxToleranceMinutes) {
            isRecorded = true;
            break;
          }
        }
        if (!isRecorded) {
          omitidas++;
        }
      }
    }

    final int programadasPasadas = tomadas + omitidas + notificadas + aplazadas;

    return {
      'tomadas': tomadas,
      'omitidas': omitidas,
      'notificadas': notificadas,
      'aplazadas': aplazadas,
      'programadasPasadas': programadasPasadas,
    };
  }

  /// Gets recent dose history entries
  List<Map<String, dynamic>> _getRecentHistory(List<Tratamiento> tratamientos, [DateTime? startDate]) {
    final List<Map<String, dynamic>> history = [];
    final now = DateTime.now();
    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.tryParse(dateString);
        if (doseTime != null &&
            (startDate == null || !doseTime.isBefore(startDate)) &&
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
  Map<String, String> _analyzeOmissionsPattern(
    List<Tratamiento> tratamientos,
    int totalOmitidas,
    DateTime startDate,
    String periodLabel,
  ) {
    if (totalOmitidas == 0) {
      return {
        'icon': '🎉',
        'title': '¡Gran constancia!',
        'subtitle': 'No presentas omisiones registradas en el período evaluado.',
      };
    }

    int morningOmissions = 0;
    int afternoonOmissions = 0;
    int nightOmissions = 0;
    int earlyOmissions = 0;

    final now = DateTime.now();

    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(dateString);
          if (doseTime != null && !doseTime.isBefore(startDate) && doseTime.isBefore(now)) {
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

    if (maxVal > 0) {
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

    return {
      'icon': '💡',
      'title': 'Oportunidad de mejora',
      'subtitle': 'Registras $totalOmitidas dosis pendientes o no confirmadas en este período.',
    };
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
      stream: firestoreService.getMedicamentosStream(user.uid, _getActiveCaregiverProfile(context)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final allTreatments = snapshot.data ?? [];
        final tratamientos = allTreatments.where((t) => t.isActivo || !t.isFinalizado).toList();

        if (tratamientos.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Text(
              'Aún no tienes medicamentos activos registrados para calcular tu progreso de adherencia.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }

        // Calculate global stats
        final periodConfig = _resolvePeriodConfig();
        final startDate = periodConfig.startDate;
        final endDate = periodConfig.endDate;
        final periodLabel = periodConfig.label;
        final targetInterval = periodConfig.targetInterval;

        int totalTomadas = 0;
        int totalOmitidas = 0;
        int totalNotificadas = 0;
        int totalProgramadas = 0;

        final List<Map<String, dynamic>> perTreatmentStats = [];

        for (var t in tratamientos) {
          final stats = _calcularEstadisticas(t, startDate, endDate);
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

        final recentHistory = _getRecentHistory(tratamientos, startDate);
        final omissionsInfo = _analyzeOmissionsPattern(tratamientos, totalOmitidas, startDate, periodLabel);

        final bool isGoodAdherence = overallAdherence >= 80;

        void navigateToReportes() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportesPage(initialInterval: targetInterval),
            ),
          );
        }

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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: navigateToReportes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 1. HEADER: Overall Adherence ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.insights_rounded, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reporte de Adherencia',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                periodLabel,
                                style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                              ),
                            ],
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
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.secondaryTextColor),
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
                            style: TextStyle(
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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

              // ─── 8. TAP FOOTER HINT ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  border: Border(top: BorderSide(color: AppTheme.borderColor)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 15, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'Toca para ver el reporte completo y tendencias',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryColor),
                  ],
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
  final void Function(
    String name,
    String pres,
    int interval,
    int dosis,
    int duration,
    String notas, [
    CaregiverProfile? targetProfile,
  ]) onSaved;

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

  CaregiverProfile? _selectedProfile;
  bool _profileInitialized = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileInitialized) {
      _profileInitialized = true;
      _initSelectedProfile();
    }
  }

  void _initSelectedProfile() {
    final prefNotifier = context.read<PreferenceNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final allProfiles = caregiverNotifier.managedProfiles;
    final data = widget.prescriptionData;

    final targetId = data['targetProfileId']?.toString();
    final targetName = data['targetProfileName']?.toString();

    if (targetId != null && targetId.isNotEmpty && targetId != 'general') {
      try {
        _selectedProfile = allProfiles.firstWhere((p) => p.id == targetId);
        return;
      } catch (_) {}
    }

    if (targetName != null && targetName.trim().isNotEmpty) {
      final clean = targetName.trim().toLowerCase();
      if (clean != 'personal' && clean != 'yo' && clean != 'mí' && clean != 'mi perfil') {
        final modeProfiles = allProfiles.where((p) => isAnimal ? p.isAnimal : !p.isAnimal).toList();
        final pool = modeProfiles.isNotEmpty ? modeProfiles : allProfiles;
        try {
          _selectedProfile = pool.firstWhere((p) => p.name.trim().toLowerCase() == clean);
          return;
        } catch (_) {
          try {
            _selectedProfile = pool.firstWhere((p) =>
                p.name.trim().toLowerCase().contains(clean) ||
                clean.contains(p.name.trim().toLowerCase()));
            return;
          } catch (_) {}
        }
      }
    }

    _selectedProfile = caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal);
    if (_selectedProfile == null && isAnimal) {
      final animals = allProfiles.where((p) => p.isAnimal).toList();
      if (animals.isNotEmpty) {
        _selectedProfile = animals.first;
      }
    }
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
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final isCaregiver = caregiverNotifier.isCaregiverModeActive;
    final availableProfiles = caregiverNotifier.managedProfiles
        .where((p) => isAnimal ? p.isAnimal : !p.isAnimal)
        .toList();

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
          if (isCaregiver || isAnimal) ...[
            if (isSaved)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (isAnimal ? Colors.teal : AppTheme.primaryColor).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isAnimal ? Colors.teal : AppTheme.primaryColor).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAnimal ? Icons.pets_rounded : Icons.person_rounded,
                      size: 20,
                      color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAnimal ? 'Mascota / Paciente' : 'Paciente asignado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedProfile != null
                                ? '${_selectedProfile!.name} (${isAnimal ? (_selectedProfile!.species ?? "Mascota") : _selectedProfile!.relationship})'
                                : 'Mi Perfil Personal (Yo)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAnimal ? Icons.pets_rounded : Icons.person_outline_rounded,
                          size: 16,
                          color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAnimal ? 'Paciente / Mascota a tratar' : 'Paciente asignado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<CaregiverProfile?>(
                      value: availableProfiles.contains(_selectedProfile) ? _selectedProfile : null,
                      dropdownColor: Theme.of(context).cardColor,
                      isExpanded: true,
                      style: TextStyle(
                        color: AppTheme.primaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      items: [
                        if (!isAnimal)
                          const DropdownMenuItem<CaregiverProfile?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.person_pin_rounded, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  'Mi Perfil Personal (Yo)',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ...availableProfiles.map((p) {
                          Color pColor = isAnimal ? Colors.teal : AppTheme.primaryColor;
                          try {
                            pColor = Color(int.parse(p.colorHex.replaceFirst('#', '0xFF')));
                          } catch (_) {}
                          return DropdownMenuItem<CaregiverProfile?>(
                            value: p,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: pColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.name} (${isAnimal ? (p.species ?? "Mascota") : p.relationship})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedProfile = val;
                          widget.prescriptionData['targetProfileId'] = val?.id;
                          widget.prescriptionData['targetProfileName'] = val?.name;
                        });
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
                          borderSide: BorderSide(
                            color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
                borderSide: BorderSide(color: AppTheme.primaryColor),
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

                  widget.onSaved(name, pres, interval, dosis, duration, notas, _selectedProfile);
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
              borderSide: BorderSide(color: AppTheme.primaryColor),
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
  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.prescriptionData,
    this.showAdherenceChart = false,
    this.adherenceChartData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isUser;
  final bool isStreaming;
  final Map<String, dynamic>? prescriptionData;
  final bool showAdherenceChart;
  final Map<String, dynamic>? adherenceChartData;
  final DateTime timestamp;

  _ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isStreaming,
    Map<String, dynamic>? prescriptionData,
    bool? showAdherenceChart,
    Map<String, dynamic>? adherenceChartData,
    DateTime? timestamp,
  }) {
    return _ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isStreaming: isStreaming ?? this.isStreaming,
      prescriptionData: prescriptionData ?? this.prescriptionData,
      showAdherenceChart: showAdherenceChart ?? this.showAdherenceChart,
      adherenceChartData: adherenceChartData ?? this.adherenceChartData,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
