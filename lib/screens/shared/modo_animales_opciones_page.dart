import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/caregiver/manage_caregiver_profiles_page.dart';

class ModoAnimalesOpcionesPage extends StatefulWidget {
  const ModoAnimalesOpcionesPage({super.key});

  @override
  State<ModoAnimalesOpcionesPage> createState() => _ModoAnimalesOpcionesPageState();
}

class _ModoAnimalesOpcionesPageState extends State<ModoAnimalesOpcionesPage> {
  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimalActive = preferenceNotifier.isAnimalMode;
    final animalModeType = preferenceNotifier.animalModeType;

    // Filter animal profiles if any, or all managed profiles when in animal mode
    final animalProfiles = caregiverNotifier.managedProfiles.where((p) => p.isAnimal).toList();
    final displayedCount = animalProfiles.isNotEmpty
        ? animalProfiles.length
        : caregiverNotifier.managedProfiles.length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Modo Animales (Veterinaria)'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de estado con cambio a verde
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAnimalActive
                    ? [AppTheme.primaryColor, const Color(0xFF58BA8B)]
                    : [Colors.grey.shade700, Colors.grey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isAnimalActive ? AppTheme.primaryColor : Colors.black).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAnimalActive ? Icons.pets_rounded : Icons.pets_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnimalActive ? 'Modo Animales Activo' : 'Modo Animales Desactivado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnimalActive
                            ? 'Interfaz y colores verdes adaptados para el cuidado de mascotas y atención veterinaria.'
                            : 'Activa esta opción para adaptar la aplicación a la atención de mascotas o clínicas veterinarias.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isAnimalActive,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.4),
                  onChanged: (val) async {
                    await preferenceNotifier.setAnimalMode(val);
                    if (val) {
                      await caregiverNotifier.setModeType(CaregiverModeType.veterinario);
                    } else {
                      await caregiverNotifier.setModeType(CaregiverModeType.familiar);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (isAnimalActive) ...[
            Text(
              'Modalidad de Cuidado Animal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: (preferenceNotifier.showCardBorder || preferenceNotifier.highContrast)
                    ? Border.all(color: AppTheme.borderColor)
                    : null,
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text(
                      'Mascota Individual / Hogar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Para tutores de una sola mascota o animal en tratamiento doméstico en casa.',
                    ),
                    secondary: Icon(Icons.pets_rounded, color: AppTheme.primaryColor),
                    value: 'individual',
                    groupValue: animalModeType,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) {
                        preferenceNotifier.setAnimalModeType(val);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text(
                      'Clínica Veterinaria / Multi-Animales',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Para veterinarias, consultorios o refugios con múltiples animales, boxes/jaulas y fichas clínicas.',
                    ),
                    secondary: Icon(Icons.local_hospital_rounded, color: AppTheme.primaryColor),
                    value: 'veterinaria',
                    groupValue: animalModeType,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) {
                        preferenceNotifier.setAnimalModeType(val);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Notificaciones y Alertas Veterinarias',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: (preferenceNotifier.showCardBorder || preferenceNotifier.highContrast)
                    ? Border.all(color: AppTheme.borderColor)
                    : null,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Alertas de Medicamentos de Animales',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Recibir alarmas y recordatorios programados para las tomas de tus mascotas.',
                    ),
                    secondary: Icon(Icons.notifications_active_rounded, color: AppTheme.primaryColor),
                    value: caregiverNotifier.notifyPatientDoses,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      caregiverNotifier.setNotifyPatientDoses(val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      'Incluir Jaula, Box o Especie',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Muestra la jaula, box, canil o especie del animal en la notificación.',
                    ),
                    secondary: Icon(Icons.meeting_room_rounded, color: AppTheme.primaryColor),
                    value: caregiverNotifier.includeLocationInNotifications,
                    activeColor: AppTheme.primaryColor,
                    onChanged: caregiverNotifier.notifyPatientDoses
                        ? (val) {
                            caregiverNotifier.setIncludeLocationInNotifications(val);
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Gestión de Pacientes Animales',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: (preferenceNotifier.showCardBorder || preferenceNotifier.highContrast)
                    ? Border.all(color: AppTheme.borderColor)
                    : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pets_rounded, color: AppTheme.primaryColor),
                ),
                title: Text(
                  animalModeType == 'individual'
                      ? 'Ficha de la Mascota'
                      : 'Gestionar Mascotas y Pacientes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  animalModeType == 'individual'
                      ? (displayedCount > 0
                          ? '1 mascota configurada'
                          : 'Configura el perfil de tu mascota')
                      : '$displayedCount animales registrados',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageCaregiverProfilesPage(isAnimalMode: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
