// lib/screens/medication/receta_page.dart
import 'package:meditime/widgets/medication/receta_summary_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
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
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:showcaseview/showcaseview.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart';
import 'package:meditime/widgets/container_transform_card.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/core/subscription_guard.dart';
import 'package:meditime/services/gemini_service.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/pill_icon.dart';

class RecetaPage extends StatefulWidget {
  final GlobalKey? fabKey;
  final GlobalKey? summaryKey;
  final GlobalKey? dateKey;

  const RecetaPage({super.key, this.fabKey, this.summaryKey, this.dateKey});

  @override
  State<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends State<RecetaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  List<Map<String, String>> _aiTips = [];
  bool _isLoadingAiTips = false;
  String _lastTipsCacheKey = '';

  Future<void> _fetchAiTipsIfNeeded({
    required List<Tratamiento> treatments,
    required int pendingCount,
    required int takenCount,
    required double adherenceRate,
    required bool isPremium,
    bool isAnimalMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? caregiverProfile,
    bool isCaregiverActive = false,
    String languageCode = 'es',
  }) async {
    if (!isPremium) return;

    // Fingerprint based on active treatments, profile, mode and language (invalidates if treatments, mode or language change)
    final sortedMeds =
        treatments.map((t) => '${t.id}_${t.nombreMedicamento}').toList()
          ..sort();
    final profileKey = caregiverProfile?.id ?? 'main_user';
    final modeKey =
        isAnimalMode
            ? 'animal'
            : (isCaregiverActive
                ? (caregiverModeType?.name ?? 'caregiver')
                : 'personal');
    final fingerprint =
        '${profileKey}_${modeKey}_${sortedMeds.join('|')}_${languageCode}_${DateTime.now().day}';

    // Si cambió el perfil, modo o tratamientos, limpiar tips previos para evitar mostrar datos viejos
    if (fingerprint != _lastTipsCacheKey) {
      _lastTipsCacheKey = fingerprint;
      _aiTips = [];
    } else if (_aiTips.isNotEmpty) {
      return;
    }
    if (_isLoadingAiTips) return;

    final prefService = context.read<PreferenceService>();
    final geminiService = context.read<GeminiService>();

    // 1. Check persistent disk cache first (persists across app restarts and navigation, TTL 12 hours)
    final cachedTips = await prefService.getCachedAiTips(
      currentFingerprint: fingerprint,
      maxAge: const Duration(hours: 12),
    );

    if (cachedTips != null && cachedTips.isNotEmpty) {
      if (mounted) {
        setState(() {
          _aiTips = cachedTips;
        });
      }
      return; // ZERO NETWORK REQUESTS! Reuses cached tips, saving tokens and quota!
    }

    // 2. If no cache, populate with instant clinical heuristics immediately so user never sees empty
    final fallbackTips = geminiService.getFallbackTips(
      treatments: treatments,
      pendingCount: pendingCount,
      takenCount: takenCount,
      adherenceRate: adherenceRate,
      isAnimalMode: isAnimalMode,
      caregiverModeType: caregiverModeType,
      profile: caregiverProfile,
      language: languageCode,
    );

    if (_aiTips.isEmpty && mounted) {
      setState(() {
        _aiTips = fallbackTips;
      });
    }

    // 3. Fetch fresh tips from API with strict token limits and short timeout
    _isLoadingAiTips = true;
    try {
      final freshTips = await geminiService.generateTreatmentTips(
        treatments: treatments,
        pendingCount: pendingCount,
        takenCount: takenCount,
        adherenceRate: adherenceRate,
        isAnimalMode: isAnimalMode,
        caregiverModeType: caregiverModeType,
        profile: caregiverProfile,
        language: languageCode,
      );

      if (mounted && freshTips.isNotEmpty) {
        setState(() {
          _aiTips = freshTips;
          _isLoadingAiTips = false;
        });
        // Save to persistent storage for 12 hours
        await prefService.saveCachedAiTips(
          fingerprint: fingerprint,
          tips: freshTips,
        );
      }
    } catch (e) {
      debugPrint('Error or offline fetching AI tips: $e');
      if (mounted) {
        setState(() {
          _isLoadingAiTips = false;
          if (_aiTips.isEmpty) {
            _aiTips = fallbackTips;
          }
        });
      }
    }
  }

