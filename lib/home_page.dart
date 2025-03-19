import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meditime/screens/calendario_page.dart';
import 'package:meditime/screens/instrucciones_page.dart';
import 'package:meditime/screens/perfil_page.dart';
import 'package:meditime/screens/receta_page.dart';
import 'package:meditime/screens/ayuda_page.dart';
import 'data/drawer_widget.dart';

class HomePage extends StatefulWidget {
  final List<String>? nameParts;
  final String? profileImagePath;

  const HomePage({
    super.key,
    this.nameParts,
    this.profileImagePath,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isEditing = false;
  late List<String>? _nameParts = widget.nameParts;
  late String? _profileImagePath = widget.profileImagePath;

  void onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void onSelected(BuildContext context, int item) {
    switch (item) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InstruccionesPage()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AyudaPage()),
        );
        break;
    }
  }

  String obtenerSaludo() {
    final horaActual = DateTime.now().hour;
    if (horaActual >= 6 && horaActual < 12) {
      return 'Buenos días';
    } else if (horaActual >= 12 && horaActual < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  String capitalize(String s) => s.isNotEmpty
      ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}'
      : '';

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await NotificationPermissions.requestPermissions();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los permisos son necesarios para recordatorios')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = ['Medicamentos', 'Calendario', 'Perfil'];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0, // Reduce el espacio entre el ícono y el título
title: Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0),
  child: Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      height: 28, // Altura fija para el contenedor
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // Centrado vertical
        children: [
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                colors: [
                  Color.fromARGB(255, 73, 194, 255),
                  Color.fromARGB(255, 47, 109, 180),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            child: Text(
              titles[_currentIndex],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                height: 1.0, // Altura de línea normalizada
              ),
              textAlign: TextAlign.center, // Alineación horizontal
            ),
          ),
        ],
      ),
    ),
  ),
),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 100),
            child: _currentIndex == 2
                ? IconButton(
                    key: ValueKey<bool>(_isEditing),
                    icon: Icon(_isEditing ? Icons.close_outlined : Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                  )
                : const SizedBox.shrink(),
          ),
          PopupMenuButton<int>(
          icon: Icon(Icons.question_mark, color: Color.fromARGB(255, 47, 109, 180)), // Color del icono
            
            onSelected: (item) => onSelected(context, item),
            itemBuilder: (context) => [
              const PopupMenuItem<int>(value: 0, child: Text('Tutorial')),
              const PopupMenuItem<int>(value: 1, child: Text('Ayuda')),
            ],
          ),
        ],
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu_outlined),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              color: Color.fromARGB(255, 73, 194, 255),
            );
          },
        ),
      ),
      drawer: CustomDrawer(
        nameParts: _nameParts,
        profileImagePath: _profileImagePath,
        onLogout: _handleLogout,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          const RecetaPage(),
          const CalendarioPage(),
          PerfilPage(
            isEditing: _isEditing,
            toggleEditing: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            onImageChanged: (String newPath) {
              setState(() {
                _profileImagePath = newPath;
              });
            },
            onNameChanged: (String newName) {
              setState(() {
                _nameParts = newName.split(' ');
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // Color de la sombra
              blurRadius: 12, // Difuminado
              spreadRadius: 0, // Extensión
              offset: Offset(0, -3), // Posición (horizontal, vertical)
            ),
          ],
        ),
        child: BottomNavigationBar(
          onTap: onTabTapped,
          currentIndex: _currentIndex,
          selectedItemColor: Color.fromARGB(255, 16, 162, 235),
          backgroundColor: Color.fromARGB(255, 241, 241, 241),
          elevation: 0, // Eliminamos la elevación por defecto
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_rounded),
              label: 'Receta',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Calendario',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
class NotificationPermissions {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<bool> requestPermissions() async {
    final result = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }
}