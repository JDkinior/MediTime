import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class OpcionesPage extends StatelessWidget {
  const OpcionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: Text(l10n?.optionsTitle ?? 'Opciones'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryTextColor,
        ),
      ),
      body: ModernContentFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const SettingsSectionHeader(
              title: 'General y Personalización',
              topPadding: 0,
            ),
            SettingsActionTileCard(
              title: l10n?.optionsAppearance ?? 'Diseño y Apariencia',
              subtitle: l10n?.optionsAppearanceSubtitle ??
                  'Tema claro/oscuro, estilo de interfaz, calendario y efectos visuales.',
              icon: Icons.palette_outlined,
              iconColor: Colors.amber.shade700,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DisenoAparienciaPage()),
              ),
            ),
            SettingsActionTileCard(
              title: l10n?.optionsAccessibility ?? 'Accesibilidad',
              subtitle: l10n?.optionsAccessibilitySubtitle ??
                  'Texto grande, botones amplios, alto contraste e interfaz simplificada.',
              icon: Icons.accessibility_new_rounded,
              iconColor: AppTheme.primaryColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccesibilidadPage()),
              ),
            ),
            SettingsActionTileCard(
              title: l10n?.optionsLanguage ?? 'Idioma',
              subtitle: l10n?.optionsLanguageSubtitle ??
                  'Selecciona el idioma de los menús y recordatorios de la aplicación.',
              icon: Icons.language_rounded,
              iconColor: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IdiomaOpcionesPage()),
              ),
            ),

            const SettingsSectionHeader(
              title: 'Alertas y Privacidad',
              topPadding: 12,
            ),
            SettingsActionTileCard(
              title: l10n?.optionsNotifications ?? 'Notificaciones y Alarmas',
              subtitle: l10n?.optionsNotificationsSubtitle ??
                  'Modo de aviso, tono de alarma, aplazamiento y diagnóstico de batería.',
              icon: Icons.notifications_active_outlined,
              iconColor: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificacionesOpcionesPage()),
              ),
            ),
            SettingsActionTileCard(
              title: l10n?.optionsPrivacy ?? 'Datos y Privacidad',
              subtitle: l10n?.optionsPrivacySubtitle ??
                  'Privacidad en pantalla, documentos legales y gestión de historial médico.',
              icon: Icons.security_rounded,
              iconColor: AppTheme.errorColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DatosPrivacidadPage()),
              ),
            ),

            const SettingsSectionHeader(
              title: 'Modos Especializados',
              topPadding: 12,
            ),
            SettingsActionTileCard(
              title: l10n?.optionsCaregiver ?? 'Modo Cuidador',
              subtitle: l10n?.optionsCaregiverSubtitle ??
                  'Configura la gestión multi-perfil para familiares o sector clínico.',
              icon: Icons.health_and_safety_outlined,
              iconColor: const Color(0xFF8B62D4),
              isPro: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModoCuidadorOpcionesPage()),
              ),
            ),
            SettingsActionTileCard(
              title: l10n?.optionsAnimals ?? 'Modo Animales (Veterinaria)',
              subtitle: l10n?.optionsAnimalsSubtitle ??
                  'Adapta la aplicación para mascotas en el hogar o clínica veterinaria.',
              icon: Icons.pets_rounded,
              iconColor: const Color(0xFF389E6A),
              isPro: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModoAnimalesOpcionesPage()),
              ),
            ),

            Builder(
              builder: (ctx) {
                final user = ctx.watch<AuthService>().currentUser;
                if (user == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SettingsSectionHeader(
                      title: 'Configuración Guiada',
                      topPadding: 12,
                    ),
                    SettingsActionTileCard(
                      title: 'Asistente de Personalización',
                      subtitle:
                          'Vuelve a ejecutar el recorrido guiado para ajustar tu perfil, propósito y estilo.',
                      icon: Icons.auto_awesome_rounded,
                      iconColor: Colors.deepPurple,
                      onTap: () {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => OnboardingPage(
                              user: user,
                              isReconfiguring: true,
                              onCompleted: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Configuración actualizada con éxito.',
                                      ),
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
