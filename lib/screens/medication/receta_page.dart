// lib/screens/medication/receta_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:showcaseview/showcaseview.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';

class RecetaPage extends StatefulWidget {
  final GlobalKey? fabKey;
  final GlobalKey? summaryKey;
  final GlobalKey? dateKey;

  const RecetaPage({
    super.key,
    this.fabKey,
    this.summaryKey,
    this.dateKey,
  });

  @override
  State<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends State<RecetaPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  bool _esHoy(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  List<Map<String, dynamic>> _obtenerDosisDelDia(List<Tratamiento> todosLosTratamientos, DateTime date) {
    final List<Map<String, dynamic>> hoyDosis = [];
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    for (var tratamiento in todosLosTratamientos) {
      // 1. Recopilar todas las dosis explícitamente registradas en doseStatus para este día
      final List<DateTime> recordedTimes = [];
      tratamiento.doseStatus.forEach((key, status) {
        final parsedTime = DateTime.tryParse(key);
        if (parsedTime != null &&
            !parsedTime.isBefore(startOfDay) &&
            !parsedTime.isAfter(endOfDay)) {
          recordedTimes.add(parsedTime);
          hoyDosis.add({
            'tratamiento': tratamiento,
            'doseTime': parsedTime,
            'status': status,
          });
        }
      });

      recordedTimes.sort();

      // 2. Generar dosis programadas del día y agregar aquellas que no tienen registro asociado
      final dosisCalculadas = TratamientoService.generarDosisEnRango(tratamiento, startOfDay, endOfDay);
      final intervaloMinutos = tratamiento.intervaloDosis.inMinutes > 0 ? tratamiento.intervaloDosis.inMinutes : 240;
      final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);

      int recIdx = 0;
      final int recLen = recordedTimes.length;

      for (var doseTime in dosisCalculadas) {
        while (recIdx < recLen && doseTime.difference(recordedTimes[recIdx]).inMinutes > maxToleranceMinutes) {
          recIdx++;
        }

        bool isRecorded = false;
        int checkIdx = recIdx;
        while (checkIdx < recLen) {
          final diffMinutes = recordedTimes[checkIdx].difference(doseTime).inMinutes;
          if (diffMinutes.abs() <= maxToleranceMinutes) {
            isRecorded = true;
            break;
          }
          if (diffMinutes > maxToleranceMinutes) {
            break;
          }
          checkIdx++;
        }

        if (!isRecorded) {
          final key = doseTime.toIso8601String();
          final status = tratamiento.doseStatus[key] ?? DoseStatus.pendiente;
          hoyDosis.add({
            'tratamiento': tratamiento,
            'doseTime': doseTime,
            'status': status,
          });
        }
      }
    }

    hoyDosis.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
    return hoyDosis;
  }

