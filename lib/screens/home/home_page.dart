import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/screens/medication/agregar_receta_page.dart';
import 'package:meditime/core/subscription_guard.dart';
import 'package:meditime/models/caregiver_profile.dart';

// Pantallas y Widgets
import 'package:meditime/screens/calendar/calendario_page.dart';
import 'package:meditime/screens/medication/receta_page.dart';
import 'package:meditime/screens/medication/general_caregiver_page.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:meditime/screens/reports/progreso_page.dart';
import 'package:meditime/widgets/drawer_widget.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/widgets/midi_blinking_icon.dart';
import 'package:meditime/widgets/caregiver/patient_selector_dialog.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  bool _isTutorialRunning = false;

  // Showcase keys (un step por funcionalidad clave)
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _chatbotKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _calendarViewKey = GlobalKey();
  final GlobalKey _progressKey = GlobalKey();
  final GlobalKey _progressRingKey = GlobalKey();
  final GlobalKey _progressTimelineKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();

  // Contexto dentro del árbol de ShowCaseWidget para poder llamar startShowCase / dismiss
  BuildContext? _showcaseContext;

  // OverlayEntry para el botón "Saltar", siempre encima del overlay del showcase
  OverlayEntry? _skipOverlay;

  @override
  void initState() {
    super.initState();
    // Espera a que el primer frame se pinte (y _showcaseContext quede asignado)
    // antes de verificar si hay que mostrar el tutorial.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeTutorial();
    });
  }

  @override
  void dispose() {
    _hideSkipButton();
    _pageController.dispose();
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeTutorial() async {
    if (!mounted) return;
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null) return;

    final shown = await PreferenceService().hasTutorialBeenShown(userId);
    if (!shown && mounted) {
      _startTutorial();
    }
  }

  void _startTutorial() {
    if (_showcaseContext == null || !mounted) return;
    setState(() => _isTutorialRunning = true);
    
    final isSimplified = context.read<PreferenceNotifier>().simplifiedInterface;
    
    ShowCaseWidget.of(_showcaseContext!).startShowCase([
      _menuKey,
      if (!isSimplified) _chatbotKey,
      _summaryKey,
      _dateKey,
      _fabKey,
      _calendarKey,
      _calendarViewKey,
      _progressKey,
      _progressRingKey,
      _progressTimelineKey,
      _bottomNavKey,
    ]);
  }

  void _showSkipButton([GlobalKey? currentKey]) {
    if (!mounted) return;
    _hideSkipButton();
    final isChatbotStep = currentKey == _chatbotKey;
    _skipOverlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            top: MediaQuery.of(ctx).padding.top + 12,
            right: isChatbotStep ? null : 16,
            left: isChatbotStep ? 16 : null,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _skipTutorial,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.tutorialSkip ?? 'Saltar',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
    Overlay.of(context).insert(_skipOverlay!);
  }

  void _hideSkipButton() {
    _skipOverlay?.remove();
    _skipOverlay = null;
  }

  Future<void> _markTutorialDone() async {
    if (!mounted) return;
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null) return;
    await PreferenceService().markTutorialShown(userId);
  }

  void _skipTutorial() {
    if (_showcaseContext != null) {
      ShowCaseWidget.of(_showcaseContext!).dismiss();
    }
    setState(() => _isTutorialRunning = false);
    _hideSkipButton();
    _markTutorialDone();
  }

  void _onTabTapped(int index) {
    _currentIndexNotifier.value = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }



  void _handleLogout() async {
    final authService = context.read<AuthService>();
    final profileNotifier = context.read<ProfileNotifier>();

    final result = await authService.signOut(profileNotifier: profileNotifier);

    if (result.isFailure && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error al cerrar sesión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<String> titles = [
      l10n?.appBarMedications ?? 'Medicamentos',
      l10n?.appBarCalendar ?? 'Calendario',
      l10n?.appBarProgress ?? 'Mi Progreso',
    ];

    return ShowCaseWidget(
      blurValue: 3.0,
      onStart: (index, key) {
        if (!_isTutorialRunning) {
          setState(() => _isTutorialRunning = true);
        }
        // Re-insertar el botón saltar tras el renderizado de la capa de desenfoque del showcase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _isTutorialRunning) {
              _showSkipButton(key);
            }
          });
        });
      },
      onComplete: (index, key) {
        // Navegar a la página correcta reactivamente según la clave del tutorial
        if (key == _fabKey) {
          _pageController.jumpToPage(1);
          _currentIndexNotifier.value = 1;
        } else if (key == _calendarViewKey) {
          _pageController.jumpToPage(2);
          _currentIndexNotifier.value = 2;
        } else if (key == _progressTimelineKey) {
          _pageController.jumpToPage(0);
          _currentIndexNotifier.value = 0;
        }
      },
      onFinish: () {
        _pageController.jumpToPage(0);
        _currentIndexNotifier.value = 0;
        setState(() => _isTutorialRunning = false);
        _hideSkipButton();
        _markTutorialDone();
      },
      builder: (ctx) {
        // Guardamos este contexto (que sí está dentro del árbol de ShowCaseWidget)
        // para poder llamar startShowCase / dismiss desde métodos externos.
        _showcaseContext = ctx;

        final l10n = AppLocalizations.of(ctx);
        final preferenceNotifier = ctx.watch<PreferenceNotifier>();
        final isModern = preferenceNotifier.interfaceStyle == 'modern';
        final caregiverNotifier = ctx.watch<CaregiverNotifier>();
        final isAnimalMode = preferenceNotifier.isAnimalMode;
        final isCaregiverActive = caregiverNotifier.isCaregiverModeActive;
        final isManagedModeActive = isCaregiverActive || isAnimalMode;
        final activeProfile = caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimalMode);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          extendBody: isModern,
          appBar: AppBar(
            centerTitle: true,
            title: isManagedModeActive
                ? InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const PatientSelectorDialog(),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                            ? Border.all(color: AppTheme.borderColor)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            caregiverNotifier.isGeneralMode
                                ? (isAnimalMode ? Icons.pets_rounded : Icons.grid_view_rounded)
                                : (activeProfile != null
                                    ? (activeProfile.isAnimal || isAnimalMode
                                        ? Icons.pets_rounded
                                        : (caregiverNotifier.modeType == CaregiverModeType.clinico
                                            ? Icons.hotel_rounded
                                            : Icons.person_rounded))
                                    : (isAnimalMode ? Icons.pets_rounded : Icons.person_pin_rounded)),
                            color: activeProfile != null
                                ? Color(int.parse(activeProfile.colorHex.replaceFirst('#', 'FF'), radix: 16))
                                : AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              caregiverNotifier.isGeneralMode
                                  ? (isAnimalMode
                                      ? 'Vista General (Mascotas)'
                                      : 'Vista General (Todos)')
                                  : (activeProfile != null
                                      ? activeProfile.name
                                      : (isAnimalMode ? 'Seleccionar Mascota' : 'Mi Perfil')),
                              style: TextStyle(
                                color: AppTheme.primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryTextColor,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  )
                : ValueListenableBuilder<int>(
                    valueListenable: _currentIndexNotifier,
                    builder: (context, currentIndex, _) {
                      return Text(
                        titles[currentIndex],
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      );
                    },
                  ),
            actions: [
              if (!preferenceNotifier.simplifiedInterface)
                Showcase.withWidget(
                  key: _chatbotKey,
                  height: 160,
                  width: 320,
                  disableDefaultTargetGestures: true,
                  container: TutorialTooltip(
                    icon: Icons.smart_toy_rounded,
                    title: l10n?.tutorialStep2Title ?? 'Midi, tu Asistente Virtual',
                    description: l10n?.tutorialStep2Desc ?? 'Conoce a Midi, tu asistente inteligente. Chatea con él para resolver dudas sobre medicamentos, dosis, efectos secundarios e interacciones.',
                    stepNumber: 2,
                    totalSteps: 11,
                  ),
                  targetShapeBorder: const CircleBorder(),
                  targetPadding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: const MidiBlinkingIcon(size: 28),
                    onPressed: () {
                      Navigator.pushNamed(context, ChatBotScreen.routeName);
                    },
                  ),
                ),
            ],
            leading: Showcase.withWidget(
              key: _menuKey,
              height: 160,
              width: 320,
              disableDefaultTargetGestures: true,
              container: TutorialTooltip(
                icon: Icons.menu_rounded,
                title: l10n?.tutorialStep1Title ?? 'Menú Principal',
                description: l10n?.tutorialStep1Desc ?? 'Accede al menú lateral para ver tu Perfil, Reportes de Adherencia en PDF, gestionar Pacientes (Modo Cuidador) y ajustar Notificaciones.',
                stepNumber: 1,
                totalSteps: 11,
              ),
              targetShapeBorder: const CircleBorder(),
              targetPadding: const EdgeInsets.all(4),
              child: Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.menu_outlined),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    color: AppTheme.secondaryTextColor,
                  );
                },
              ),
            ),
          ),
          drawer: CustomDrawer(
            onLogout: _handleLogout,
            onStartTutorial: _startTutorial,
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (isManagedModeActive && caregiverNotifier.isGeneralMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      color: AppTheme.primaryColor,
                      child: Text(
                        isAnimalMode
                            ? 'Vista General: Todas las mascotas'
                            : 'Vista General: Todos los pacientes',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (isManagedModeActive && activeProfile != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      color: Color(int.parse(activeProfile.colorHex.replaceFirst('#', 'FF'), radix: 16)),
                      child: Text(
                        isAnimalMode
                            ? 'Viendo tratamientos de: ${activeProfile.name}'
                            : 'Viendo agenda médica de: ${activeProfile.name}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: PageView(
                      physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                      controller: _pageController,
                      onPageChanged: (index) {
                        if (_currentIndexNotifier.value != index) {
                          _currentIndexNotifier.value = index;
                        }
                      },
                      children: [
                        (isManagedModeActive && caregiverNotifier.isGeneralMode)
                            ? const GeneralCaregiverPage()
                            : RecetaPage(
                                fabKey: isModern ? null : _fabKey,
                                summaryKey: _summaryKey,
                                dateKey: _dateKey,
                              ),
                        CalendarioPage(
                          calendarKey: _calendarKey,
                          calendarViewKey: _calendarViewKey,
                        ),
                        ProgresoPage(
                          progressRingKey: _progressRingKey,
                          progressTimelineKey: _progressTimelineKey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isModern)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 160,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.backgroundColor.withValues(alpha: 0.0),
                            AppTheme.backgroundColor.withValues(alpha: 0.35),
                            AppTheme.backgroundColor.withValues(alpha: 0.8),
                            AppTheme.backgroundColor.withValues(alpha: 0.98),
                          ],
                          stops: const [0.0, 0.35, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: isModern
              ? SafeArea(
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
                    child: Row(
                      children: [
                        // Left: Capsule navigation bar
                        Expanded(
                          child: Showcase.withWidget(
                            key: _bottomNavKey,
                            height: 160,
                            width: 320,
                            disableDefaultTargetGestures: true,
                            container: TutorialTooltip(
                              icon: Icons.navigation_rounded,
                              title: l10n?.tutorialStep11Title ?? 'Navegación Principal',
                              description: l10n?.tutorialStep11Desc ?? '¡Todo listo! Usa la barra inferior para moverte cómodamente entre Receta, Calendario y Mi Progreso.',
                              stepNumber: 11,
                              totalSteps: 11,
                            ),
                            targetShapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            targetPadding: EdgeInsets.zero,
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                                    ? Border.all(color: AppTheme.borderColor, width: 1)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.45)
                                        : Colors.black.withValues(alpha: 0.04),
                                    blurRadius: isDark ? 16 : 10,
                                    offset: const Offset(0, -3),
                                  ),
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _currentIndexNotifier,
                                  builder: (context, currentIndex, _) {
                                    return BottomNavigationBar(
                                      onTap: _onTabTapped,
                                      currentIndex: currentIndex,
                                      selectedItemColor: AppTheme.primaryColor,
                                      unselectedItemColor:
                                          AppTheme.secondaryTextColor.withOpacity(0.6),
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      type: BottomNavigationBarType.fixed,
                                      items: [
                                        BottomNavigationBarItem(
                                          icon: const Icon(Icons.medication_rounded),
                                          label: l10n?.navPrescription ?? 'Receta',
                                        ),
                                        BottomNavigationBarItem(
                                          icon: Showcase.withWidget(
                                            key: _calendarKey,
                                            height: 160,
                                            width: 320,
                                            disableDefaultTargetGestures: true,
                                            container: TutorialTooltip(
                                              icon: Icons.calendar_month_rounded,
                                              title: l10n?.tutorialStep6Title ?? 'Pestaña Calendario',
                                              description: l10n?.tutorialStep6Desc ?? 'Accede al Calendario interactivo para ver tu historial de tomas organizado día por día.',
                                              stepNumber: 6,
                                              totalSteps: 11,
                                            ),
                                            targetShapeBorder: const CircleBorder(),
                                            targetPadding: const EdgeInsets.all(4),
                                            child: const Icon(Icons.calendar_today),
                                          ),
                                          label: l10n?.navCalendar ?? 'Calendario',
                                        ),
                                        BottomNavigationBarItem(
                                          icon: Showcase.withWidget(
                                            key: _progressKey,
                                            height: 160,
                                            width: 320,
                                            disableDefaultTargetGestures: true,
                                            container: TutorialTooltip(
                                              icon: Icons.bar_chart_rounded,
                                              title: l10n?.tutorialStep8Title ?? 'Pestaña Mi Progreso',
                                              description: l10n?.tutorialStep8Desc ?? 'Accede a la pestaña Progreso para analizar tus estadísticas de salud, cumplimiento acumulado y rachas.',
                                              stepNumber: 8,
                                              totalSteps: 11,
                                            ),
                                            targetShapeBorder: const CircleBorder(),
                                            targetPadding: const EdgeInsets.all(4),
                                            child: const Icon(Icons.bar_chart_rounded),
                                          ),
                                          label: l10n?.navProgress ?? 'Progreso',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right: Modern FAB
                        Showcase.withWidget(
                          key: _fabKey,
                          height: 160,
                          width: 320,
                          disableDefaultTargetGestures: true,
                          container: TutorialTooltip(
                            icon: Icons.add_circle_outline_rounded,
                            title: l10n?.tutorialStep5Title ?? 'Agregar Receta o Tratamiento',
                            description: l10n?.tutorialStep5Desc ?? 'Toca el botón + para registrar nuevos medicamentos, definir frecuencias de tomas y configurar recordatorios automáticos.',
                            stepNumber: 5,
                            totalSteps: 11,
                          ),
                          targetShapeBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          targetPadding: const EdgeInsets.all(4),
                          child: InkWell(
                            onTap: () async {
                              final canProceed = await SubscriptionGuard.canAddTreatment(context);
                              if (!canProceed || !context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AgregarRecetaPage(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Showcase.withWidget(
                  key: _bottomNavKey,
                  height: 160,
                  width: 320,
                  disableDefaultTargetGestures: true,
                  container: TutorialTooltip(
                    icon: Icons.navigation_rounded,
                    title: l10n?.tutorialStep11Title ?? 'Navegación Principal',
                    description: l10n?.tutorialStep11Desc ?? '¡Todo listo! Usa la barra inferior para moverte cómodamente entre Receta, Calendario y Mi Progreso.',
                    stepNumber: 11,
                    totalSteps: 11,
                  ),
                  targetShapeBorder: const RoundedRectangleBorder(),
                  targetPadding: EdgeInsets.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                          ? Border(top: BorderSide(color: AppTheme.borderColor, width: 1))
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: isDark ? 16 : 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentIndexNotifier,
                      builder: (context, currentIndex, _) {
                        return BottomNavigationBar(
                          onTap: _onTabTapped,
                          currentIndex: currentIndex,
                          selectedItemColor: AppTheme.primaryColor,
                          unselectedItemColor: AppTheme.secondaryTextColor.withOpacity(0.6),
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          items: [
                            BottomNavigationBarItem(
                              icon: const Icon(Icons.medication_rounded),
                              label: l10n?.navPrescription ?? 'Receta',
                            ),
                            BottomNavigationBarItem(
                              icon: Showcase.withWidget(
                                key: _calendarKey,
                                height: 160,
                                width: 320,
                                disableDefaultTargetGestures: true,
                                container: TutorialTooltip(
                                  icon: Icons.calendar_month_rounded,
                                  title: l10n?.tutorialStep6Title ?? 'Pestaña Calendario',
                                  description: l10n?.tutorialStep6Desc ?? 'Accede al Calendario interactivo para ver tu historial de tomas organizado día por día.',
                                  stepNumber: 6,
                                  totalSteps: 11,
                                ),
                                targetShapeBorder: const CircleBorder(),
                                targetPadding: const EdgeInsets.all(4),
                                child: const Icon(Icons.calendar_today),
                              ),
                              label: l10n?.navCalendar ?? 'Calendario',
                            ),
                            BottomNavigationBarItem(
                              icon: Showcase.withWidget(
                                key: _progressKey,
                                height: 160,
                                width: 320,
                                disableDefaultTargetGestures: true,
                                container: TutorialTooltip(
                                  icon: Icons.bar_chart_rounded,
                                  title: l10n?.tutorialStep8Title ?? 'Pestaña Mi Progreso',
                                  description: l10n?.tutorialStep8Desc ?? 'Accede a la pestaña Progreso para analizar tus estadísticas de salud, cumplimiento acumulado y rachas.',
                                  stepNumber: 8,
                                  totalSteps: 11,
                                ),
                                targetShapeBorder: const CircleBorder(),
                                targetPadding: const EdgeInsets.all(4),
                                child: const Icon(Icons.bar_chart_rounded),
                              ),
                              label: l10n?.navProgress ?? 'Progreso',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// --- LA CLASE REDUNDANTE NotificationPermissions SE HA ELIMINADO COMPLETAMENTE DE ESTE ARCHIVO ---
