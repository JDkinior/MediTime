import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/screens/shared/opciones_page.dart';
import 'package:meditime/screens/reports/reportes_page.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:meditime/screens/profile/perfil_page.dart';
import 'package:meditime/screens/caregiver/manage_caregiver_profiles_page.dart';
import 'package:meditime/screens/shared/modo_cuidador_opciones_page.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback? onStartTutorial;

  const CustomDrawer({
    super.key,
    required this.onLogout,
    this.onStartTutorial,
  });

  String _obtenerSaludo() {
    final greeting = AppUtils.getTimeBasedGreeting();
    return '¡$greeting!';
  }

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final profile = context.watch<ProfileNotifier>();
    final caregiver = context.watch<CaregiverNotifier>();

    final nameParts = profile.userName?.split(' ');
    final displayName = nameParts?.take(2).join(' ') ?? AppConstants.defaultUserName;
    final profileImagePath = profile.profileImageUrl;
    final canLoadProfileImage =
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        !_isDeprecatedFirebaseStorageUrl(profileImagePath);

    final isCaregiverActive = caregiver.isCaregiverModeActive;

    // Background matching the rest of the application
    final drawerBgColor = Theme.of(context).scaffoldBackgroundColor;

    final headerGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B2236), Color(0xFF14192A)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEBF3FF), Color(0xFFE2EDFF)],
          );

    final sectionHeaderColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF3F9);

    return Drawer(
      backgroundColor: drawerBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                // Profile Image without border ring
                CircleAvatar(
                  radius: 34,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  backgroundImage: canLoadProfileImage ? NetworkImage(profileImagePath) : null,
                  child: !canLoadProfileImage
                      ? Icon(
                          Icons.person,
                          size: 36,
                          color: isDark ? Colors.white70 : const Color(0xFF004AC6),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _obtenerSaludo(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCaregiverActive) ...[
                        const SizedBox(height: 8),
                        // Caregiver Mode Chip Badge (only shown when active)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2A47) : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Modo Cuidador',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // LIST ITEMS
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // PRINCIPAL SECTION
                _buildSectionHeader('PRINCIPAL', sectionHeaderColor),
                _DrawerTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Mi Perfil',
                  subtitle: 'Ver y editar tu información',
                  iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  iconBgColor: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFEFF6FF),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PerfilPage()),
                    );
                  },
                ),
                _DrawerTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Reporte de Adherencia',
                  subtitle: 'Estadísticas y reportes',
                  iconColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
                  iconBgColor: isDark ? const Color(0xFF2E1B4E) : const Color(0xFFF5F3FF),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportesPage()),
                    );
                  },
                ),
                _DrawerTile(
                  icon: Icons.settings_outlined,
                  title: 'Opciones',
                  subtitle: 'Ajustes de la aplicación',
                  iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  iconBgColor: isDark ? const Color(0xFF1B382B) : const Color(0xFFECFDF5),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OpcionesPage()),
                    );
                  },
                ),

                Divider(height: 24, thickness: 1, color: dividerColor),

                // AYUDA SECTION
                _buildSectionHeader('AYUDA', sectionHeaderColor),
                _DrawerTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Ayuda',
                  subtitle: 'Centro de ayuda y soporte',
                  iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  iconBgColor: isDark ? const Color(0xFF16324A) : const Color(0xFFF0F9FF),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AyudaPage()),
                    );
                  },
                ),
                _DrawerTile(
                  icon: Icons.school_outlined,
                  title: 'Tutorial',
                  subtitle: 'Guías y consejos de uso',
                  iconColor: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
                  iconBgColor: isDark ? const Color(0xFF3D2418) : const Color(0xFFFFF7ED),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    if (onStartTutorial != null) {
                      onStartTutorial!();
                    }
                  },
                ),
                _DrawerTile(
                  icon: Icons.smart_toy_outlined,
                  title: 'Chatbot MediTime',
                  subtitle: 'Asistente inteligente',
                  iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                  iconBgColor: isDark ? const Color(0xFF2A1C4E) : const Color(0xFFF5F3FF),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, ChatBotScreen.routeName);
                  },
                ),

                if (isCaregiverActive) ...[
                  Divider(height: 24, thickness: 1, color: dividerColor),

                  // GESTIÓN SECTION
                  _buildSectionHeader('GESTIÓN', sectionHeaderColor),
                  _DrawerTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Gestionar Pacientes',
                    subtitle: 'Agregar, editar o eliminar',
                    iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    iconBgColor: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFEFF6FF),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageCaregiverProfilesPage(),
                        ),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.tune_rounded,
                    title: 'Configuración Cuidador',
                    subtitle: 'Preferencias del modo cuidador',
                    iconColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                    iconBgColor: isDark ? const Color(0xFF183B38) : const Color(0xFFF0FDFA),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModoCuidadorOpcionesPage(),
                        ),
                      );
                    },
                  ),
                ],

                Divider(height: 24, thickness: 1, color: dividerColor),

                // SALIR
                _DrawerTile(
                  icon: Icons.logout_rounded,
                  title: 'Salir',
                  subtitle: 'Cerrar sesión',
                  iconColor: const Color(0xFFEF4444),
                  iconBgColor: isDark ? const Color(0xFF3D1B1F) : const Color(0xFFFEF2F2),
                  titleColor: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: onLogout,
                ),

                const SizedBox(height: 16),
                Center(
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.hasData ? snapshot.data!.version : '2.30.0';
                      return Text(
                        'MediTime v$version',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBgColor;
  final Color? titleColor;
  final bool isDark;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBgColor,
    this.titleColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTitleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? defaultTitleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: subtitleColor,
            ),
          ],
        ),
      ),
    );
  }
}
