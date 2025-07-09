// lib/screens/calendar/calendario_page.dart
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/screens/medication/dosis_dia_page.dart';
import 'package:meditime/screens/medication/resumen_tratamiento_page.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/services/tratamiento_service.dart';

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
                final events = _procesarEventos(todosLosTratamientos);

                return _CalendarioContenido(events: events);
              },
            ),
    );
  }

  LinkedHashMap<DateTime, List<Tratamiento>> _procesarEventos(List<Tratamiento> tratamientos) {
      final events = LinkedHashMap<DateTime, List<Tratamiento>>(
        equals: isSameDay,
        hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
      );
      final tratamientoService = TratamientoService(); // Instancia del servicio
     for (var tratamiento in tratamientos) {
      // Usamos el servicio para obtener todas las dosis
      final todasLasDosis = tratamientoService.generarDosisTotales(tratamiento);
      
      // Creamos un conjunto de días únicos para evitar duplicados
      final diasUnicos = todasLasDosis.map((d) => DateTime.utc(d.year, d.month, d.day)).toSet();

      for (var dia in diasUnicos) {
         events.putIfAbsent(dia, () => []).add(tratamiento);
      }
    }
    return events;
  }
}

class _CalendarioContenido extends StatefulWidget {
  final LinkedHashMap<DateTime, List<Tratamiento>> events;

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

  List<Tratamiento> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return widget.events[normalizedDay] ?? [];
  }

  int getDoseCountForDay(Tratamiento tratamiento, DateTime forDay) {
    return TratamientoService().getDosisCountForDay(tratamiento, forDay);
  }


  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _getEventsForDay(_selectedDay!);

    return Column(
      children: [
        TableCalendar<Tratamiento>(
          locale: 'es_ES',
          firstDay: DateTime.utc(2022, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          eventLoader: _getEventsForDay,
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
                    ev.fechaFinTratamiento.isBefore(DateTime.now()));

                return Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: todosTerminados ? Colors.green : const Color(0xFF4092E4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${day.day}', style: const TextStyle(color: Colors.white)),
                  ),
                );
              }
              return null;
            },
            markerBuilder: (context, day, events) => const SizedBox.shrink(),
          ),
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
        ),
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Medicamentos del Día",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
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
                    final bool isFinished = event.fechaFinTratamiento.isBefore(DateTime.now());

                    final int doseCountToday = isFinished ? 0 : getDoseCountForDay(event, _selectedDay!);
                    final String subtitleText = isFinished
                        ? 'Tratamiento finalizado'
                        : 'En progreso - $doseCountToday dosis hoy';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: kCustomBoxShadow,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isFinished ? Icons.check_circle_outline : Icons.timelapse,
                          color: isFinished ? Colors.grey : Colors.green.shade600,
                          size: 28,
                        ),
                        title: Text(event.nombreMedicamento, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitleText, style: TextStyle(color: Colors.grey.shade600)),
                        onTap: () {
                          if (isFinished) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                // ----- ¡AQUÍ ESTÁ LA CORRECCIÓN! -----
                                // Pasamos el objeto 'event' directamente, ya que es un Tratamiento.
                                builder: (context) => ResumenTratamientoPage(tratamiento: event),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DosisDiaPage(
                                  tratamiento: event, // <-- CAMBIO: Pasamos el objeto completo
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