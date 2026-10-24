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

class ModoAnimalesOpcionesPage extends StatefulWidget {
  const ModoAnimalesOpcionesPage({super.key});

  @override
  State<ModoAnimalesOpcionesPage> createState() => _ModoAnimalesOpcionesPageState();
}

class _ModoAnimalesOpcionesPageState extends State<ModoAnimalesOpcionesPage> {
  static const Color _animalAccent = Color(0xFF389E6A);

  Future<void> _toggleAnimalMode(
    BuildContext context,
    PreferenceNotifier preferenceNotifier,
    CaregiverNotifier caregiverNotifier,
    bool val,
    String animalModeType,
  ) async {
    if (val) {
      final canProceed = await SubscriptionGuard.canActivateAnimalMode(context);
      if (!canProceed || !context.mounted) return;

      final hadCaregiverMode = caregiverNotifier.isCaregiverModeActive;
      if (hadCaregiverMode) {
        await caregiverNotifier.setCaregiverModeActive(false);
      }

      // manageAlarms: false porque caregiverNotifier.onAnimalModeToggled(true)
      // gestiona la desactivación/activación usando la caché de perfiles.
      await preferenceNotifier.setAnimalMode(true, manageAlarms: false);
      await caregiverNotifier.setModeType(CaregiverModeType.veterinario);
      caregiverNotifier.ensureActiveProfileForMode(
        isAnimalMode: true,
        animalModeType: animalModeType,
      );
      await caregiverNotifier.onAnimalModeToggled(true);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                hadCaregiverMode
                    ? 'Modo Animales activado (Modo Cuidador desactivado).'
                    : 'Modo Animales activado.',
              ),
              backgroundColor: _animalAccent,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } else {
      await preferenceNotifier.setAnimalMode(false, manageAlarms: false);
      await caregiverNotifier.setModeType(CaregiverModeType.familiar);
      caregiverNotifier.clearActiveProfile();
      await caregiverNotifier.onAnimalModeToggled(false);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Modo Animales desactivado.'),
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
    final isAnimalActive = preferenceNotifier.isAnimalMode;
    final animalModeType = preferenceNotifier.animalModeType;

    // Contar estrictamente perfiles de animales para no mezclar con pacientes humanos
    final animalProfilesCount =
        caregiverNotifier.managedProfiles.where((p) => p.isAnimal).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Modo Animales (Veterinaria)'),
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
              title: 'Activar Modo Animales (Veterinaria)',
              description:
                  'Adapta la interfaz, recordatorios y fichas para mascotas del hogar o pacientes veterinarios.',
              icon: Icons.pets_rounded,
              activeColor: _animalAccent,
              value: isAnimalActive,
              onChanged: (val) => _toggleAnimalMode(
                context,
                preferenceNotifier,
                caregiverNotifier,
                val,
                animalModeType,
              ),
            ),

            if (!isAnimalActive)
              _buildInactiveFeatureOverview(
                context,
                preferenceNotifier,
                caregiverNotifier,
                animalModeType,
              ),

            if (isAnimalActive) ...[
              const SettingsSectionHeader(
                title: 'Modalidad de Cuidado Animal',
                topPadding: 0,
              ),
              SettingsRadioOptionCard(
                title: 'Mascota Individual / Hogar',
                subtitle:
                    'Para tutores de mascotas en tratamiento doméstico (ficha simplificada con especie, raza y peso).',
                icon: Icons.home_rounded,
                color: _animalAccent,
                isSelected: animalModeType == 'individual',
                onTap: () async {
                  await preferenceNotifier.setAnimalModeType('individual');
                  caregiverNotifier.ensureActiveProfileForMode(
                    isAnimalMode: true,
                    animalModeType: 'individual',
                  );
                },
              ),
              SettingsRadioOptionCard(
                title: 'Clínica Veterinaria / Multi-Animales',
                subtitle:
                    'Para veterinarias, hospitalización o refugios con múltiples animales, jaulas/boxes y microchip.',
                icon: Icons.local_hospital_rounded,
                color: _animalAccent,
                isSelected: animalModeType == 'veterinaria',
                onTap: () async {
                  await preferenceNotifier.setAnimalModeType('veterinaria');
                  caregiverNotifier.ensureActiveProfileForMode(
                    isAnimalMode: true,
                    animalModeType: 'veterinaria',
                  );
                },
              ),

              const SettingsSectionHeader(
                title: 'Notificaciones y Alertas Veterinarias',
                topPadding: 12,
              ),
              SettingsSwitchTileCard(
                title: 'Alertas de medicamentos de animales',
                description:
                    'Recibir alarmas y recordatorios programados para las tomas de tus mascotas o pacientes veterinarios.',
                value: caregiverNotifier.notifyPatientDoses,
                icon: Icons.notifications_active_rounded,
                activeColor: _animalAccent,
                onChanged: (val) => caregiverNotifier.setNotifyPatientDoses(val),
              ),
              SettingsSwitchTileCard(
                title: 'Incluir jaula, box o especie en la alerta',
                description:
                    'Muestra la ubicación (jaula, canil, box) o la especie del animal directamente en la notificación.',
                value: caregiverNotifier.includeLocationInNotifications,
                enabled: caregiverNotifier.notifyPatientDoses,
                icon: Icons.meeting_room_rounded,
                activeColor: _animalAccent,
                onChanged: (val) => caregiverNotifier.setIncludeLocationInNotifications(val),
              ),

              const SettingsSectionHeader(
                title: 'Fichas de Mascotas y Pacientes',
                topPadding: 12,
              ),
              SettingsActionTileCard(
                title: animalModeType == 'individual'
                    ? 'Ficha de tu Mascota'
                    : 'Gestionar Mascotas y Pacientes',
                subtitle: animalModeType == 'individual'
                    ? (animalProfilesCount > 0
                        ? '$animalProfilesCount mascota(s) configurada(s) en tu cuenta.'
                        : 'Crea la ficha de tu mascota para registrar sus medicamentos.')
                    : (animalProfilesCount == 1
                        ? '1 animal registrado en tu directorio veterinario.'
                        : '$animalProfilesCount animales registrados en tu directorio veterinario.'),
                icon: Icons.pets_rounded,
                iconColor: _animalAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ManageCaregiverProfilesPage(isAnimalMode: true),
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
    String animalModeType,
  ) {
    return SettingsCardWrapper(
      title: '¿Qué incluye el Modo Animales?',
      subtitle: 'Pensado tanto para tutores de mascotas en casa como para clínicas veterinarias.',
      child: Column(
        children: [
          _buildFeatureBullet(
            icon: Icons.pets_rounded,
            title: 'Fichas adaptadas por especie, raza y peso',
            subtitle: 'Registra perros, gatos, aves, exóticos y lleva el control exacto de sus dosis por peso.',
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            icon: Icons.palette_outlined,
            title: 'Tema visual verde veterinario',
            subtitle: 'La interfaz se transforma con iconografía y acentos verdes para distinguirla al instante.',
          ),
          const SizedBox(height: 12),
          _buildFeatureBullet(
            icon: Icons.local_hospital_outlined,
            title: 'Modo Hogar o Clínica Veterinaria',
            subtitle: 'Elige entre una vista simple para tu mascota o gestión multi-animal con jaulas y boxes.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _toggleAnimalMode(
                context,
                preferenceNotifier,
                caregiverNotifier,
                true,
                animalModeType,
              ),
              icon: const Icon(Icons.pets_rounded, size: 20),
              label: const Text(
                'Activar Modo Animales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _animalAccent,
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
            color: _animalAccent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _animalAccent, size: 18),
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
