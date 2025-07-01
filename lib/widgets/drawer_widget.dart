import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/profile_notifier.dart'; // Importa el Notifier
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/screens/shared/opciones_page.dart';
import 'package:meditime/screens/reports/reportes_page.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  // Se eliminan nameParts y profileImagePath del constructor

  const CustomDrawer({
    super.key,
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
    // Escuchamos los cambios en el ProfileNotifier
    final profile = context.watch<ProfileNotifier>();
    final nameParts = profile.userName?.split(' ');
    final profileImagePath = profile.profileImageUrl;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF3FB8EE),
                  Color(0xFF4092E4),
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: profileImagePath != null && profileImagePath.isNotEmpty
                      ? NetworkImage(profileImagePath)
                      : null,
                  child: profileImagePath == null || profileImagePath.isEmpty
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
                        // Usamos los datos del notifier
                        nameParts?.take(2).join(' ') ?? 'Usuario',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assessment_outlined), // <-- Ícono para el reporte
            title: const Text('Reporte de Adherencia'),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Opciones'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OpcionesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ayuda'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AyudaPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Salir'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}