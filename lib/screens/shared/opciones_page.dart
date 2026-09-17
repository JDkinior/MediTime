import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/shared/accesibilidad_page.dart';
import 'package:meditime/screens/shared/diseno_apariencia_page.dart';
import 'package:meditime/screens/shared/notificaciones_opciones_page.dart';
import 'package:meditime/screens/shared/datos_privacidad_page.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/screens/onboarding/onboarding_page.dart';
import 'package:meditime/screens/shared/modo_cuidador_opciones_page.dart';
import 'package:meditime/screens/shared/modo_animales_opciones_page.dart';
import 'package:meditime/screens/shared/idioma_opciones_page.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class OpcionesPage extends StatelessWidget {
  const OpcionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l10n?.optionsTitle ?? 'Opciones'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsLanguage ?? 'Idioma',
            subtitle: l10n?.optionsLanguageSubtitle ?? 'Selecciona el idioma de la aplicación.',
            icon: Icons.language_rounded,
            iconColor: Colors.indigo,
            page: const IdiomaOpcionesPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsAccessibility ?? 'Accesibilidad',
            subtitle: l10n?.optionsAccessibilitySubtitle ?? 'Oculta opciones secundarias y se enfoca solo en lo más importante.',
            icon: Icons.accessibility_new_rounded,
            iconColor: AppTheme.primaryColor,
            page: const AccesibilidadPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsAppearance ?? 'Diseño y Apariencia',
            subtitle: l10n?.optionsAppearanceSubtitle ?? 'Personaliza la apariencia de la app a tu gusto.',
            icon: Icons.palette_outlined,
            iconColor: Colors.amber,
            page: const DisenoAparienciaPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsNotifications ?? 'Notificaciones y Alarmas',
            subtitle: l10n?.optionsNotificationsSubtitle ?? 'Configura cómo quieres recibir tus recordatorios.',
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.blue,
            page: const NotificacionesOpcionesPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsPrivacy ?? 'Datos y Privacidad',
            subtitle: l10n?.optionsPrivacySubtitle ?? 'Gestiona tu historial médico y de chats.',
            icon: Icons.security_rounded,
            iconColor: AppTheme.errorColor,
            page: const DatosPrivacidadPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsCaregiver ?? 'Modo Cuidador',
            subtitle: l10n?.optionsCaregiverSubtitle ?? 'Configura la gestión multi-perfil para familiares o sector clínico.',
            icon: Icons.health_and_safety_outlined,
            iconColor: Colors.teal,
            page: const ModoCuidadorOpcionesPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: l10n?.optionsAnimals ?? 'Modo Animales (Veterinaria)',
            subtitle: l10n?.optionsAnimalsSubtitle ?? 'Adapta la aplicación para veterinarias y mascotas (individual o múltiple).',
            icon: Icons.pets_rounded,
            iconColor: const Color(0xFF15803D),
            page: const ModoAnimalesOpcionesPage(),
          ),
          Builder(
            builder: (ctx) {
              final user = ctx.watch<AuthService>().currentUser;
              if (user == null) return const SizedBox.shrink();
              return _buildCategoryCard(
                context: ctx,
                title: 'Asistente de Personalización',
                subtitle: 'Vuelve a ejecutar la configuración guiada inicial de MediTime.',
                icon: Icons.auto_awesome_rounded,
                iconColor: Colors.deepPurple,
                page: OnboardingPage(
                  user: user,
                  onCompleted: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: const Text('Configuración actualizada con éxito.'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }
}
