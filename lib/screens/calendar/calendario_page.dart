import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/screens/shared/localizador_farmacias_page.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:intl/intl.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:meditime/screens/medication/agregar_receta_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class CalendarioPage extends StatefulWidget {
  final GlobalKey? calendarKey;
  final GlobalKey? calendarViewKey;

  const CalendarioPage({
    super.key,
    this.calendarKey,
    this.calendarViewKey,
  });

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Stream<List<Map<String, dynamic>>>? _combinedStream;
  List<CaregiverProfile>? _lastProfiles;
  bool _lastIsGeneral = false;
  String? _lastActiveProfileId;
  String? _lastUserId;

  void _updateStreamIfNeeded(String userId, bool isGeneral, List<CaregiverProfile> profiles, CaregiverProfile? activeProfile, FirestoreService firestoreService) {
    final activeProfileId = activeProfile?.id;
    if (_combinedStream != null &&
        _lastUserId == userId &&
        _lastIsGeneral == isGeneral &&
        _lastActiveProfileId == activeProfileId &&
        _lastProfiles != null &&
        _lastProfiles!.length == profiles.length) {
      bool same = true;
      for (int i = 0; i < profiles.length; i++) {
        if (_lastProfiles![i].id != profiles[i].id) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    _lastUserId = userId;
    _lastIsGeneral = isGeneral;
    _lastActiveProfileId = activeProfileId;
    _lastProfiles = List.from(profiles);

    if (!isGeneral) {
      _combinedStream = firestoreService.getMedicamentosStream(userId, activeProfile).map((tratamientos) {
        return tratamientos.map((t) => {'tratamiento': t, 'profile': activeProfile}).toList();
      });
      return;
    }

    if (profiles.isEmpty) {
      _combinedStream = Stream.value([]);
      return;
    }

    List<Stream<List<Map<String, dynamic>>>> streams = profiles.map((profile) {
      return firestoreService.getMedicamentosStream(userId, profile).map((tratamientos) {
        return tratamientos.map((t) => {'tratamiento': t, 'profile': profile}).toList();
      });
    }).toList();

    _combinedStream = _combineLatest(streams).map((listOfLists) {
      return listOfLists.expand((list) => list).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final user = authService.currentUser;
    final isAnimal = preferenceNotifier.isAnimalMode;
    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;
    final isGeneralMode = isManagedMode && caregiverNotifier.isGeneralMode;
    final activeProfile = isManagedMode ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal) : null;
    final profiles = isAnimal
        ? caregiverNotifier.managedProfiles.where((p) => p.isAnimal).toList()
        : caregiverNotifier.managedProfiles.where((p) => !p.isAnimal).toList();

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: Text('Inicia sesión para ver el calendario.')),
      );
    }

    _updateStreamIfNeeded(user.uid, isGeneralMode, profiles, activeProfile, firestoreService);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey('${isGeneralMode}_${activeProfile?.id}_$isManagedMode'),
        initialData: !isGeneralMode
            ? firestoreService.getCachedMedicamentos(user.uid, activeProfile)?.map((t) => {'tratamiento': t, 'profile': activeProfile}).toList()
            : null,
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
          }
          if (snapshot.hasError) {
            return const EstadoVista(
              state: ViewState.error,
              errorMessage: 'No se pudieron cargar los datos.',
              child: SizedBox.shrink(),
            );
          }

          final items = snapshot.data ?? [];
          return _CalendarioContenido(
            tratamientosItems: items,
            userId: user.uid,
            calendarKey: widget.calendarKey,
            calendarViewKey: widget.calendarViewKey,
          );
        },
      ),
    );
  }
}


class _CalendarioContenido extends StatefulWidget {
  final List<Map<String, dynamic>> tratamientosItems;
  final String userId;
  final GlobalKey? calendarKey;
  final GlobalKey? calendarViewKey;

