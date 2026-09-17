import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/shared/ayuda_page.dart';
import 'package:meditime/screens/shared/opciones_page.dart';
import 'package:meditime/screens/reports/reportes_page.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/core/constants.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:meditime/screens/profile/perfil_page.dart';
import 'package:meditime/screens/caregiver/manage_caregiver_profiles_page.dart';
import 'package:meditime/screens/shared/modo_cuidador_opciones_page.dart';
import 'package:meditime/screens/shared/modo_animales_opciones_page.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback? onStartTutorial;

  const CustomDrawer({
    super.key,
    required this.onLogout,
    this.onStartTutorial,
  });

  String _obtenerSaludo(BuildContext context) {
    return AppUtils.getLocalizedGreeting(context);
  }

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final profile = context.watch<ProfileNotifier>();
    final caregiver = context.watch<CaregiverNotifier>();
    final preferences = context.watch<PreferenceNotifier>();

    final nameParts = profile.userName?.split(' ');
    final displayName = nameParts?.take(2).join(' ') ?? AppConstants.defaultUserName;
    final profileImagePath = profile.profileImageUrl;
    final canLoadProfileImage =
        profileImagePath != null &&
        profileImagePath.isNotEmpty &&
        !_isDeprecatedFirebaseStorageUrl(profileImagePath);

    final isCaregiverActive = caregiver.isCaregiverModeActive;
    final isAnimalActive = preferences.isAnimalMode;

    final headerBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F6FE);
    final sectionHeaderColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // HEADER
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              color: headerBgColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
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
                        _obtenerSaludo(context),
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
                      if (isAnimalActive) ...[
                        const SizedBox(height: 8),
                        // Animal Mode Chip Badge (green)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pets_rounded,
                                size: 14,
                                color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                l10n?.drawerAnimalsMode ?? 'Modo Animales',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isCaregiverActive) ...[
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
                                l10n?.drawerCaregiverMode ?? 'Modo Cuidador',
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
                _buildSectionHeader(l10n?.drawerSectionMain ?? 'PRINCIPAL', sectionHeaderColor),
                _DrawerTile(
                  icon: Icons.person_outline_rounded,
                  title: l10n?.drawerProfile ?? 'Mi Perfil',
                  subtitle: l10n?.drawerProfileSubtitle ?? 'Ver y editar tu información',
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
                  title: l10n?.drawerAdherenceReport ?? 'Reporte de Adherencia',
                  subtitle: l10n?.drawerAdherenceReportSubtitle ?? 'Estadísticas y reportes',
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
                  title: l10n?.optionsTitle ?? 'Opciones',
                  subtitle: l10n?.drawerOptionsSubtitle ?? 'Ajustes de la aplicación',
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
                _buildSectionHeader(l10n?.drawerSectionHelp ?? 'AYUDA', sectionHeaderColor),
                _DrawerTile(
                  icon: Icons.help_outline_rounded,
                  title: l10n?.drawerHelp ?? 'Ayuda',
                  subtitle: l10n?.drawerHelpSubtitle ?? 'Centro de ayuda y soporte',
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
                  title: l10n?.drawerTutorial ?? 'Tutorial',
                  subtitle: l10n?.drawerTutorialSubtitle ?? 'Guías y consejos de uso',
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
                  title: l10n?.drawerChatbot ?? 'Chatbot MediTime',
                  subtitle: l10n?.drawerChatbotSubtitle ?? 'Asistente inteligente',
                  iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                  iconBgColor: isDark ? const Color(0xFF2A1C4E) : const Color(0xFFF5F3FF),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, ChatBotScreen.routeName);
                  },
                ),

                if (isAnimalActive) ...[
                  Divider(height: 24, thickness: 1, color: dividerColor),

                  // GESTIÓN VETERINARIA SECTION
                  _buildSectionHeader('GESTIÓN VETERINARIA', sectionHeaderColor),
                  _DrawerTile(
                    icon: Icons.pets_rounded,
                    title: l10n?.drawerManageAnimals ?? 'Gestionar Mascotas / Animales',
                    subtitle: l10n?.drawerManageAnimalsSubtitle ?? 'Agregar, editar o dar de alta',
                    iconColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                    iconBgColor: isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageCaregiverProfilesPage(isAnimalMode: true),
                        ),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.tune_rounded,
                    title: l10n?.drawerAnimalsSettings ?? 'Configuración Modo Animales',
                    subtitle: l10n?.drawerAnimalsSettingsSubtitle ?? 'Preferencias veterinarias y de mascotas',
                    iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                    iconBgColor: isDark ? const Color(0xFF133E2B) : const Color(0xFFECFDF5),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModoAnimalesOpcionesPage(),
                        ),
                      );
                    },
                  ),
                ] else if (isCaregiverActive) ...[
                  Divider(height: 24, thickness: 1, color: dividerColor),

                  // GESTIÓN SECTION
                  _buildSectionHeader(l10n?.drawerSectionManage ?? 'GESTIÓN', sectionHeaderColor),
                  _DrawerTile(
                    icon: Icons.people_outline_rounded,
                    title: l10n?.drawerManagePatients ?? 'Gestionar Pacientes',
                    subtitle: l10n?.drawerManagePatientsSubtitle ?? 'Agregar, editar o eliminar',
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
                    title: l10n?.drawerCaregiverSettings ?? 'Configuración Cuidador',
                    subtitle: l10n?.drawerCaregiverSettingsSubtitle ?? 'Preferencias del modo cuidador',
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
                  title: l10n?.drawerLogout ?? 'Salir',
                  subtitle: l10n?.drawerLogoutSubtitle ?? 'Cerrar sesión',
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
