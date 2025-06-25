import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/screens/medication/dosis_dia_page.dart';
import 'package:meditime/screens/medication/resumen_tratamiento_page.dart';

// Definimos la sombra como una constante para reutilizarla y mantener la consistencia.
const kCustomBoxShadow = [
  BoxShadow(
    color: Color.fromARGB(20, 47, 109, 180), // Sombra azul sutil
    blurRadius: 6,
    spreadRadius: 3,
    offset: Offset(0, 4),
  ),
];

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  _CalendarioPageState createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medicamentos')
            .doc(userId)
            .collection('userMedicamentos')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = LinkedHashMap<DateTime, List<Map<String, dynamic>>>(
            equals: isSameDay,
            hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
          );

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['fechaInicioTratamiento'] == null ||
                data['fechaFinTratamiento'] == null) {
              continue;
            }
            final startDate =
                (data['fechaInicioTratamiento'] as Timestamp).toDate();
            final endDate =
                (data['fechaFinTratamiento'] as Timestamp).toDate();
            for (var day = startDate;
                day.isBefore(endDate.add(const Duration(days: 1)));
                day = day.add(const Duration(days: 1))) {
              final normalizedDay = DateTime.utc(day.year, day.month, day.day);
              final dayEvents = events.putIfAbsent(normalizedDay, () => []);
              dayEvents.add({...data, 'docId': doc.id});
            }
          }

          List<Map<String, dynamic>> getEventsForDay(DateTime day) {
            final normalizedDay = DateTime.utc(day.year, day.month, day.day);
            return events[normalizedDay] ?? [];
          }

          int getDoseCountForDay(
              Map<String, dynamic> tratamiento, DateTime forDay) {
            final DateTime inicioTratamiento =
                (tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
            final DateTime fechaFin =
                (tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
            final int intervalo = int.parse(tratamiento['intervaloDosis']);
            int count = 0;
            DateTime dosisActual = inicioTratamiento;

            // CAMBIO CLAVE: El bucle ahora recorre TODO el tratamiento.
            while (dosisActual.isBefore(fechaFin)) {
              // El filtro para el día específico se hace aquí adentro.
              if (isSameDay(dosisActual, forDay)) {
                count++;
              }
              dosisActual = dosisActual.add(Duration(hours: intervalo));
            }
            return count;
          }

          final selectedDayEvents = getEventsForDay(_selectedDay!);

          return Column(
            children: [
              TableCalendar<Map<String, dynamic>>(
                locale: 'es_ES',
                firstDay: DateTime.utc(2022, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                eventLoader: getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
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
                    final dayEvents = getEventsForDay(day);
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
                  // --- AÑADIDO PARA OCULTAR MARCADORES POR DEFECTO ---
                  markerBuilder: (context, day, events) {
                    // Devolvemos un widget vacío para que no dibuje los puntos negros
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
                child: ListView.builder(
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
        },
      ),
    );
  }
}