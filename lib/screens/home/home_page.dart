import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/medication/agregar_receta_page.dart';

// Pantallas y Widgets
import 'package:meditime/screens/calendar/calendario_page.dart';
import 'package:meditime/screens/profile/perfil_page.dart';
import 'package:meditime/screens/medication/receta_page.dart';
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:meditime/screens/reports/progreso_page.dart';
import 'package:meditime/widgets/drawer_widget.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/widgets/midi_blinking_icon.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isTutorialRunning = false;

  // Showcase keys (un step por funcionalidad clave)
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _chatbotKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
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
      _profileKey,
      _bottomNavKey,
    ]);
  }

  void _showSkipButton() {
    if (!mounted) return;
    _hideSkipButton();
    _skipOverlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            top: MediaQuery.of(ctx).padding.top + 12,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: _skipTutorial,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Saltar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
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
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onSelectedHelpMenu(BuildContext context, int item) {
    switch (item) {
      case 0:
        // En lugar de navegar a InstruccionesPage, pregunta si repetir el tutorial
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                title: const Text('Repetir tutorial'),
                content: const Text(
                  '¿Deseas volver a ver el tutorial interactivo de la aplicación?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 47, 109, 180),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startTutorial();
                    },
                    child: const Text('Sí, ver tutorial'),
                  ),
                ],
              ),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AyudaPage()),
        );
        break;
      case 2:
        Navigator.pushNamed(context, ChatBotScreen.routeName);
        break;
    }
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
    final List<String> titles = ['Medicamentos', 'Calendario', 'Mi Progreso'];

    return ShowCaseWidget(
      blurValue: 3.0,
      onStart: (index, key) {
        if (!_isTutorialRunning) {
          setState(() => _isTutorialRunning = true);
        }
        // Re-insertar el botón saltar en cada paso para que quede sobre el overlay
        WidgetsBinding.instance.addPostFrameCallback((_) => _showSkipButton());
      },
      onComplete: (index, key) {
        // Navegar a la página correcta reactivamente según la clave
        if (key == _fabKey) {
          _pageController.jumpToPage(1);
          setState(() => _currentIndex = 1);
        } else if (key == _calendarKey) {
          _pageController.jumpToPage(2);
          setState(() => _currentIndex = 2);
        } else if (key == _profileKey) {
          _pageController.jumpToPage(0);
          setState(() => _currentIndex = 0);
        }
      },
      onFinish: () {
        setState(() => _isTutorialRunning = false);
        _hideSkipButton();
        _markTutorialDone();
      },
      builder: (ctx) {
        // Guardamos este contexto (que sí está dentro del árbol de ShowCaseWidget)
        // para poder llamar startShowCase / dismiss desde métodos externos.
        _showcaseContext = ctx;

        final profile = ctx.watch<ProfileNotifier>();
        final preferenceNotifier = ctx.watch<PreferenceNotifier>();
        final isModern = preferenceNotifier.interfaceStyle == 'modern';
        final profileImagePath = profile.profileImageUrl;
        final canLoadProfileImage = profileImagePath != null &&
            profileImagePath.isNotEmpty &&
            !profileImagePath.contains('firebasestorage.googleapis.com');

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                titles[_currentIndex],
                style: TextStyle(
                  color: AppTheme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            actions: [
              if (!preferenceNotifier.simplifiedInterface)
                Showcase.withWidget(
                  key: _chatbotKey,
                  height: 160,
                  width: 320,
                  disableDefaultTargetGestures: true,
                  container: const TutorialTooltip(
                    icon: Icons.smart_toy_rounded,
                    title: 'Asistente MediTime AI',
                    description: 'Resuelve tus dudas sobre dosis, efectos secundarios o interacciones de medicamentos chateando con nuestra IA inteligente.',
                    stepNumber: 2,
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
              container: const TutorialTooltip(
                icon: Icons.menu_rounded,
                title: 'Menú principal',
                description: 'Accede al menú lateral para ver reportes de adherencia, ajustar notificaciones y acceder al chat de IA.',
                stepNumber: 1,
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
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              RecetaPage(
                fabKey: isModern ? null : _fabKey,
                summaryKey: _summaryKey,
                dateKey: _dateKey,
              ),
              CalendarioPage(calendarKey: _calendarKey),
              const ProgresoPage(),
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
                            container: const TutorialTooltip(
                              icon: Icons.swap_horiz_rounded,
                              title: 'Navegación principal',
                              description: 'Muévete entre tus Recetas (medicamentos pendientes), el Calendario mensual y tu Progreso de salud.',
                              stepNumber: 8,
                            ),
                            targetShapeBorder: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            targetPadding: EdgeInsets.zero,
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFC3C6D7).withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BottomNavigationBar(
                                  onTap: _onTabTapped,
                                  currentIndex: _currentIndex,
                                  selectedItemColor: AppTheme.primaryColor,
                                  unselectedItemColor:
                                      AppTheme.secondaryTextColor.withOpacity(0.6),
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  type: BottomNavigationBarType.fixed,
                                  items: [
                                    const BottomNavigationBarItem(
                                      icon: Icon(Icons.medication_rounded),
                                      label: 'Receta',
                                    ),
                                    const BottomNavigationBarItem(
                                      icon: Icon(Icons.calendar_today),
                                      label: 'Calendario',
                                    ),
                                    BottomNavigationBarItem(
                                      icon: Showcase.withWidget(
                                        key: _profileKey,
                                        height: 160,
                                        width: 320,
                                        disableDefaultTargetGestures: true,
                                        container: const TutorialTooltip(
                                          icon: Icons.bar_chart_rounded,
                                          title: 'Mi Progreso',
                                          description: 'Monitorea tu nivel de adherencia, mira tus estadísticas diarias y mantén tus rachas de toma de medicamentos.',
                                          stepNumber: 7,
                                        ),
                                        targetShapeBorder: const CircleBorder(),
                                        targetPadding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.bar_chart_rounded),
                                      ),
                                      label: 'Progreso',
                                    ),
                                  ],
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
                          container: const TutorialTooltip(
                            icon: Icons.add_circle_outline_rounded,
                            title: 'Agregar medicamento',
                            description: 'Toca aquí para añadir un nuevo medicamento. Podrás configurar el horario, intervalo y duración del tratamiento.',
                            stepNumber: 5,
                          ),
                          targetShapeBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          targetPadding: const EdgeInsets.all(4),
                          child: InkWell(
                            onTap: () {
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
                  container: const TutorialTooltip(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Navegación principal',
                    description: 'Muévete entre tus Recetas (medicamentos pendientes), el Calendario mensual y tu Progreso de salud.',
                    stepNumber: 8,
                  ),
                  targetShapeBorder: const RoundedRectangleBorder(),
                  targetPadding: EdgeInsets.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFC3C6D7).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: BottomNavigationBar(
                      onTap: _onTabTapped,
                      currentIndex: _currentIndex,
                      selectedItemColor: AppTheme.primaryColor,
                      unselectedItemColor: AppTheme.secondaryTextColor.withOpacity(0.6),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      items: [
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.medication_rounded),
                          label: 'Receta',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.calendar_today),
                          label: 'Calendario',
                        ),
                        BottomNavigationBarItem(
                          icon: Showcase.withWidget(
                            key: _profileKey,
                            height: 160,
                            width: 320,
                            disableDefaultTargetGestures: true,
                            container: const TutorialTooltip(
                              icon: Icons.bar_chart_rounded,
                              title: 'Mi Progreso',
                              description: 'Monitorea tu nivel de adherencia, mira tus estadísticas diarias y mantén tus rachas de toma de medicamentos.',
                              stepNumber: 7,
                            ),
                            targetShapeBorder: const CircleBorder(),
                            targetPadding: const EdgeInsets.all(4),
                            child: const Icon(Icons.bar_chart_rounded),
                          ),
                          label: 'Progreso',
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// --- LA CLASE REDUNDANTE NotificationPermissions SE HA ELIMINADO COMPLETAMENTE DE ESTE ARCHIVO ---
