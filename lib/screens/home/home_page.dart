import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';

// Pantallas y Widgets
import 'package:meditime/screens/calendar/calendario_page.dart';
import 'package:meditime/screens/profile/perfil_page.dart';
import 'package:meditime/screens/medication/receta_page.dart';
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/widgets/drawer_widget.dart';
import 'package:meditime/screens/shared/instrucciones_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isEditing = false;

  // --- SE ELIMINA LA LLAMADA A _requestNotificationPermissions de initState ---

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

  void _handleLogout() {
    context.read<AuthService>().signOut();
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = ['Medicamentos', 'Calendario', 'Perfil'];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 28,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (_currentIndex == 2)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: _toggleEditing,
            ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.question_mark, color: Color.fromARGB(255, 47, 109, 180)),
            onSelected: (item) => _onSelectedHelpMenu(context, item),
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
              onPressed: () => Scaffold.of(context).openDrawer(),
              color: const Color.fromARGB(255, 73, 194, 255),
            );
          },
        ),
      ),
      drawer: CustomDrawer(onLogout: _handleLogout),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            if (_isEditing) _isEditing = false;
            _currentIndex = index;
          });
        },
        children: [
          const RecetaPage(),
          const CalendarioPage(),
          PerfilPage(
            isEditing: _isEditing,
            toggleEditing: _toggleEditing,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onTabTapped,
        currentIndex: _currentIndex,
        selectedItemColor: const Color.fromARGB(255, 16, 162, 235),
        backgroundColor: const Color.fromARGB(255, 241, 241, 241),
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
    );
  }
}

// --- LA CLASE REDUNDANTE NotificationPermissions SE HA ELIMINADO COMPLETAMENTE DE ESTE ARCHIVO ---