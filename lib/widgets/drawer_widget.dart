import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/screens/shared/opciones_page.dart';
import 'package:meditime/screens/reports/reportes_page.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  // Se eliminan nameParts y profileImagePath del constructor

  const CustomDrawer({super.key, required this.onLogout});

  String _obtenerSaludo() {
    return AppUtils.getTimeBasedGreeting();
  }

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en el ProfileNotifier
    final profile = context.watch<ProfileNotifier>();
    final nameParts = profile.userName?.split(' ');
    final profileImagePath = profile.profileImageUrl;
    final canLoadProfileImage =
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        !_isDeprecatedFirebaseStorageUrl(profileImagePath);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3FB8EE), Color(0xFF4092E4)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: AppConstants.drawerProfileImageRadius,
                  backgroundImage:
                      canLoadProfileImage
                          ? NetworkImage(profileImagePath)
                          : null,
                  child:
                      !canLoadProfileImage
                          ? const Icon(
                            Icons.person,
                            size: 50,
                            color: AppTheme.whiteTextColor,
                          )
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
                        style: AppTheme.drawerGreetingStyle,
                      ),
                      Text(
                        // Usamos los datos del notifier
                        nameParts?.take(2).join(' ') ??
                            AppConstants.defaultUserName,
                        style: AppTheme.drawerNameStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.assessment_outlined,
            ), // <-- Ícono para el reporte
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OpcionesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ayuda'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AyudaPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('Chatbot MediTime'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, ChatBotScreen.routeName);
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
