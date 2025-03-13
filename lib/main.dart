import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/data/perfil_data.dart';
import 'screens/perfil_page.dart';
import 'screens/receta_page.dart';
import 'screens/calendario_page.dart';
import 'screens/opciones_page.dart';
import 'screens/ayuda_page.dart';
import 'screens/instrucciones_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MediTime',
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _profileImagePath;
  List<String>? _nameParts;
  bool _isLoading = true;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _handleAuthStateChange(user);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthStateChange(User? user) async {
    setState(() {
      _isLoading = true;
    });

    if (user == null) {
      setState(() {
        _profileImagePath = null; // Reiniciar la imagen de perfil
        _nameParts = null; // Reiniciar el nombre
        _isLoading = false;
      });
    } else {
      await _loadProfileData(user);
      // Asegúrate de reconstruir la interfaz después de cargar los datos del perfil
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileData(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final fullName = data?[PerfilData.keyName] as String?;
        final imagePath = data?[PerfilData.keyProfileImage] as String?;

        setState(() {
          _nameParts = fullName?.split(' ') ?? [];
          _profileImagePath = imagePath ?? '';
        });
      }
    } catch (e) {
      print('Error al cargar los datos del perfil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingScreen()
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasData) {
                return MyHomePage(
                  nameParts: _nameParts,
                  profileImagePath: _profileImagePath,
                );
              } else {
                return const LoginPage();
              }
            },
          );
  }
}



class MyHomePage extends StatefulWidget {
  final List<String>? nameParts;
  final String? profileImagePath;

  const MyHomePage({
    super.key,
    this.nameParts,
    this.profileImagePath,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isEditing = false;
  List<String>? _nameParts;
  String? _profileImagePath;

  final List<String> _titles = ['Medicamentos', 'Calendario', 'Perfil'];

  @override
  void initState() {
    super.initState();
    _nameParts = widget.nameParts;
    _profileImagePath = widget.profileImagePath;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
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
            icon: const Icon(Icons.question_mark),
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
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              color: const Color.fromARGB(255, 0, 132, 255),
            );
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40.0,
                    backgroundImage: _profileImagePath != null && _profileImagePath!.isNotEmpty
                        ? NetworkImage(_profileImagePath!)
                        : null,
                    child: _profileImagePath == null || _profileImagePath!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 50)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          obtenerSaludo(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _nameParts?.take(2).map(capitalize).join(' ') ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Opciones'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OpcionesPage()),
                );
              },
            ),
            ListTile(
              title: const Text('Ayuda'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AyudaPage()),
                );
              },
            ),
            ListTile(
              title: const Text('Salir'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
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
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
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