  void _showDoseOptionsDialog(BuildContext context, Tratamiento tratamiento, DateTime doseTime, DoseStatus status) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final caregiverNotifier = Provider.of<CaregiverNotifier>(context, listen: false);
    final preferenceNotifier = Provider.of<PreferenceNotifier>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    final isAnimal = preferenceNotifier.isAnimalMode;
    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;
    final activeProfile = isManagedMode ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal) : null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Widget buildDeferOption(BuildContext ctx, int minutes, String label) {
      return InkWell(
        onTap: () => Navigator.pop(ctx, minutes),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 8,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetCtx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opciones de la Dosis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tratamiento.nombreMedicamento} • ${DateFormat('hh:mm a').format(doseTime)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 1: Main Completion Action
              if (status != DoseStatus.tomada) ...[
                InkWell(
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final inventoryResult = await firestoreService.updateDoseStatus(
                      user.uid,
                      tratamiento.id,
                      doseTime,
                      DoseStatus.tomada,
                      activeProfile,
                    );
                    if (inventoryResult?.stockBajo == true) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Stock bajo: te quedan ${inventoryResult!.dosisRestantes} dosis'),
                        ),
                      );
                    } else {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Dosis marcada como tomada.')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: AppTheme.successColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Marcar como tomada',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Descuenta del inventario automáticamente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section 2: Quick Adjustments Group
              Material(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: const Icon(Icons.close, color: Colors.red, size: 20),
                        ),
                        title: Text(
                          'Marcar como omitida',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                        ),
                        subtitle: Text(
                          'No descontará inventario pero registrará la omisión',
                          style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                        ),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          await firestoreService.updateDoseStatus(
                            user.uid,
                            tratamiento.id,
                            doseTime,
                            DoseStatus.omitida,
                            activeProfile,
                          );
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Dosis marcada como omitida.')),
                          );
                        },
                      ),
                      Divider(height: 1, color: AppTheme.borderColor),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          child: const Icon(Icons.snooze, color: Colors.orange, size: 20),
                        ),
                        title: Text(
                          'Aplazar dosis',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                        ),
                        subtitle: Text(
                          'Pospone la toma 10, 15, 30 o 60 minutos',
                          style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                        ),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          final minutes = await showModalBottomSheet<int>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => Container(
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).cardColor,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      margin: const EdgeInsets.only(bottom: 20),
                                    ),
                                  ),
                                  Text(
                                    'Aplazar dosis',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryTextColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Selecciona cuánto tiempo deseas posponer la toma:',
                                    style: TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 2.2,
                                    children: [
                                      buildDeferOption(ctx, 10, '+10 min'),
                                      buildDeferOption(ctx, 15, '+15 min'),
                                      buildDeferOption(ctx, 30, '+30 min'),
                                      buildDeferOption(ctx, 60, '+1 hora'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          );

                          if (minutes != null) {
                            final newDoseTime = doseTime.add(Duration(minutes: minutes));
                            final docRef = firestoreService.getMedicamentoDocRef(user.uid, tratamiento.id, activeProfile);
                            await FirebaseFirestore.instance.runTransaction((transaction) async {
                              final snapshot = await transaction.get(docRef);
                              if (!snapshot.exists) return;
                              final t = Tratamiento.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
                              final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
                              final oldKey = doseTime.toIso8601String();
                              updatedMap.remove(oldKey);
                              updatedMap[newDoseTime.toIso8601String()] = DoseStatus.aplazada;
                              transaction.update(docRef, {'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value))});
                            });

                            final doc = await docRef.get();
                            if (doc.exists) {
                              final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                              await NotificationService.rescheduleNextPendingDose(updatedTratamiento, user.uid, activeProfile);
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Dosis aplazada por $minutes minutos.')),
                            );
                          }
                        },
                      ),
                      Divider(height: 1, color: AppTheme.borderColor),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20),
                        ),
                        title: Text(
                          'Editar tratamiento',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                        ),
                        subtitle: Text(
                          'Modificar solo esta dosis o el tratamiento completo',
                          style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          _showEditOptionsDialog(
                            context: context,
                            tratamiento: tratamiento,
                            doseTime: doseTime,
                            activeProfile: activeProfile,
                            user: user,
                            scaffoldMessenger: scaffoldMessenger,
                            firestoreService: firestoreService,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: Destructive Action
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: AppTheme.errorColor.withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever, color: AppTheme.errorColor, size: 20),
                ),
                title: const Text(
                  'Eliminar tratamiento',
                  style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Remueve este tratamiento y todas sus alarmas',
                  style: TextStyle(fontSize: 11, color: AppTheme.errorColor),
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogCtx) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Confirmar eliminación', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                        content: const Text('¿Estás seguro de que deseas eliminar este tratamiento?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                            child: const Text('Eliminar'),
                            onPressed: () async {
                              Navigator.of(dialogCtx).pop();
                              await NotificationService.revokeTreatmentLocally(user.uid, tratamiento.id);
                              await NotificationService.cancelTreatmentAlarms(tratamiento.prescriptionAlarmId);
                              await NotificationService.cancelAllActiveAndroidNotifications();
                              await NotificationService.cancelAllFlutterLocalNotifications();
                              await firestoreService.deleteTratamiento(user.uid, tratamiento.id, activeProfile);
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(content: Text('Tratamiento eliminado.')),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditOptionsDialog({
    required BuildContext context,
    required Tratamiento tratamiento,
    required DateTime doseTime,
    CaregiverProfile? activeProfile,
    required dynamic user,
    required ScaffoldMessengerState scaffoldMessenger,
    required FirestoreService firestoreService,
  }) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetCtx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(sheetCtx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 18),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Qué deseas editar?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tratamiento.nombreMedicamento} • ${DateFormat('hh:mm a').format(doseTime)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Material(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(Icons.edit_calendar_outlined, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(
                        'Editar solo esta dosis',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Cambiar la hora programada para esta toma (${DateFormat('hh:mm a').format(doseTime)})',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(sheetCtx).pop('single_dose'),
                    ),
                    Divider(height: 1, color: AppTheme.borderColor),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withValues(alpha: 0.1),
                        child: const Icon(Icons.medication_outlined, color: Colors.purple, size: 20),
                      ),
                      title: Text(
                        'Editar tratamiento completo',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Modificar medicamento, horarios, duración e inventario',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(sheetCtx).pop('full_treatment'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (option == 'single_dose') {
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(doseTime),
      );
      if (pickedTime != null) {
        final newDoseTime = DateTime(
          doseTime.year,
          doseTime.month,
          doseTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        final docRef = firestoreService.getMedicamentoDocRef(user.uid, tratamiento.id, activeProfile);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) return;
          final t = Tratamiento.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
          final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
          final oldKey = doseTime.toIso8601String();
          final statusVal = updatedMap.remove(oldKey) ?? DoseStatus.pendiente;
          updatedMap[newDoseTime.toIso8601String()] = statusVal;
          transaction.update(docRef, {'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value))});
        });

        final doc = await docRef.get();
        if (doc.exists) {
          final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
          await NotificationService.rescheduleNextPendingDose(updatedTratamiento, user.uid, activeProfile);
        }
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Hora de la dosis modificada.')),
        );
      }
    } else if (option == 'full_treatment') {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AgregarRecetaPage(tratamientoToEdit: tratamiento),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final profile = context.watch<ProfileNotifier>();
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isModern = preferenceNotifier.interfaceStyle == 'modern';
    final user = authService.currentUser;
    final isAnimal = preferenceNotifier.isAnimalMode;
    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;
    final activeProfile = isManagedMode ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal) : null;
    final l10n = AppLocalizations.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus recetas.')),
      );
    }

    final nameParts = profile.userName?.split(' ');
    final firstName = nameParts?.first ?? 'Usuario';

    // Formatear fecha seleccionada según idioma activo
    final langCode = Localizations.localeOf(context).languageCode;
    final datePattern = langCode == 'en' ? 'EEEE, MMMM d' : "EEEE, d 'de' MMMM";
    final rawDate = DateFormat(datePattern, langCode == 'en' ? 'en_US' : 'es_ES').format(_selectedDate);
    final formattedDate = rawDate.isNotEmpty
        ? (rawDate.substring(0, 1).toUpperCase() + rawDate.substring(1))
        : rawDate;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Tratamiento>>(
        initialData: firestoreService.getCachedMedicamentos(user.uid, activeProfile),
        stream: firestoreService.getMedicamentosStream(user.uid, activeProfile),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
          }
          if (snapshot.hasError) {
            return EstadoVista(
              state: ViewState.error,
              errorMessage: 'Ocurrió un error al cargar las recetas.',
              onRetry: () => setState(() {}),
              child: const SizedBox.shrink(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EstadoVista(
              state: ViewState.empty,
              emptyMessage: 'Aún no has agregado ninguna receta. ¡Añade una para empezar!',
              child: SizedBox.shrink(),
            );
          }

          final todosLosTratamientos = snapshot.data!;
          final hoyDosis = _obtenerDosisDelDia(todosLosTratamientos, _selectedDate);

          // Calcular estadísticas del día seleccionado
          final tomadasHoy = hoyDosis.where((d) => d['status'] == DoseStatus.tomada).length;
          final pendientesHoy = hoyDosis.where((d) => d['status'] == DoseStatus.pendiente || d['status'] == DoseStatus.notificada || d['status'] == DoseStatus.aplazada).length;
          
          final now = DateTime.now();
          final dosisPasadasHoy = hoyDosis.where((d) => (d['doseTime'] as DateTime).isBefore(now)).length;
          final divisorAdherencia = dosisPasadasHoy > tomadasHoy ? dosisPasadasHoy : tomadasHoy;
          final adherenciaHoy = divisorAdherencia > 0 ? (tomadasHoy / divisorAdherencia) * 100 : 0.0;

          // Date Pill widget (Clickable)
          Widget datePill = GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('es', 'ES'),
                builder: (context, child) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: isDark
                          ? ColorScheme.dark(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.white,
                              surface: Theme.of(context).cardColor,
                              onSurface: AppTheme.primaryTextColor,
                            )
                          : ColorScheme.light(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.white,
                              surface: Theme.of(context).cardColor,
                              onSurface: AppTheme.primaryTextColor,
                            ),
                      dialogBackgroundColor: Theme.of(context).cardColor,
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != _selectedDate) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                    ? Border.all(color: AppTheme.borderColor)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppTheme.secondaryTextColor,
                  ),
                ],
              ),
            ),
          );

          // Summary Card widget (wrapped in RepaintBoundary for smooth transitions)
          Widget summaryCard = RepaintBoundary(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22004AC6),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: WavePainter(animationValue: _waveController.value),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _esHoy(_selectedDate)
                              ? (l10n?.summaryToday ?? 'Resumen de hoy')
                              : (l10n?.summaryDay ?? 'Resumen del día'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(pendientesHoy.toString(), l10n?.pendingUppercase ?? 'PENDIENTES'),
                            _buildSummaryItem(tomadasHoy.toString(), l10n?.takenUppercase ?? 'TOMADAS'),
                            _buildSummaryItem('${adherenciaHoy.toStringAsFixed(0)}%', l10n?.adherenceUppercase ?? 'ADHERENCIA'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          return ListView(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 16.0,
              bottom: isModern ? 100.0 : 16.0,
            ),
            children: [
              // Header/Saludo Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.helloUser(firstName) ?? 'Hola, $firstName',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _esHoy(_selectedDate)
                        ? (l10n?.planForToday ?? 'Aquí está tu plan para hoy')
                        : (l10n?.planForDay ?? 'Aquí está tu plan para este día'),
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date Pill (Clickable) wrapped with Showcase
                  widget.dateKey != null
                      ? Showcase.withWidget(
                          key: widget.dateKey!,
                          height: 160,
                          width: 320,
                          disableDefaultTargetGestures: true,
                          container: const TutorialTooltip(
                            icon: Icons.date_range_rounded,
                            title: 'Selector de Fechas',
                            description: 'Navega en el tiempo: toca la fecha para planificar o registrar medicamentos de días anteriores o futuros.',
                            stepNumber: 4,
                            totalSteps: 11,
                          ),
                          targetShapeBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          targetPadding: const EdgeInsets.all(4),
                          child: datePill,
                        )
                      : datePill,
                ],
              ),
              const SizedBox(height: 24),

              // Resumen de hoy Card wrapped with Showcase
              widget.summaryKey != null
                  ? Showcase.withWidget(
                      key: widget.summaryKey!,
                      height: 160,
                      width: 320,
                      disableDefaultTargetGestures: true,
                      container: const TutorialTooltip(
                        icon: Icons.assessment_rounded,
                        title: 'Resumen Diario',
                        description: 'Monitorea tu nivel de adherencia hoy y visualiza de un vistazo las dosis pendientes y tomadas del día.',
                        stepNumber: 3,
                        totalSteps: 11,
                      ),
                      targetShapeBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      targetPadding: const EdgeInsets.all(4),
                      child: summaryCard,
                    )
                  : summaryCard,
              const SizedBox(height: 32),

              // Timeline Title
              Text(
                _esHoy(_selectedDate)
                    ? (l10n?.upcomingDoses ?? 'Próximas dosis')
                    : (l10n?.dosesOfTheDay ?? 'Dosis del día'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),

              // Timeline List
              if (hoyDosis.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      _esHoy(_selectedDate)
                          ? (l10n?.noDosesToday ?? 'No tienes dosis programadas para hoy.')
                          : (l10n?.noDosesDay ?? 'No tienes dosis programadas para este día.'),
                      style: TextStyle(color: AppTheme.secondaryTextColor),
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(hoyDosis.length, (index) {
                    final dose = hoyDosis[index];
                    final isFirst = index == 0;
                    final isLast = index == hoyDosis.length - 1;
                    return _buildTimelineRow(dose, isFirst, isLast);
                  }),
                ),
            ],
          );
        },
      ),
      floatingActionButton: isModern ? null : _buildFab(context),
    );
  }

  Widget _buildSummaryItem(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> dose, bool isFirst, bool isLast) {
    final Tratamiento tratamiento = dose['tratamiento'];
    final DateTime doseTime = dose['doseTime'];
    final DoseStatus status = dose['status'];
    final timeStr = DateFormat('hh:mm a', 'es_ES').format(doseTime);

    final l10n = AppLocalizations.of(context);
    // Determinar estilo visual según el estado
    Color nodeColor = Colors.grey.shade300;
    Widget nodeWidget = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
    );
    Color chipBorderColor = const Color(0xFFC3C6D7);
    Color chipBgColor = AppTheme.surfaceColor;
    Color chipTextColor = AppTheme.secondaryTextColor;
    String statusText = l10n?.doseStatusScheduled ?? 'Programada';

    final isPast = doseTime.isBefore(DateTime.now());

    if (status == DoseStatus.tomada) {
      nodeColor = AppTheme.successColor;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
      chipBorderColor = AppTheme.successColor.withOpacity(0.3);
      chipBgColor = AppTheme.successColor.withOpacity(0.08);
      chipTextColor = AppTheme.successColor;
      statusText = l10n?.doseStatusTaken ?? 'Tomada';
    } else if (status == DoseStatus.omitida) {
      nodeColor = AppTheme.errorColor;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      );
      chipBorderColor = AppTheme.errorColor.withOpacity(0.3);
      chipBgColor = AppTheme.errorColor.withOpacity(0.08);
      chipTextColor = AppTheme.errorColor;
      statusText = l10n?.doseStatusSkipped ?? 'Omitida';
    } else if (status == DoseStatus.aplazada) {
      nodeColor = Colors.orange;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
        child: const Icon(Icons.watch_later_outlined, color: Colors.white, size: 14),
      );
      chipBorderColor = Colors.orange.withOpacity(0.3);
      chipBgColor = Colors.orange.withOpacity(0.08);
      chipTextColor = Colors.orange;
      statusText = l10n?.doseStatusSnoozed ?? 'Aplazada';
    } else if (status == DoseStatus.notificada || (status == DoseStatus.pendiente && isPast)) {
      nodeColor = Colors.amber;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.notifications, color: Colors.white, size: 14),
      );
      chipBorderColor = Colors.amber.withOpacity(0.3);
      chipBgColor = Colors.amber.withOpacity(0.08);
      chipTextColor = Colors.amber;
      statusText = l10n?.doseStatusNotified ?? 'Notificada';
    } else {
      // Futura pendiente
      nodeColor = const Color(0xFFC3C6D7);
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: nodeColor, width: 2),
        ),
      );
      chipBorderColor = const Color(0xFFC3C6D7).withOpacity(0.4);
      chipBgColor = AppTheme.surfaceColor;
      chipTextColor = AppTheme.secondaryTextColor;
      statusText = l10n?.doseStatusScheduled ?? 'Programada';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator (Left)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (isFirst)
                  const SizedBox(height: 18)
                else
                  Container(
                    width: 2,
                    height: 18,
                    color: const Color(0xFFC3C6D7).withOpacity(0.4),
                  ),
                nodeWidget,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFC3C6D7).withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Dose Card (Right)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetalleRecetaPage(
                    tratamiento: tratamiento,
                    horaDosis: doseTime,
                  )),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                        ? Border.all(color: AppTheme.borderColor)
                        : null,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: chipBgColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: chipBorderColor),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: chipTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tratamiento.nombreMedicamento,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final localizedPres = AppUtils.localizePresentation(context, tratamiento.presentacion);
                                final localizedFreq = tratamiento.intervaloDosis.inHours == 1
                                    ? (l10n?.everyHourSingle ?? 'Cada hora')
                                    : (l10n?.everyHours(tratamiento.intervaloDosis.inHours) ?? 'Cada ${tratamiento.intervaloDosis.inHours} horas');
                                return Text(
                                  '$localizedPres · $localizedFreq',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showDoseOptionsDialog(context, tratamiento, doseTime, status),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.more_vert, color: AppTheme.secondaryTextColor),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    final fab = FloatingActionButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AgregarRecetaPage()));
      },
      tooltip: 'Agregar Medicamento',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.primaryColor,
      heroTag: 'uniqueTag1',
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );

    if (widget.fabKey != null) {
      return Showcase.withWidget(
        key: widget.fabKey!,
        height: 160,
        width: 320,
        disableDefaultTargetGestures: true,
        container: const TutorialTooltip(
          icon: Icons.add_circle_outline_rounded,
          title: 'Agregar Receta o Tratamiento',
          description: 'Toca el botón + para registrar nuevos medicamentos, definir frecuencias de tomas y configurar recordatorios automáticos.',
          stepNumber: 5,
          totalSteps: 11,
        ),
        targetShapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        targetPadding: const EdgeInsets.all(4),
        child: fab,
      );
    }
    return fab;
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paint3 = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paint4 = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path1 = Path();
    final path2 = Path();
    final path3 = Path();
    final path4 = Path();

    final yOffset1 = size.height * 0.6;
    final yOffset2 = size.height * 0.45;
    final yOffset3 = size.height * 0.75;
    final yOffset4 = size.height * 0.35;

    const amplitude1 = 12.0;
    const amplitude2 = 8.0;
    const amplitude3 = 10.0;
    const amplitude4 = 6.0;

    final wavelength1 = size.width * 1.2;
    final wavelength2 = size.width * 0.9;
    final wavelength3 = size.width * 1.5;
    final wavelength4 = size.width * 0.7;

    path1.moveTo(0, yOffset1);
    path2.moveTo(0, yOffset2);
    path3.moveTo(0, yOffset3);
    path4.moveTo(0, yOffset4);

    for (double x = 0; x <= size.width; x++) {
      // First wave (moving left to right)
      final relativeX1 = x / wavelength1;
      final y1 = yOffset1 + math.sin((relativeX1 * 2 * math.pi) + (animationValue * 2 * math.pi)) * amplitude1;
      path1.lineTo(x, y1);

      // Second wave (moving right to left)
      final relativeX2 = x / wavelength2;
      final y2 = yOffset2 + math.sin((relativeX2 * 2 * math.pi) - (animationValue * 2 * math.pi) + (math.pi / 3)) * amplitude2;
      path2.lineTo(x, y2);

      // Third wave (slower / wider)
      final relativeX3 = x / wavelength3;
      final y3 = yOffset3 + math.sin((relativeX3 * 2 * math.pi) + (animationValue * 2 * math.pi) - (math.pi / 4)) * amplitude3;
      path3.lineTo(x, y3);

      // Fourth wave (faster / narrower)
      final relativeX4 = x / wavelength4;
      final y4 = yOffset4 + math.sin((relativeX4 * 2 * math.pi) - (animationValue * 4 * math.pi) + (math.pi / 6)) * amplitude4;
      path4.lineTo(x, y4);
    }

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
    canvas.drawPath(path3, paint3);
    canvas.drawPath(path4, paint4);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}