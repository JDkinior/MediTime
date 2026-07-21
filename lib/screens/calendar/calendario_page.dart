// lib/screens/calendar/calendario_page.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
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
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarioPage extends StatelessWidget {
  final GlobalKey? calendarKey;

  const CalendarioPage({super.key, this.calendarKey});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final user = authService.currentUser;
    final activeProfile = caregiverNotifier.isCaregiverModeActive ? caregiverNotifier.activeProfile : null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver el calendario.'))
          : StreamBuilder<List<Tratamiento>>(
              initialData: firestoreService.getCachedMedicamentos(user.uid, activeProfile),
              stream: firestoreService.getMedicamentosStream(user.uid, activeProfile),
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

                final todosLosTratamientos = snapshot.data ?? [];
                return _CalendarioContenido(
                  tratamientos: todosLosTratamientos,
                  userId: user.uid,
                  calendarKey: calendarKey,
                );
              },
            ),
    );
  }
}

class _CalendarioContenido extends StatefulWidget {
  final List<Tratamiento> tratamientos;
  final String userId;
  final GlobalKey? calendarKey;

  const _CalendarioContenido({
    required this.tratamientos,
    required this.userId,
    this.calendarKey,
  });

  @override
  State<_CalendarioContenido> createState() => _CalendarioContenidoState();
}

