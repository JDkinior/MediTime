import 'package:flutter/material.dart';
import 'package:meditime/screens/ayuda_page.dart';
import 'package:meditime/screens/opciones_page.dart';

class CustomDrawer extends StatelessWidget {
  final List<String>? nameParts;
  final String? profileImagePath;
  final VoidCallback onLogout;

  const CustomDrawer({
    super.key,
    this.nameParts,
    this.profileImagePath,
    required this.onLogout,
  });

  String _obtenerSaludo() {
    final horaActual = DateTime.now().hour;
    if (horaActual >= 6 && horaActual < 12) return 'Buenos días';
    if (horaActual >= 12 && horaActual < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF3FB8EE), // HEX #49C2E1
                  Color(0xFF4092E4), // HEX #2F6DB4
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: profileImagePath != null && profileImagePath!.isNotEmpty
                      ? NetworkImage(profileImagePath!)
                      : null,
                  child: profileImagePath == null || profileImagePath!.isEmpty
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _obtenerSaludo(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        nameParts?.take(2).join(' ') ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Opciones'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OpcionesPage()),
            ),
          ),
          ListTile(
            title: const Text('Ayuda'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AyudaPage()),
            ),
          ),
          ListTile(
            title: const Text('Salir'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}