  const _CalendarioContenido({
    required this.tratamientosItems,
    required this.userId,
    this.calendarKey,
    this.calendarViewKey,
  });

  @override
  State<_CalendarioContenido> createState() => _CalendarioContenidoState();
}

class _CalendarioContenidoState extends State<_CalendarioContenido> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Animation<double>? _secondaryAnimation;

  final Map<DateTime, Map<String, List<Map<String, dynamic>>>> _dayCache = {};
  final Set<DateTime> _populatedMonths = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _populateCacheForMonth(_focusedDay);
    _loadCalendarFormatSetting();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newAnim = ModalRoute.of(context)?.secondaryAnimation;
    if (newAnim != _secondaryAnimation) {
      _secondaryAnimation?.removeStatusListener(_onAnimationStatusChanged);
      _secondaryAnimation = newAnim;
      _secondaryAnimation?.addStatusListener(_onAnimationStatusChanged);
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _loadCalendarFormatSetting();
    }
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  Future<void> _loadCalendarFormatSetting() async {
    final preferenceService = context.read<PreferenceService>();
    final formatStr = await preferenceService.getCalendarFormat();
    if (mounted) {
      setState(() {
        if (formatStr == 'weekly') {
          _calendarFormat = CalendarFormat.week;
        } else if (formatStr == 'biweekly') {
          _calendarFormat = CalendarFormat.twoWeeks;
        } else if (formatStr == 'monthly') {
          _calendarFormat = CalendarFormat.month;
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _CalendarioContenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tratamientosItems != widget.tratamientosItems) {
      _dayCache.clear();
      _populatedMonths.clear();
      _populateCacheForMonth(_focusedDay);
    }
  }

  void _populateCacheForMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month, 1);
    if (_populatedMonths.contains(monthKey)) {
      return;
    }
    _populatedMonths.add(monthKey);

    final firstDayOfMonth = DateTime(month.year, month.month, 1, 0, 0, 0);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);

    for (var item in widget.tratamientosItems) {
      final Tratamiento tratamiento = item['tratamiento'];
      final CaregiverProfile? profile = item['profile'];
      final cacheKey = "${tratamiento.id}_${profile?.id ?? 'self'}";

      // 1. Recopilar todas las dosis explícitamente registradas en doseStatus para este mes
      final List<DateTime> recordedTimes = [];
      tratamiento.doseStatus.forEach((dateString, status) {
        final parsedTime = DateTime.tryParse(dateString);
        if (parsedTime != null &&
            !parsedTime.isBefore(firstDayOfMonth) &&
            !parsedTime.isAfter(lastDayOfMonth)) {
          recordedTimes.add(parsedTime);
          final dayKey = DateTime(parsedTime.year, parsedTime.month, parsedTime.day);

          _dayCache.putIfAbsent(dayKey, () => {});
          final treatmentMap = _dayCache[dayKey]!;

          treatmentMap.putIfAbsent(cacheKey, () => []);
          treatmentMap[cacheKey]!.add({
            'tratamiento': tratamiento,
            'profile': profile,
            'doseTime': parsedTime,
            'status': status,
          });
        }
      });

      recordedTimes.sort();

      // 2. Generar dosis programadas del mes y agregar aquellas que no tienen registro asociado
      final dosisCalculadas = TratamientoService.generarDosisEnRango(tratamiento, firstDayOfMonth, lastDayOfMonth);
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
          final dayKey = DateTime(doseTime.year, doseTime.month, doseTime.day);

          _dayCache.putIfAbsent(dayKey, () => {});
          final treatmentMap = _dayCache[dayKey]!;

          treatmentMap.putIfAbsent(cacheKey, () => []);
          treatmentMap[cacheKey]!.add({
            'tratamiento': tratamiento,
            'profile': profile,
            'doseTime': doseTime,
            'status': status,
          });
        }
      }
    }

    _dayCache.forEach((day, treatmentMap) {
      if (day.year == month.year && day.month == month.month) {
        for (var doseList in treatmentMap.values) {
          doseList.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
        }
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  Map<String, List<Map<String, dynamic>>> _getGroupedDosesForDay(DateTime day) {
    final monthKey = DateTime(day.year, day.month, 1);
    if (!_populatedMonths.contains(monthKey)) {
      _populateCacheForMonth(day);
    }
    final dayKey = DateTime(day.year, day.month, day.day);
    return _dayCache[dayKey] ?? {};
  }

  List<Map<String, dynamic>> _obtenerDosisDelDia(DateTime day) {
    final groupedDoses = _getGroupedDosesForDay(day);
    final List<Map<String, dynamic>> flatDoses = [];

    groupedDoses.forEach((key, list) {
      for (var dose in list) {
        flatDoses.add(dose);
      }
    });

    flatDoses.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
    return flatDoses;
  }

  Color _determineDayColor(Map<String, List<Map<String, dynamic>>> dosesForDay) {
    if (dosesForDay.isEmpty) return Colors.transparent;

    final now = DateTime.now();
    final allDoses = dosesForDay.values.expand((d) => d).toList();

    bool hasNotificada = allDoses.any((d) {
      final DoseStatus s = d['status'];
      final DateTime dt = d['doseTime'];
      return s == DoseStatus.notificada || (s == DoseStatus.pendiente && dt.isBefore(now));
    });

    if (hasNotificada) {
      return Colors.amber.shade600;
    } else if (allDoses.any((d) => d['status'] == DoseStatus.omitida)) {
      return AppTheme.errorColor;
    } else if (allDoses.every((d) => d['status'] == DoseStatus.tomada)) {
      return AppTheme.successColor;
    } else {
      return AppTheme.primaryColor;
    }
  }

  void _showDoseOptionsDialog(BuildContext context, Tratamiento tratamiento, CaregiverProfile? profile, DateTime doseTime, DoseStatus status) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
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
                      widget.userId,
                      tratamiento.id,
                      doseTime,
                      DoseStatus.tomada,
                      profile,
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
                            widget.userId,
                            tratamiento.id,
                            doseTime,
                            DoseStatus.omitida,
                            profile,
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
                            final docRef = firestoreService.getMedicamentoDocRef(widget.userId, tratamiento.id, profile);
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
                              await NotificationService.rescheduleNextPendingDose(updatedTratamiento, widget.userId, profile);
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
                            profile: profile,
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
                              await NotificationService.revokeTreatmentLocally(widget.userId, tratamiento.id);
                              await NotificationService.cancelTreatmentAlarms(tratamiento.prescriptionAlarmId);
                              await NotificationService.cancelAllActiveAndroidNotifications();
                              await NotificationService.cancelAllFlutterLocalNotifications();
                              await firestoreService.deleteTratamiento(widget.userId, tratamiento.id, profile);
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
    CaregiverProfile? profile,
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
        final docRef = firestoreService.getMedicamentoDocRef(widget.userId, tratamiento.id, profile);
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
          await NotificationService.rescheduleNextPendingDose(updatedTratamiento, widget.userId, profile);
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
    final l10n = AppLocalizations.of(context);
    final firestoreService = context.read<FirestoreService>();
    final flatDoses = _obtenerDosisDelDia(_selectedDay!);

    // Calcular progreso diario
    final totalDoses = flatDoses.length;
    final takenDoses = flatDoses.where((d) => d['status'] == DoseStatus.tomada).length;
    final progressVal = totalDoses > 0 ? takenDoses / totalDoses : 0.0;

    return Column(
      children: [
        // TableCalendar Container Card (wrapped in RepaintBoundary for smooth transitions)
        RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
              border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                  ? Border.all(color: AppTheme.borderColor)
                  : null,
            ),
            child: _buildCalendar(),
          ),
        ),

        // Resumen del día
        if (totalDoses > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                    ? Border.all(color: AppTheme.borderColor)
                    : null,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n?.daySummary ?? 'Resumen del día',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
                      ),
                      Text(
                        l10n?.dosesCompletedSummary(takenDoses, totalDoses) ?? '$takenDoses de $totalDoses dosis completadas',
                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressVal,
                      minHeight: 8,
                      backgroundColor: AppTheme.surfaceColor,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n?.medicationsOfTheDay ?? "Medicamentos del día",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              if (flatDoses.isEmpty) {
                return EstadoVista(
                  state: ViewState.empty,
                  emptyMessage: l10n?.calendarNoEvents ?? 'No hay dosis programadas para este día.',
                  child: const SizedBox.shrink(),
                );
              }

              final isModern = context.watch<PreferenceNotifier>().interfaceStyle == 'modern';
              return ListView.builder(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  bottom: isModern ? 100.0 : 20.0,
                ),
                itemCount: flatDoses.length,
                itemBuilder: (context, index) {
                  final dose = flatDoses[index];
                  final isFirst = index == 0;
                  final isLast = index == flatDoses.length - 1;
                  return _buildTimelineRow(dose, isFirst, isLast, firestoreService);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final langCode = Localizations.localeOf(context).languageCode;
    final calendar = TableCalendar<Map<String, dynamic>>(
      locale: langCode == 'en' ? 'en_US' : 'es_ES',
      firstDay: DateTime.utc(2022, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      eventLoader: (day) => _getGroupedDosesForDay(day).values.expand((d) => d).toList(),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _populateCacheForMonth(selectedDay);
        }
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() => _calendarFormat = format);
        }
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _populateCacheForMonth(focusedDay);
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) => const SizedBox.shrink(),
        defaultBuilder: (context, day, focusedDay) {
          final dosesForDay = _getGroupedDosesForDay(day);
          if (dosesForDay.isEmpty) return null;
          final dayColor = _determineDayColor(dosesForDay);
          return AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              margin: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                color: dayColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: dayColor.withOpacity(0.4), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(color: dayColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          );
        },
        selectedBuilder: (context, day, focusedDay) {
          return AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              margin: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
        todayBuilder: (context, day, focusedDay) {
          return AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              margin: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppTheme.primaryColor, width: 2.0),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      calendarStyle: const CalendarStyle(outsideDaysVisible: false),
      headerStyle: HeaderStyle(titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
      ),
    );

    final keyToUse = widget.calendarViewKey ?? widget.calendarKey;
    if (keyToUse != null) {
      final l10n = AppLocalizations.of(context);
      return Showcase.withWidget(
        key: keyToUse,
        height: 200,
        width: 320,
        disableDefaultTargetGestures: true,
        container: TutorialTooltip(
          icon: Icons.today_rounded,
          title: l10n?.tutorialStep7Title ?? 'Historial y Detalle del Día',
          description: l10n?.tutorialStep7Desc ?? 'Revisa cada día según tus dosis:\n🟢 Tomadas  🔴 Omitidas  🟡 Pendientes\n\nToca cualquier día para ver la lista de dosis programadas.',
          stepNumber: 7,
          totalSteps: 11,
        ),
        targetShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        targetPadding: const EdgeInsets.all(4),
        child: calendar,
      );
    }
    return calendar;
  }

  Widget _buildTimelineRow(Map<String, dynamic> dose, bool isFirst, bool isLast, FirestoreService firestoreService) {
    final Tratamiento tratamiento = dose['tratamiento'];
    final CaregiverProfile? profile = dose['profile'];
    final DateTime doseTime = dose['doseTime'];
    final DoseStatus status = dose['status'];
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final timeStr = DateFormat('hh:mm a', langCode == 'en' ? 'en_US' : 'es_ES').format(doseTime);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DetalleRecetaPage(
                        tratamiento: tratamiento,
                        horaDosis: doseTime,
                        profile: profile,
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
                                 if (profile != null) ...[
                                   const SizedBox(height: 8),
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                     decoration: BoxDecoration(
                                       color: Color(int.parse(profile.colorHex.replaceFirst('#', 'FF'), radix: 16)).withOpacity(0.05),
                                       borderRadius: BorderRadius.circular(4),
                                       border: Border.all(color: Color(int.parse(profile.colorHex.replaceFirst('#', 'FF'), radix: 16)).withOpacity(0.2)),
                                     ),
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Icon(Icons.person, size: 12, color: Color(int.parse(profile.colorHex.replaceFirst('#', 'FF'), radix: 16))),
                                         const SizedBox(width: 4),
                                         Text(
                                           profile.name,
                                           style: TextStyle(
                                             fontSize: 11, 
                                             fontWeight: FontWeight.bold, 
                                             color: Color(int.parse(profile.colorHex.replaceFirst('#', 'FF'), radix: 16)),
                                           ),
                                         ),
                                       ],
                                     ),
                                   ),
                                 ],
                               ],
                             ),
                           ),
                           const SizedBox(width: 8),
                           GestureDetector(
                             onTap: () => _showDoseOptionsDialog(context, tratamiento, profile, doseTime, status),
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

                   // Quick Action Buttons below if it's notified or pending past (pending response)
                   if (status == DoseStatus.notificada || (status == DoseStatus.pendiente && isPast))
                     Padding(
                       padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                       child: Row(
                         children: [
                           FilledButton.icon(
                             icon: const Icon(Icons.check, size: 14),
                             label: Text(l10n?.doseStatusTaken ?? 'Tomada', style: const TextStyle(fontSize: 11)),
                             style: FilledButton.styleFrom(
                               backgroundColor: AppTheme.successColor.withOpacity(0.12),
                               foregroundColor: AppTheme.successColor,
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                               elevation: 0,
                             ),
                             onPressed: () async {
                               final result = await firestoreService.updateDoseStatus(widget.userId, tratamiento.id, doseTime, DoseStatus.tomada, profile);
                               if (result?.stockBajo == true && context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(
                                     content: Text('Stock bajo: te quedan ${result!.dosisRestantes} dosis'),
                                     action: SnackBarAction(
                                       label: 'Farmacias',
                                       onPressed: () {
                                         Navigator.of(context).push(
                                           MaterialPageRoute(builder: (context) => const LocalizadorFarmaciasPage()),
                                         );
                                       },
                                     ),
                                   ),
                                 );
                               }
                             },
                           ),
                           const SizedBox(width: 8),
                           FilledButton.icon(
                             icon: const Icon(Icons.close, size: 14),
                             label: Text(l10n?.doseStatusSkipped ?? 'Omitida', style: const TextStyle(fontSize: 11)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.errorColor.withOpacity(0.12),
                              foregroundColor: AppTheme.errorColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              firestoreService.updateDoseStatus(widget.userId, tratamiento.id, doseTime, DoseStatus.omitida, profile);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A simple manual stream combiner since we don't have rxdart
Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) {
    return Stream.value([]);
  }
  
  late StreamController<List<T>> controller;
  List<T?> currentValues = List.filled(streams.length, null);
  List<bool> hasValue = List.filled(streams.length, false);
  
  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      int completed = 0;
      List<dynamic> subscriptions = [];
      
      for (int i = 0; i < streams.length; i++) {
        subscriptions.add(streams[i].listen(
          (value) {
            currentValues[i] = value;
            hasValue[i] = true;
            if (!hasValue.contains(false)) {
              controller.add(List<T>.from(currentValues));
            }
          },
          onError: controller.addError,
          onDone: () {
            completed++;
            if (completed == streams.length) {
              controller.close();
            }
          },
        ));
      }
      
      controller.onCancel = () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
      };
    },
  );
  
  return controller.stream;
}