class _CalendarioContenidoState extends State<_CalendarioContenido> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Animation<double>? _secondaryAnimation;

  final Map<DateTime, Map<Tratamiento, List<Map<String, dynamic>>>> _dayCache = {};
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
    if (oldWidget.tratamientos != widget.tratamientos) {
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

    final firstDayOfMonth = monthKey;
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (var tratamiento in widget.tratamientos) {
      tratamiento.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.parse(dateString);

        if (doseTime.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
            doseTime.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
          final dayKey = DateTime(doseTime.year, doseTime.month, doseTime.day);

          _dayCache.putIfAbsent(dayKey, () => {});
          final treatmentMap = _dayCache[dayKey]!;

          treatmentMap.putIfAbsent(tratamiento, () => []);
          treatmentMap[tratamiento]!.add({
            'doseTime': doseTime,
            'status': status,
          });
        }
      });
    }

    _dayCache.forEach((day, treatmentMap) {
      if (day.year == month.year && day.month == month.month) {
        for (var doseList in treatmentMap.values) {
          doseList.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
        }
      }
    });

    _populatedMonths.add(monthKey);
    if (mounted) {
      setState(() {});
    }
  }

  Map<Tratamiento, List<Map<String, dynamic>>> _getGroupedDosesForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _dayCache[dayKey] ?? {};
  }

  List<Map<String, dynamic>> _obtenerDosisDelDia(DateTime day) {
    final groupedDoses = _getGroupedDosesForDay(day);
    final List<Map<String, dynamic>> flatDoses = [];

    groupedDoses.forEach((tratamiento, list) {
      for (var dose in list) {
        flatDoses.add({
          'tratamiento': tratamiento,
          'doseTime': dose['doseTime'] as DateTime,
          'status': dose['status'] as DoseStatus,
        });
      }
    });

    flatDoses.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
    return flatDoses;
  }

  Color _determineDayColor(Map<Tratamiento, List<Map<String, dynamic>>> dosesForDay) {
    if (dosesForDay.isEmpty) return Colors.transparent;

    final allDoses = dosesForDay.values.expand((d) => d).toList();

    if (allDoses.any((d) => d['status'] == DoseStatus.notificada)) {
      return Colors.amber.shade600;
    } else if (allDoses.any((d) => d['status'] == DoseStatus.omitida)) {
      return AppTheme.errorColor;
    } else if (allDoses.every((d) => d['status'] == DoseStatus.tomada)) {
      return AppTheme.successColor;
    } else {
      return AppTheme.primaryColor;
    }
  }

  void _showDoseOptionsDialog(BuildContext context, Tratamiento tratamiento, DateTime doseTime, DoseStatus status) {
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
            style: const TextStyle(
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
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 8,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 16,
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
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
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
                    Navigator.of(context).pop();
                    final inventoryResult = await firestoreService.updateDoseStatus(
                      widget.userId,
                      tratamiento.id,
                      doseTime,
                      DoseStatus.tomada,
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
                      color: AppTheme.successColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.successColor.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Marcar como tomada',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTextColor,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Registrar esta dosis como ingerida',
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

              // Section 2: Rescheduling & Timing Options
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    if (status != DoseStatus.omitida) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.alarm_off, color: Colors.orange, size: 20),
                        ),
                        title: Text(
                          'Omitir esta dosis',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                        ),
                        subtitle: Text(
                          'Saltar esta toma sin registrarla',
                          style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await firestoreService.updateDoseStatus(widget.userId, tratamiento.id, doseTime, DoseStatus.omitida);
                          final doc = await firestoreService.getMedicamentoDocRef(widget.userId, tratamiento.id).get();
                          if (doc.exists) {
                            final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                            await NotificationService.rescheduleNextPendingDose(updatedTratamiento, widget.userId);
                          }
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Dosis omitida y alarma reprogramada.')),
                          );
                        },
                      ),
                      Divider(height: 1, color: AppTheme.borderColor),
                    ],
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.withOpacity(0.1),
                        child: const Icon(Icons.snooze, color: Colors.amber, size: 20),
                      ),
                      title: Text(
                        'Aplazar dosis',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                      ),
                      subtitle: Text(
                        'Postergar la toma por unos minutos',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                      ),
                      onTap: () async {
                        Navigator.of(context).pop();
                        final minutes = await showModalBottomSheet<int>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            decoration: BoxDecoration(color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            padding: EdgeInsets.only(
                              top: 8,
                              left: 20,
                              right: 20,
                              bottom: MediaQuery.of(ctx).padding.bottom + 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                                  margin: const EdgeInsets.only(bottom: 16),
                                ),
                                Text(
                                  'Aplazar Dosis',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '¿Cuánto tiempo deseas aplazar esta dosis?',
                                  style: TextStyle(color: AppTheme.secondaryTextColor),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 2.2,
                                  children: [
                                    buildDeferOption(ctx, 10, '10 Minutos'),
                                    buildDeferOption(ctx, 15, '15 Minutos'),
                                    buildDeferOption(ctx, 30, '30 Minutos'),
                                    buildDeferOption(ctx, 60, '1 Hora'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        );

                        if (minutes != null) {
                          final newDoseTime = doseTime.add(Duration(minutes: minutes));
                          final docRef = firestoreService.getMedicamentoDocRef(widget.userId, tratamiento.id);
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
                            await NotificationService.rescheduleNextPendingDose(updatedTratamiento, widget.userId);
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
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: const Icon(Icons.edit_calendar_outlined, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(
                        'Editar hora de la dosis',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                      ),
                      subtitle: Text(
                        'Cambiar la hora programada para esta dosis',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                      ),
                      onTap: () async {
                        Navigator.of(context).pop();
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
                          final docRef = firestoreService.getMedicamentoDocRef(widget.userId, tratamiento.id);
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
                            await NotificationService.rescheduleNextPendingDose(updatedTratamiento, widget.userId);
                          }
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Hora de la dosis modificada.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: Destructive Action
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: AppTheme.errorColor.withOpacity(0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.15),
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
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Confirmar eliminación', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                        content: const Text('¿Estás seguro de que deseas eliminar este tratamiento?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                            child: const Text('Eliminar'),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await NotificationService.revokeTreatmentLocally(widget.userId, tratamiento.id);
                              await NotificationService.cancelTreatmentAlarms(tratamiento.prescriptionAlarmId);
                              await firestoreService.deleteTratamiento(widget.userId, tratamiento.id);
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

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final flatDoses = _obtenerDosisDelDia(_selectedDay!);

    // Calcular progreso diario
    final totalDoses = flatDoses.length;
    final takenDoses = flatDoses.where((d) => d['status'] == DoseStatus.tomada).length;
    final progressVal = totalDoses > 0 ? takenDoses / totalDoses : 0.0;

    return Column(
      children: [
        // TableCalendar Container Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
          ),
          child: _buildCalendar(),
        ),

        // Resumen del día
        if (totalDoses > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resumen del día',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
                      ),
                      Text(
                        '$takenDoses de $totalDoses dosis completadas',
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
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
              "Medicamentos del día",
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
                return const EstadoVista(
                  state: ViewState.empty,
                  emptyMessage: 'No hay dosis programadas para este día.',
                  child: SizedBox.shrink(),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
    final calendar = TableCalendar<Map<String, dynamic>>(
      locale: 'es_ES',
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
        }
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() => _calendarFormat = format);
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
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
                  style: const TextStyle(
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

    if (widget.calendarKey != null) {
      return Showcase.withWidget(
        key: widget.calendarKey!,
        height: 200,
        width: 320,
        disableDefaultTargetGestures: true,
        container: const TutorialTooltip(
          icon: Icons.calendar_month_rounded,
          title: 'Calendario de dosis',
          description: 'Visualiza el historial de tus medicamentos día a día.\n\n🟢 Completado  🔴 Omitido  🟥 Pendiente\n\nToca un día para ver los detalles.',
          stepNumber: 6,
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
    final DateTime doseTime = dose['doseTime'];
    final DoseStatus status = dose['status'];
    final timeStr = DateFormat('hh:mm a', 'es_ES').format(doseTime);

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
    String statusText = 'Programada';

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
      statusText = 'Tomada';
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
      statusText = 'Omitida';
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
      statusText = 'Aplazada';
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
      statusText = 'Notificada';
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
      statusText = 'Programada';
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
                      )),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
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
                                      style: const TextStyle(
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
                                Text(
                                  '${tratamiento.presentacion} · Cada ${tratamiento.intervaloDosis.inHours} horas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryTextColor,
                                  ),
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

                  // Quick Action Buttons below if it's notified (pending response)
                  if (status == DoseStatus.notificada)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Row(
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Tomada', style: TextStyle(fontSize: 11)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.successColor.withOpacity(0.12),
                              foregroundColor: AppTheme.successColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final result = await firestoreService.updateDoseStatus(widget.userId, tratamiento.id, doseTime, DoseStatus.tomada);
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
                            label: const Text('Omitida', style: TextStyle(fontSize: 11)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.errorColor.withOpacity(0.12),
                              foregroundColor: AppTheme.errorColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              firestoreService.updateDoseStatus(widget.userId, tratamiento.id, doseTime, DoseStatus.omitida);
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
