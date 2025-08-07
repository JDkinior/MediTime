// lib/screens/calendar/calendario_page.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:intl/intl.dart';

class CalendarioPage extends StatelessWidget {
  const CalendarioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver el calendario.'))
          : StreamBuilder<List<Tratamiento>>(
              stream: firestoreService.getMedicamentosStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
                }
                if (snapshot.hasError) {
                  return EstadoVista(
                    state: ViewState.error,
                    errorMessage: 'No se pudieron cargar los datos.',
                    child: const SizedBox.shrink(),
                  );
                }

                final todosLosTratamientos = snapshot.data ?? [];
                return _CalendarioContenido(
                  tratamientos: todosLosTratamientos,
                  userId: user.uid,
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// OPTIMIZED CACHE IMPLEMENTATION
// ---------------------------------------------------------------------------

class _CalendarioContenido extends StatefulWidget {
  final List<Tratamiento> tratamientos;
  final String userId;

  const _CalendarioContenido({required this.tratamientos, required this.userId});

  @override
  State<_CalendarioContenido> createState() => _CalendarioContenidoState();
}

class _CalendarioContenidoState extends State<_CalendarioContenido> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Cache to store doses grouped by day.
  final Map<DateTime, Map<Tratamiento, List<Map<String, dynamic>>>> _dayCache = {};
  // Set to track which months have already had their doses calculated.
  final Set<DateTime> _populatedMonths = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // Initially populate the cache for the current month.
    _populateCacheForMonth(_focusedDay);
  }

  @override
  void didUpdateWidget(covariant _CalendarioContenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the list of treatments changes, clear caches and repopulate.
    if (oldWidget.tratamientos != widget.tratamientos) {
      _dayCache.clear();
      _populatedMonths.clear();
      _populateCacheForMonth(_focusedDay);
    }
  }

  // -------------------------------------------------------------------------
  // Populate the cache with doses for a specific month.
  // This is much more efficient than caching all doses for all time.
  // -------------------------------------------------------------------------
  void _populateCacheForMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month, 1);
    if (_populatedMonths.contains(monthKey)) {
      return; // Already populated for this month.
    }

    final firstDayOfMonth = monthKey;
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (var tratamiento in widget.tratamientos) {
      tratamiento.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.parse(dateString);

        // Only process doses that fall within the target month.
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

    // Sort the doses for the newly added days in the month.
    _dayCache.forEach((day, treatmentMap) {
      if (day.year == month.year && day.month == month.month) {
        for (var doseList in treatmentMap.values) {
          doseList.sort((a, b) =>
              (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));
        }
      }
    });

    _populatedMonths.add(monthKey);
    if (mounted) {
      setState(() {}); // Refresh the UI with the newly loaded data.
    }
  }

  // -------------------------------------------------------------------------
  // Helper: retrieve grouped doses for a specific day from the cache.
  // -------------------------------------------------------------------------
  Map<Tratamiento, List<Map<String, dynamic>>> _getGroupedDosesForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _dayCache[dayKey] ?? {};
  }

  // -------------------------------------------------------------------------
  // Helper: decide the colour of a day cell based on its doses.
  // -------------------------------------------------------------------------
  Color _determineDayColor(
      Map<Tratamiento, List<Map<String, dynamic>>> dosesForDay) {
    if (dosesForDay.isEmpty) return Colors.transparent;

    final allDoses = dosesForDay.values.expand((d) => d).toList();

    if (allDoses.any((d) => d['status'] == DoseStatus.notificada)) {
      return Colors.amber.shade600;
    } else if (allDoses.any((d) => d['status'] == DoseStatus.omitida)) {
      return Colors.red.shade400;
    } else if (dosesForDay.keys
        .every((t) => t.fechaFinTratamiento.isBefore(DateTime.now()))) {
      return Colors.green.shade400;
    } else {
      return kSecondaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Column(
      children: [
        TableCalendar<Map<String, dynamic>>(
          locale: 'es_ES',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          // -----------------------------------------------------------------
          // Use the cached data for event loading – this is now O(1) per day.
          // -----------------------------------------------------------------
          eventLoader: (day) =>
              _getGroupedDosesForDay(day).values.expand((d) => d).toList(),
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
            // Efficiently load data for the newly visible month.
            _populateCacheForMonth(focusedDay);
          },
          // -----------------------------------------------------------------
          // DAY CELL BUILDERS – now use the cache instead of recomputing.
          // -----------------------------------------------------------------
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) => const SizedBox.shrink(),
            defaultBuilder: (context, day, focusedDay) {
              final dosesForDay = _getGroupedDosesForDay(day);
              if (dosesForDay.isEmpty) return null;

              final dayColor = _determineDayColor(dosesForDay);

              return AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: dayColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              return AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
            todayBuilder: (context, day, focusedDay) {
              return AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: kSecondaryColor,
                      width: 2.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                          color: kSecondaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          ),
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          headerStyle:
              const HeaderStyle(titleCentered: true, formatButtonVisible: false),
        ),
        const SizedBox(height: 8.0),
        // -----------------------------------------------------------------
        // The rest of the UI (list of doses for the selected day) remains
        // unchanged – only the data source is now the cached map.
        // -----------------------------------------------------------------
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Medicamentos del Día",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800),
            ),
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            final groupedDoses = _getGroupedDosesForDay(_selectedDay!);
            if (groupedDoses.isEmpty) {
              return const EstadoVista(
                state: ViewState.empty,
                emptyMessage: 'No hay dosis programadas para este día.',
                child: SizedBox.shrink(),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              children: groupedDoses.entries.map((entry) {
                final tratamiento = entry.key;
                final doses = entry.value;

                final tomadasCount =
                    doses.where((d) => d['status'] == DoseStatus.tomada).length;
                final totalCount = doses.length;
                final progress = totalCount > 0
                    ? tomadasCount / totalCount
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 241, 241, 241),
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: kCustomBoxShadow,
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: _buildProgressIndicator(progress),
                    title: Row(
                      children: [
                        Text(tratamiento.nombreMedicamento,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kSecondaryColor)),
                        const SizedBox(width: 8),
                        if (doses
                            .any((d) => d['status'] == DoseStatus.notificada))
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle:
                        Text('$tomadasCount de $totalCount dosis completadas'),
                    children: doses.map((doseData) {
                      return _buildDoseListItem(
                          tratamiento, doseData, firestoreService);
                    }).toList(),
                  ),
                );
              }).toList(),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(double progress) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            color: kPrimaryColor,
            strokeWidth: 5,
          ),
          Center(
            child: Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDoseListItem(Tratamiento tratamiento, Map<String, dynamic> doseData, FirestoreService firestoreService) {
    final DateTime doseTime = doseData['doseTime'];
    final DoseStatus status = doseData['status'];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case DoseStatus.tomada:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case DoseStatus.omitida:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case DoseStatus.notificada:
        statusColor = Colors.amber.shade700;
        statusIcon = Icons.notifications_active;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_top;
    }

    return Container(
      color: Colors.grey.withOpacity(0.05),
      child: Column(
        children: [
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(statusIcon, color: statusColor, size: 28),
            title: Text(
              DateFormat('hh:mm a', 'es_ES').format(doseTime),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            trailing: Text(
              status.toString().split('.').last.toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          if (status == DoseStatus.notificada)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Tomada'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      firestoreService.updateDoseStatus(widget.userId, tratamiento.id, doseTime, DoseStatus.tomada);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Omitida'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
    );
  }
}