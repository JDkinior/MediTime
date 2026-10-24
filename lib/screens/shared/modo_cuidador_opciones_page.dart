import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/caregiver/manage_caregiver_profiles_page.dart';
import 'package:meditime/core/subscription_guard.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';

class ModoCuidadorOpcionesPage extends StatelessWidget {
  const ModoCuidadorOpcionesPage({super.key});

  static const Color _caregiverAccent = Color(0xFF8B62D4);

  Future<void> _toggleCaregiverMode(
    BuildContext context,
    PreferenceNotifier preferenceNotifier,
    CaregiverNotifier caregiverNotifier,
    bool val,
  ) async {
    if (val) {
      final canProceed = await SubscriptionGuard.canActivateCaregiverMode(context);
      if (!canProceed || !context.mounted) return;

      final hadAnimalMode = preferenceNotifier.isAnimalMode;
      if (hadAnimalMode) {
        await preferenceNotifier.setAnimalMode(false);
      }
      if (caregiverNotifier.modeType == CaregiverModeType.veterinario) {
        await caregiverNotifier.setModeType(CaregiverModeType.familiar);
      }
      await caregiverNotifier.setCaregiverModeActive(true);
      caregiverNotifier.ensureActiveProfileForMode(isAnimalMode: false);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                hadAnimalMode
                    ? 'Modo Cuidador activado (Modo Animales desactivado).'
                    : 'Modo Cuidador activado.',
              ),
              backgroundColor: _caregiverAccent,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } else {
      await caregiverNotifier.setCaregiverModeActive(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Modo Cuidador desactivado.'),
              duration: Duration(seconds: 2),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isActive = caregiverNotifier.isCaregiverModeActive;
    final humanPatientsCount =
        caregiverNotifier.managedProfiles.where((p) => !p.isAnimal).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Modo Cuidador'),
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
            SettingsSwitchTileCard(
              title: 'Activar Modo Cuidador',
              description:
                  'Habilita la gestión multi-perfil y recordatorios consolidados para familiares o pacientes.',
              icon: Icons.health_and_safety_rounded,
              activeColor: _caregiverAccent,
              value: isActive,
              onChanged: (val) => _toggleCaregiverMode(
                context,
                preferenceNotifier,
                caregiverNotifier,
                val,
              ),
            ),

            if (!isActive)
              _buildInactiveFeatureOverview(
                context,
                preferenceNotifier,
                caregiverNotifier,
              ),

            if (isActive) ...[
              const SettingsSectionHeader(
                title: 'Modalidad de Cuidado',
                topPadding: 0,
              ),
              SettingsRadioOptionCard(
                title: 'Cuidador Familiar',
                subtitle:
                    'Ideal para organizar las tomas de padres, hijos, abuelos u otros familiares en casa.',
                icon: Icons.family_restroom_rounded,
                color: _caregiverAccent,
                isSelected: caregiverNotifier.modeType == CaregiverModeType.familiar,
                onTap: () => caregiverNotifier.setModeType(CaregiverModeType.familiar),
              ),
              SettingsRadioOptionCard(
                title: 'Cuidador Clínico / Hospitalario',
                subtitle:
                    'Habilita campos clínicos adicionales como piso, número de habitación/cama y grupo sanguíneo.',
                icon: Icons.local_hospital_rounded,
                color: _caregiverAccent,
                isSelected: caregiverNotifier.modeType == CaregiverModeType.clinico,
                onTap: () => caregiverNotifier.setModeType(CaregiverModeType.clinico),
              ),

              const SettingsSectionHeader(
                title: 'Alertas y Notificaciones de Pacientes',
                topPadding: 12,
              ),
              SettingsSwitchTileCard(
                title: 'Recibir alertas de tomas de pacientes',
                description:
                    'Activa las alarmas y notificaciones programadas para los tratamientos de todos tus pacientes gestionados.',
                value: caregiverNotifier.notifyPatientDoses,
                icon: Icons.notifications_active_rounded,
                activeColor: _caregiverAccent,
                onChanged: (val) => caregiverNotifier.setNotifyPatientDoses(val),
              ),
              SettingsSwitchTileCard(
                title: 'Mostrar habitación y ubicación en avisos',
                description:
                    'Incluye el número de habitación, cama o piso del paciente directamente en el texto de la alerta.',
                value: caregiverNotifier.includeLocationInNotifications,
                enabled: caregiverNotifier.notifyPatientDoses,
                icon: Icons.location_on_rounded,
                activeColor: _caregiverAccent,
                onChanged: (val) => caregiverNotifier.setIncludeLocationInNotifications(val),
              ),

              const SettingsSectionHeader(
                title: 'Directorio de Pacientes',
                topPadding: 12,
              ),
              SettingsActionTileCard(
                title: 'Gestionar Pacientes',
                subtitle: humanPatientsCount == 1
                    ? '1 paciente registrado en tu directorio.'
                    : '$humanPatientsCount pacientes registrados en tu directorio.',
                icon: Icons.people_alt_rounded,
                iconColor: _caregiverAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageCaregiverProfilesPage(
                        isAnimalMode: false,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveFeatureOverview(
    BuildContext context,
    PreferenceNotifier preferenceNotifier,
    CaregiverNotifier caregiverNotifier,
  ) {
    return SettingsCardWrapper(
      title: '¿Qué incluye el Modo Cuidador?',
      subtitle: 'Diseñado para familiares y profesionales de enfermería o geriatría.',
      child: Column(
        children: [
          _buildFeatureBullet(
            icon: Icons.switch_account_rounded,
            title: 'Selector rápido de paciente en Inicio',
            subtitle: 'Cambia entre los tratamientos de cada familiar o paciente con un solo toque.',
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            icon: Icons.notifications_active_rounded,
            title: 'Alarmas identificadas por paciente',
            subtitle: 'Cada recordatorio indica claramente a quién corresponde la dosis y su habitación.',
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Perfiles locales o vinculados por invitación',
            subtitle: 'Crea fichas en tu teléfono o sincroniza en tiempo real con la cuenta del paciente.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _toggleCaregiverMode(
                context,
                preferenceNotifier,
                caregiverNotifier,
                true,
              ),
              icon: const Icon(Icons.health_and_safety_rounded, size: 20),
              label: const Text(
                'Activar Modo Cuidador',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _caregiverAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _caregiverAccent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _caregiverAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
