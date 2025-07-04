// lib/screens/calendar/calendario_page.dart
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/screens/medication/dosis_dia_page.dart';
import 'package:meditime/screens/medication/resumen_tratamiento_page.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';

// --- CAMBIO 1: El widget principal ahora es más simple ---
// Ya no maneja el estado del día seleccionado, solo carga los datos.
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
          : StreamBuilder<QuerySnapshot>(
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

                // Procesamos los eventos aquí una sola vez
                final events = _procesarEventos(snapshot.data?.docs ?? []);

                // Pasamos los eventos procesados al nuevo widget de contenido
                return _CalendarioContenido(events: events);
              },
            ),
    );
  }

    LinkedHashMap<DateTime, List<Map<String, dynamic>>> _procesarEventos(List<QueryDocumentSnapshot> docs) {
    final events = LinkedHashMap<DateTime, List<Map<String, dynamic>>>(
      equals: isSameDay,
      hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
    );

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['fechaInicioTratamiento'] == null || data['fechaFinTratamiento'] == null) {
        continue;
      }
      final startDate = (data['fechaInicioTratamiento'] as Timestamp).toDate();
      final endDate = (data['fechaFinTratamiento'] as Timestamp).toDate();
      final int intervalo = int.tryParse(data['intervaloDosis'] ?? '0') ?? 0;
      if (intervalo <= 0) continue;

      // Se itera sobre cada día del tratamiento
      for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        int doseCountForDay = 0;
        DateTime dosisActual = startDate;

        // Se calcula cuántas dosis hay en este 'day' específico
        while (dosisActual.isBefore(endDate)) {
          if (isSameDay(dosisActual, day)) {
            doseCountForDay++;
          }
          dosisActual = dosisActual.add(Duration(hours: intervalo));
        }

        // Solo se agrega el día al calendario si tiene al menos una dosis
        if (doseCountForDay > 0) {
          final normalizedDay = DateTime.utc(day.year, day.month, day.day);
          final dayEvents = events.putIfAbsent(normalizedDay, () => []);
          dayEvents.add({...data, 'docId': doc.id});
        }
      }
    }
    return events;
  }
}

// --- CAMBIO 2: Creamos un nuevo StatefulWidget para el contenido ---
// Este widget SÍ manejará el estado del día seleccionado, el formato, etc.
class _CalendarioContenido extends StatefulWidget {
  final LinkedHashMap<DateTime, List<Map<String, dynamic>>> events;

  const _CalendarioContenido({required this.events});

  @override
  State<_CalendarioContenido> createState() => _CalendarioContenidoState();
}

class _CalendarioContenidoState extends State<_CalendarioContenido> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return widget.events[normalizedDay] ?? [];
  }
  
  int getDoseCountForDay(Map<String, dynamic> tratamiento, DateTime forDay) {
      final DateTime inicioTratamiento = (tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
      final DateTime fechaFin = (tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
      final int intervalo = int.parse(tratamiento['intervaloDosis']);
      int count = 0;
      DateTime dosisActual = inicioTratamiento;

      while (dosisActual.isBefore(fechaFin)) {
        if (isSameDay(dosisActual, forDay)) {
          count++;
        }
        dosisActual = dosisActual.add(Duration(hours: intervalo));
      }
      return count;
    }


  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _getEventsForDay(_selectedDay!);

    // La UI es la misma, pero ahora vive dentro de este widget más pequeño.
    // El setState() llamado aquí solo reconstruirá _CalendarioContenido.
    return Column(
      children: [
        TableCalendar<Map<String, dynamic>>(
          locale: 'es_ES',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              // Este setState ahora solo afecta a este widget, no al StreamBuilder
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
           calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final dayEvents = _getEventsForDay(day);
              if (dayEvents.isNotEmpty) {
                bool todosTerminados = dayEvents.every((ev) =>
                    (ev['fechaFinTratamiento'] as Timestamp)
                        .toDate()
                        .isBefore(DateTime.now()));
                
                return Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: todosTerminados ? Colors.green : const Color(0xFF4092E4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
              return null;
            },
            markerBuilder: (context, day, events) {
              return const SizedBox.shrink();
            },
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
          ),
          headerStyle: const HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
          ),
        ),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Medicamentos del Día",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
        Expanded(
          child: selectedDayEvents.isEmpty
              ? const EstadoVista(
                  state: ViewState.empty,
                  emptyMessage: 'No hay medicamentos programados para este día.',
                  child: SizedBox.shrink(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 0),
                  itemCount: selectedDayEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedDayEvents[index];
                    final bool isFinished =
                        (event['fechaFinTratamiento'] as Timestamp)
                            .toDate()
                            .isBefore(DateTime.now());

                    final int doseCountToday = isFinished
                        ? 0
                        : getDoseCountForDay(event, _selectedDay!);
                    final String subtitleText = isFinished
                        ? 'Tratamiento finalizado'
                        : 'En progreso - $doseCountToday dosis hoy';

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: kCustomBoxShadow,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isFinished
                              ? Icons.check_circle_outline
                              : Icons.timelapse,
                          color:
                              isFinished ? Colors.grey : Colors.green.shade600,
                          size: 28,
                        ),
                        title: Text(
                          event['nombreMedicamento'] ?? 'Medicamento',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          subtitleText,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        onTap: () {
                          if (isFinished) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ResumenTratamientoPage(tratamiento: event),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DosisDiaPage(
                                  tratamientoId: event['docId'],
                                  selectedDay: _selectedDay!,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}