  bool _esHoy(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  List<Map<String, dynamic>> _obtenerDosisDelDia(
    List<Tratamiento> todosLosTratamientos,
    DateTime date,
  ) {
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
      final dosisCalculadas = TratamientoService.generarDosisEnRango(
        tratamiento,
        startOfDay,
        endOfDay,
      );
      final intervaloMinutos =
          tratamiento.intervaloDosis.inMinutes > 0
              ? tratamiento.intervaloDosis.inMinutes
              : 240;
      final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);

      int recIdx = 0;
      final int recLen = recordedTimes.length;

      for (var doseTime in dosisCalculadas) {
        while (recIdx < recLen &&
            doseTime.difference(recordedTimes[recIdx]).inMinutes >
                maxToleranceMinutes) {
          recIdx++;
        }

        bool isRecorded = false;
        int checkIdx = recIdx;
        while (checkIdx < recLen) {
          final diffMinutes =
              recordedTimes[checkIdx].difference(doseTime).inMinutes;
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

    hoyDosis.sort(
      (a, b) =>
          (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime),
    );
    return hoyDosis;
  }

  void _showDoseOptionsDialog(
    BuildContext context,
    Tratamiento tratamiento,
    DateTime doseTime,
    DoseStatus status,
  ) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final caregiverNotifier = Provider.of<CaregiverNotifier>(
      context,
      listen: false,
    );
    final preferenceNotifier = Provider.of<PreferenceNotifier>(
      context,
      listen: false,
    );
    final user = authService.currentUser;
    if (user == null) return;

    final isAnimal = preferenceNotifier.isAnimalMode;
    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;
    final activeProfile =
        isManagedMode
            ? caregiverNotifier.getEffectiveActiveProfile(
              isAnimalMode: isAnimal,
            )
            : null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    Widget buildDeferOption(BuildContext ctx, int minutes, String label) {
      return InkWell(
        onTap: () => Navigator.pop(ctx, minutes),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
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
                          l10n?.doseOptionsTitle ?? 'Opciones de la Dosis',
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
                    final inventoryResult = await firestoreService
                        .updateDoseStatus(
                          user.uid,
                          tratamiento.id,
                          doseTime,
                          DoseStatus.tomada,
                          activeProfile,
                        );
                    if (inventoryResult?.stockBajo == true) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.lowStockWarning(
                                  inventoryResult!.dosisRestantes,
                                ) ??
                                'Stock bajo: te quedan ${inventoryResult!.dosisRestantes} dosis',
                          ),
                        ),
                      );
                    } else {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.doseMarkedTaken ??
                                'Dosis marcada como tomada.',
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.2),
                      ),
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
                          child: const Icon(
                            Icons.check,
                            color: AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.markAsTaken ?? 'Marcar como tomada',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n?.markAsTakenDesc ??
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.errorColor.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          l10n?.markAsSkipped ?? 'Marcar como omitida',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          l10n?.markAsSkippedDesc ??
                              'No descontará inventario pero registrará la omisión',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryTextColor,
                          ),
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
                            SnackBar(
                              content: Text(
                                l10n?.doseMarkedSkipped ??
                                    'Dosis marcada como omitida.',
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: AppTheme.borderColor),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.snooze,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          l10n?.deferDose ?? 'Aplazar dosis',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          l10n?.deferDoseDesc ??
                              'Pospone la toma 10, 15, 30 o 60 minutos',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          final minutes = await showModalBottomSheet<int>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder:
                                (ctx) => Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).cardColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 20,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        l10n?.deferDose ?? 'Aplazar dosis',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryTextColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n?.deferSelectTime ??
                                            'Selecciona cuánto tiempo deseas posponer la toma:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.secondaryTextColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      GridView.count(
                                        crossAxisCount: 2,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 2.2,
                                        children: [
                                          buildDeferOption(
                                            ctx,
                                            10,
                                            l10n?.deferPlusMinutes(10) ??
                                                '+10 min',
                                          ),
                                          buildDeferOption(
                                            ctx,
                                            15,
                                            l10n?.deferPlusMinutes(15) ??
                                                '+15 min',
                                          ),
                                          buildDeferOption(
                                            ctx,
                                            30,
                                            l10n?.deferPlusMinutes(30) ??
                                                '+30 min',
                                          ),
                                          buildDeferOption(
                                            ctx,
                                            60,
                                            l10n?.deferPlusOneHour ?? '+1 hora',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                          );

                          if (minutes != null) {
                            final newDoseTime = doseTime.add(
                              Duration(minutes: minutes),
                            );
                            final docRef = firestoreService
                                .getMedicamentoDocRef(
                                  user.uid,
                                  tratamiento.id,
                                  activeProfile,
                                );
                            await FirebaseFirestore.instance.runTransaction((
                              transaction,
                            ) async {
                              final snapshot = await transaction.get(docRef);
                              if (!snapshot.exists) return;
                              final t = Tratamiento.fromFirestore(
                                snapshot
                                    as DocumentSnapshot<Map<String, dynamic>>,
                              );
                              final updatedMap = Map<String, DoseStatus>.from(
                                t.doseStatus,
                              );
                              final oldKey = doseTime.toIso8601String();
                              updatedMap.remove(oldKey);
                              updatedMap[newDoseTime.toIso8601String()] =
                                  DoseStatus.aplazada;
                              transaction.update(docRef, {
                                'doseStatus': updatedMap.map(
                                  (k, v) => MapEntry(k, v.value),
                                ),
                              });
                            });

                            final doc = await docRef.get();
                            if (doc.exists) {
                              final updatedTratamiento =
                                  Tratamiento.fromFirestore(
                                    doc
                                        as DocumentSnapshot<
                                          Map<String, dynamic>
                                        >,
                                  );
                              await NotificationService.rescheduleNextPendingDose(
                                updatedTratamiento,
                                user.uid,
                                activeProfile,
                              );
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n?.doseDeferredMinutes(minutes) ??
                                      'Dosis aplazada por $minutes minutos.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      Divider(height: 1, color: AppTheme.borderColor),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          l10n?.editTreatment ?? 'Editar tratamiento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          l10n?.editTreatmentDesc ??
                              'Modificar solo esta dosis o el tratamiento completo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryTextColor,
                          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: AppTheme.errorColor.withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  l10n?.deleteTreatment ?? 'Eliminar tratamiento',
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  l10n?.deleteTreatmentDesc ??
                      'Remueve este tratamiento y todas sus alarmas',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.errorColor,
                  ),
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogCtx) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          l10n?.confirmDeleteTitle ?? 'Confirmar eliminación',
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          l10n?.confirmDeleteMessage ??
                              '¿Estás seguro de que deseas eliminar este tratamiento?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: Text(l10n?.cancel ?? 'Cancelar'),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                            ),
                            child: Text(l10n?.commonDelete ?? 'Eliminar'),
                            onPressed: () async {
                              Navigator.of(dialogCtx).pop();
                              await NotificationService.revokeTreatmentLocally(
                                user.uid,
                                tratamiento.id,
                              );
                              await NotificationService.cancelTreatmentAlarms(
                                tratamiento.prescriptionAlarmId,
                              );
                              await NotificationService.cancelAllActiveAndroidNotifications();
                              await NotificationService.cancelAllFlutterLocalNotifications();
                              await firestoreService.deleteTratamiento(
                                user.uid,
                                tratamiento.id,
                                activeProfile,
                              );
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n?.treatmentDeleted ??
                                        'Tratamiento eliminado.',
                                  ),
                                ),
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
    final l10n = AppLocalizations.of(context);
    final formattedDoseTime = DateFormat('hh:mm a').format(doseTime);
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (BuildContext sheetCtx) => Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetCtx).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
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
                            l10n?.whatToEdit ?? '¿Qué deseas editar?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tratamiento.nombreMedicamento} • $formattedDoseTime',
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              Icons.edit_calendar_outlined,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            l10n?.editSingleDose ?? 'Editar solo esta dosis',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            l10n?.editSingleDoseDesc(formattedDoseTime) ??
                                'Cambiar la hora programada para esta toma ($formattedDoseTime)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap:
                              () => Navigator.of(sheetCtx).pop('single_dose'),
                        ),
                        Divider(height: 1, color: AppTheme.borderColor),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              Icons.medication_outlined,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            l10n?.editFullTreatment ??
                                'Editar tratamiento completo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            l10n?.editFullTreatmentDesc ??
                                'Modificar medicamento, horarios, duración e inventario',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap:
                              () =>
                                  Navigator.of(sheetCtx).pop('full_treatment'),
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
        final docRef = firestoreService.getMedicamentoDocRef(
          user.uid,
          tratamiento.id,
          activeProfile,
        );
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) return;
          final t = Tratamiento.fromFirestore(
            snapshot as DocumentSnapshot<Map<String, dynamic>>,
          );
          final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
          final oldKey = doseTime.toIso8601String();
          final statusVal = updatedMap.remove(oldKey) ?? DoseStatus.pendiente;
          updatedMap[newDoseTime.toIso8601String()] = statusVal;
          transaction.update(docRef, {
            'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value)),
          });
        });

        final doc = await docRef.get();
        if (doc.exists) {
          final updatedTratamiento = Tratamiento.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          );
          await NotificationService.rescheduleNextPendingDose(
            updatedTratamiento,
            user.uid,
            activeProfile,
          );
        }
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n?.doseTimeChanged ?? 'Hora de la dosis modificada.',
            ),
          ),
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
    final activeProfile =
        isManagedMode
            ? caregiverNotifier.getEffectiveActiveProfile(
              isAnimalMode: isAnimal,
            )
            : null;
    final l10n = AppLocalizations.of(context);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            l10n?.loginToViewPrescriptions ??
                'Inicia sesión para ver tus recetas.',
          ),
        ),
      );
    }

    final nameParts = profile.userName?.split(' ');
    final firstName = nameParts?.first ?? 'Usuario';

    // Formatear fecha seleccionada según idioma activo
    final langCode = Localizations.localeOf(context).languageCode;
    final datePattern = langCode == 'en' ? 'EEEE, MMMM d' : "EEEE, d 'de' MMMM";
    final localeString =
        langCode == 'en' ? 'en_US' : (langCode == 'pt' ? 'pt_BR' : 'es_ES');
    final rawDate = DateFormat(datePattern, localeString).format(_selectedDate);
    final formattedDate =
        rawDate.isNotEmpty
            ? (rawDate.substring(0, 1).toUpperCase() + rawDate.substring(1))
            : rawDate;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Tratamiento>>(
        initialData: firestoreService.getCachedMedicamentos(
          user.uid,
          activeProfile,
        ),
        stream: firestoreService.getMedicamentosStream(user.uid, activeProfile),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const EstadoVista(
              state: ViewState.loading,
              child: SizedBox.shrink(),
            );
          }
          if (snapshot.hasError) {
            debugPrint("Error loading recetas stream: ${snapshot.error}");
            return EstadoVista(
              state: ViewState.error,
              errorMessage:
                  l10n?.errorLoadingPrescriptions ??
                  'Ocurrió un error al cargar las recetas.',
              onRetry: () async {
                firestoreService.clearMedicamentosCache(
                  user.uid,
                  activeProfile,
                );
                if (activeProfile != null &&
                    activeProfile.isExternalUser &&
                    activeProfile.linkedUid != null) {
                  await firestoreService.ensureCaregiverLink(
                    user.uid,
                    activeProfile.linkedUid!,
                  );
                }
                if (mounted) setState(() {});
              },
              child: const SizedBox.shrink(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return EstadoVista(
              state: ViewState.empty,
              emptyMessage:
                  l10n?.noPrescriptionsYet ??
                  'Aún no has agregado ninguna receta. ¡Añade una para empezar!',
              child: const SizedBox.shrink(),
            );
          }

          final todosLosTratamientos = snapshot.data!;
          final hoyDosis = _obtenerDosisDelDia(
            todosLosTratamientos,
            _selectedDate,
          );

          // Calcular estadísticas del día seleccionado
          final tomadasHoy =
              hoyDosis.where((d) => d['status'] == DoseStatus.tomada).length;
          final pendientesHoy =
              hoyDosis
                  .where(
                    (d) =>
                        d['status'] == DoseStatus.pendiente ||
                        d['status'] == DoseStatus.notificada ||
                        d['status'] == DoseStatus.aplazada,
                  )
                  .length;

          final now = DateTime.now();
          final dosisPasadasHoy =
              hoyDosis
                  .where((d) => (d['doseTime'] as DateTime).isBefore(now))
                  .length;
          final divisorAdherencia =
              dosisPasadasHoy > tomadasHoy ? dosisPasadasHoy : tomadasHoy;
          final adherenciaHoy =
              divisorAdherencia > 0
                  ? (tomadasHoy / divisorAdherencia) * 100
                  : 0.0;

          // Date Pill widget (Clickable)
          Widget datePill = GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: Localizations.localeOf(context),
                builder: (context, child) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme:
                          isDark
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
                      dialogTheme: DialogThemeData(
                        backgroundColor: Theme.of(context).cardColor,
                      ),
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
                border:
                    (context.watch<PreferenceNotifier>().showCardBorder ||
                            context.watch<PreferenceNotifier>().highContrast)
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

          // Filtrar estrictamente solo tratamientos activos (excluyendo historial médico y finalizados)
          final tratamientosActivos =
              todosLosTratamientos.where((t) => t.isActivo).toList();
          final tratamientosVigentes =
              tratamientosActivos.isNotEmpty
                  ? tratamientosActivos
                  : todosLosTratamientos.where((t) => !t.isFinalizado).toList();

          final isPremium = context.watch<SubscriptionNotifier>().isPremium;
          if (isPremium) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchAiTipsIfNeeded(
                treatments: tratamientosVigentes,
                pendingCount: pendientesHoy,
                takenCount: tomadasHoy,
                adherenceRate: adherenciaHoy,
                isPremium: isPremium,
                isAnimalMode: isAnimal,
                caregiverModeType: caregiverNotifier.modeType,
                caregiverProfile: activeProfile,
                isCaregiverActive: caregiverNotifier.isCaregiverModeActive,
                languageCode: langCode,
              );
            });
          }

          final effectiveTips =
              _aiTips.isNotEmpty
                  ? _aiTips
                  : context.read<GeminiService>().getFallbackTips(
                    treatments: tratamientosVigentes,
                    pendingCount: pendientesHoy,
                    takenCount: tomadasHoy,
                    adherenceRate: adherenciaHoy,
                    isAnimalMode: isAnimal,
                    caregiverModeType: caregiverNotifier.modeType,
                    profile: activeProfile,
                    language: langCode,
                  );

          final Widget summaryCard = _RecetaSummaryCard(
            key: const PageStorageKey('receta_summary_card'),
            selectedDate: _selectedDate,
            pendientesHoy: pendientesHoy,
            tomadasHoy: tomadasHoy,
            adherenciaHoy: adherenciaHoy,
            isPremium: isPremium,
            effectiveTips: effectiveTips,
            l10n: l10n,
          );

          return ModernContentFade(
            height: 28,
            child: ListView(
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
                          : (l10n?.planForDay ??
                              'Aquí está tu plan para este día'),
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
                          container: TutorialTooltip(
                            icon: Icons.date_range_rounded,
                            title:
                                l10n?.tutorialStep4Title ??
                                'Selector de Fechas',
                            description:
                                l10n?.tutorialStep4Desc ??
                                'Navega en el tiempo: toca la fecha para planificar o registrar medicamentos de días anteriores o futuros.',
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
                      container: TutorialTooltip(
                        icon: Icons.assessment_rounded,
                        title: l10n?.tutorialStep3Title ?? 'Resumen Diario',
                        description:
                            l10n?.tutorialStep3Desc ??
                            'Monitorea tu nivel de adherencia hoy y visualiza de un vistazo las dosis pendientes y tomadas del día.',
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
                            ? (l10n?.noDosesToday ??
                                'No tienes dosis programadas para hoy.')
                            : (l10n?.noDosesDay ??
                                'No tienes dosis programadas para este día.'),
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
                      return _buildTimelineRow(
                        dose,
                        isFirst,
                        isLast,
                        activeProfile,
                      );
                    }),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isModern ? null : _buildFab(context),
    );
  }

  Widget _buildTimelineRow(
    Map<String, dynamic> dose,
    bool isFirst,
    bool isLast, [
    CaregiverProfile? activeProfile,
  ]) {
    final Tratamiento tratamiento = dose['tratamiento'];
    final DateTime doseTime = dose['doseTime'];
    final DoseStatus status = dose['status'];
    final timeStr = DateFormat(
      'hh:mm a',
      Localizations.localeOf(context).toString(),
    ).format(doseTime);

    final l10n = AppLocalizations.of(context);
    // Determinar estilo visual según el estado
    Color nodeColor = Colors.grey.shade300;
    Widget nodeWidget = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
    );
    final isPast = doseTime.isBefore(DateTime.now());

    if (status == DoseStatus.tomada) {
      nodeColor = AppTheme.successColor;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    } else if (status == DoseStatus.omitida) {
      nodeColor = AppTheme.errorColor;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      );
    } else if (status == DoseStatus.aplazada) {
      nodeColor = Colors.orange;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange,
        ),
        child: const Icon(
          Icons.watch_later_outlined,
          color: Colors.white,
          size: 14,
        ),
      );
    } else if (status == DoseStatus.notificada ||
        (status == DoseStatus.pendiente && isPast)) {
      nodeColor = Colors.amber;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.notifications, color: Colors.white, size: 14),
      );
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
                  const SizedBox(height: 22)
                else
                  Container(
                    width: 2,
                    height: 22,
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                  ),
                nodeWidget,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Dose Card (Right)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ContainerTransformCard<void>(
                openBuilder:
                    (context, _) => DetalleRecetaPage(
                      tratamiento: tratamiento,
                      horaDosis: doseTime,
                      profile: activeProfile,
                    ),
                closedBuilder: (context, openContainer) {
                  final localizedPres = AppUtils.localizePresentation(
                    context,
                    tratamiento.presentacion,
                  );
                  final dosePresentationText =
                      tratamiento.dosisPorToma > 0
                          ? '${tratamiento.dosisPorToma} $localizedPres'
                          : localizedPres;
                  final localizedFreq =
                      tratamiento.intervaloDosis.inHours == 1
                          ? (l10n?.everyHourSingle ?? 'Cada hora')
                          : (l10n?.everyHours(
                                tratamiento.intervaloDosis.inHours,
                              ) ??
                              'Cada ${tratamiento.intervaloDosis.inHours} horas');

                  return InkWell(
                    onTap: openContainer,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 20,
                        top: 22,
                        bottom: 22,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left Column: Time & Frequency
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    localizedFreq,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Subtle Vertical Divider
                          Container(
                            height: 42,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: AppTheme.secondaryTextColor.withValues(
                              alpha: 0.18,
                            ),
                          ),

                          // Right Column: Medication Name & Presentation
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tratamiento.nombreMedicamento,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PillIcon(
                                      size: 13,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        dosePresentationText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Three-dot Options Menu
                          GestureDetector(
                            onTap:
                                () => _showDoseOptionsDialog(
                                  context,
                                  tratamiento,
                                  doseTime,
                                  status,
                                ),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                right: 6.0,
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fab = FloatingActionButton(
      onPressed: () async {
        final canProceed = await SubscriptionGuard.canAddTreatment(context);
        if (!canProceed || !context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AgregarRecetaPage()),
        );
      },
      tooltip: l10n?.tutorialStep5Title ?? 'Agregar Medicamento',
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
        container: TutorialTooltip(
          icon: Icons.add_circle_outline_rounded,
          title: l10n?.tutorialStep5Title ?? 'Agregar Receta o Tratamiento',
          description:
              l10n?.tutorialStep5Desc ??
              'Toca el botón + para registrar nuevos medicamentos, definir frecuencias de tomas y configurar recordatorios automáticos.',
          stepNumber: 5,
          totalSteps: 11,
        ),
        targetShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        targetPadding: const EdgeInsets.all(4),
        child: fab,
      );
    }
    return fab;
  }
}

// Typedefs para mantener compatibilidad interna tras modularización
typedef _RecetaSummaryCard = RecetaSummaryCard;
