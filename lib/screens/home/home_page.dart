import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/services/preference_service.dart';

// Pantallas y Widgets
import 'package:meditime/screens/calendar/calendario_page.dart';
import 'package:meditime/screens/profile/perfil_page.dart';
import 'package:meditime/screens/medication/receta_page.dart';
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:meditime/screens/reports/progreso_page.dart';
import 'package:meditime/widgets/drawer_widget.dart';
import 'package:meditime/theme/app_theme.dart';

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
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();
  final GlobalKey _helpKey = GlobalKey();

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
    ShowCaseWidget.of(_showcaseContext!).startShowCase([
      _menuKey,
      _fabKey,
      _calendarKey,
      _profileKey,
      _bottomNavKey,
      _helpKey,
    ]);
  }

  void _showSkipButton() {
    if (!mounted) return;
    _hideSkipButton();
    _skipOverlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            top: MediaQuery.of(ctx).padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: TextButton(
                onPressed: _skipTutorial,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Saltar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
      onStart: (index, key) {
        if (!_isTutorialRunning) {
          setState(() => _isTutorialRunning = true);
        }
        // Re-insertar el botón saltar en cada paso para que quede sobre el overlay
        WidgetsBinding.instance.addPostFrameCallback((_) => _showSkipButton());
      },
      onComplete: (index, key) {
        // Navegar a la página correcta antes de que empiece el siguiente paso
        if (index == 1) {
          // Después del FAB → CalendarioPage para _calendarKey
          _pageController.jumpToPage(1);
          setState(() => _currentIndex = 1);
        } else if (index == 2) {
          // Después del Calendario → PerfilPage para _profileKey
          _pageController.jumpToPage(2);
          setState(() => _currentIndex = 2);
        } else if (index == 3) {
          // Después del Perfil → volver a página 0 para _bottomNavKey
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
                style: const TextStyle(
                  color: AppTheme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: canLoadProfileImage
                    ? CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(profileImagePath),
                      )
                    : const Icon(
                        Icons.account_circle_outlined,
                        color: AppTheme.secondaryTextColor,
                      ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PerfilPage()),
                  );
                },
              ),
            ],
            leading: Showcase(
              key: _menuKey,
              title: 'Menú principal',
              description:
                  'Accede al menú lateral para ver reportes de adherencia, ajustar notificaciones y más opciones.',
              tooltipBackgroundColor: AppTheme.primaryColor,
              textColor: Colors.white,
              descTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
              targetShapeBorder: const CircleBorder(),
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
              RecetaPage(fabKey: _fabKey),
              CalendarioPage(calendarKey: _calendarKey),
              const ProgresoPage(),
            ],
          ),
          bottomNavigationBar: Showcase(
            key: _bottomNavKey,
            title: 'Navegación principal',
            description:
                'Muévete entre tus Recetas (medicamentos pendientes), el Calendario mensual y tu Progreso de salud.',
            tooltipBackgroundColor: AppTheme.primaryColor,
            textColor: Colors.white,
            descTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
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
                    icon: Showcase(
                      key: _profileKey,
                      title: 'Mi Progreso',
                      description:
                          'Monitorea tu nivel de adherencia, mira tus estadísticas diarias y mantén tus rachas de toma de medicamentos.',
                      tooltipBackgroundColor: AppTheme.primaryColor,
                      textColor: Colors.white,
                      descTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
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
