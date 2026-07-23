import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/caregiver/manage_caregiver_profiles_page.dart';

class ModoCuidadorOpcionesPage extends StatelessWidget {
  const ModoCuidadorOpcionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isActive = caregiverNotifier.isCaregiverModeActive;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Modo Cuidador'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de estado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [AppTheme.primaryColor.withOpacity(0.85), AppTheme.primaryColor]
                    : [Colors.grey.shade700, Colors.grey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? AppTheme.primaryColor : Colors.black).withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.health_and_safety_rounded : Icons.shield_outlined,
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
                        isActive ? 'Modo Cuidador Activo' : 'Modo Cuidador Desactivado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActive
                            ? 'Gestiona pacientes, salas y recordatorios consolidados.'
                            : 'Activa esta opción si cuidas a familiares o en entorno clínico.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withOpacity(0.4),
                  onChanged: (val) {
                    caregiverNotifier.setCaregiverModeActive(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (isActive) ...[
            Text(
              'Perfil de Cuidador',
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
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  RadioListTile<CaregiverModeType>(
                    title: const Text('Cuidador Familiar', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Gestión de familiares directos, recordatorios y perfiles personalizados.'),
                    secondary: const Icon(Icons.family_restroom_rounded, color: AppTheme.primaryColor),
                    value: CaregiverModeType.familiar,
                    groupValue: caregiverNotifier.modeType,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) caregiverNotifier.setModeType(val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<CaregiverModeType>(
                    title: const Text('Cuidador Clínico / Hospitalario', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Incluye pisos, números de habitación/cama y tipo de sangre.'),
                    secondary: const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryColor),
                    value: CaregiverModeType.clinico,
                    groupValue: caregiverNotifier.modeType,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) caregiverNotifier.setModeType(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Notificaciones de Pacientes',
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
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notificaciones de Pacientes', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Recibir alertas programadas para las tomas de medicamentos de tus pacientes.'),
                    secondary: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryColor),
                    value: caregiverNotifier.notifyPatientDoses,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      caregiverNotifier.setNotifyPatientDoses(val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Incluir Ubicación y Habitación', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Muestra el número de habitación, cama o piso en la notificación.'),
                    secondary: const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor),
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
              'Gestión de Pacientes',
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
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AppTheme.primaryColor),
                ),
                title: const Text('Gestionar Pacientes', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${caregiverNotifier.managedProfiles.length} pacientes registrados'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageCaregiverProfilesPage()),
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
