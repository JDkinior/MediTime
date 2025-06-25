import 'dart:async';
import 'dart:math'; // Para generar un nuevo ID de notificación
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:meditime/alarm_callback_handler.dart';
import 'package:meditime/theme/app_theme.dart'; // Asegúrate de tener tu tema definido aquí
// Definición de la sombra personalizada


class DosisDiaPage extends StatelessWidget {
  final String tratamientoId;
  final DateTime selectedDay;

  const DosisDiaPage({
    super.key,
    required this.tratamientoId,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final docRef = FirebaseFirestore.instance
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .doc(tratamientoId);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final tratamiento = snapshot.data!.data() as Map<String, dynamic>;
        final String nombreMedicamento = tratamiento['nombreMedicamento'] ?? 'N/A';
        final DateFormat formatter = DateFormat('d \'de\' MMMM', 'es_ES');

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombreMedicamento),
                Text(
                  formatter.format(selectedDay),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              if (tratamiento['notas'] != null && tratamiento['notas'].isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Notas del Medicamento'),
                        content: Text(tratamiento['notas']),
                        actions: [
                          TextButton(
                            child: const Text('Cerrar'),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        ],
                      ),
                    );
                  },
                )
            ],
          ),
          body: DosisDiaView(
            tratamiento: tratamiento,
            selectedDay: selectedDay,
            docRef: docRef,
          ),
        );
      },
    );
  }
}

class DosisDiaView extends StatefulWidget {
  final Map<String, dynamic> tratamiento;
  final DateTime selectedDay;
  final DocumentReference docRef;

  const DosisDiaView({
    super.key,
    required this.tratamiento,
    required this.selectedDay,
    required this.docRef,
  });

  @override
  State<DosisDiaView> createState() => _DosisDiaViewState();
}

class _DosisDiaViewState extends State<DosisDiaView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  // --- Lógica de la pantalla ---
  List<DateTime> _generarDosisDelDia() {
    final DateTime inicio = (widget.tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
    final DateTime fechaFin = (widget.tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervalo = int.parse(widget.tratamiento['intervaloDosis']);
    List<DateTime> dosisGeneradas = [];
    DateTime dosisActual = inicio;

    // CAMBIO CLAVE: El bucle, al igual que en el calendario, recorre TODO el tratamiento.
    while (dosisActual.isBefore(fechaFin)) {
      // Filtramos aquí adentro solo las dosis que corresponden al día seleccionado.
      if (isSameDay(dosisActual, widget.selectedDay)) {
        dosisGeneradas.add(dosisActual);
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }
    return dosisGeneradas;
  }
  
  String _getTiempoRestante(DateTime proximaDosis) {
    final diferencia = proximaDosis.difference(DateTime.now());
    if (diferencia.isNegative) return 'Ahora';
    return '${diferencia.inHours.toString().padLeft(2, '0')}:${(diferencia.inMinutes % 60).toString().padLeft(2, '0')}:${(diferencia.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _toggleDosisStatus(DateTime dosisTime, bool fueOmitida) async {
    final timestamp = Timestamp.fromDate(dosisTime);
    final int alarmId = widget.tratamiento['prescriptionAlarmId'];
    
    // --- LÓGICA PARA OMITIR UNA DOSIS (igual que antes) ---
    if (!fueOmitida) {
      debugPrint("OMITIENDO: Cancelando cadena de alarmas con ID: $alarmId");
      await AndroidAlarmManager.cancel(alarmId);

      await widget.docRef.update({
        'skippedDoses': FieldValue.arrayUnion([timestamp])
      });

      // Reprogramar desde la siguiente dosis
      final DateTime? proximaDosisReal = await _findNextUpcomingDose();

      if (proximaDosisReal != null) {
        debugPrint("OMITIENDO: Reprogramando la alarma para las $proximaDosisReal con ID: $alarmId");
        await AndroidAlarmManager.oneShotAt(
          proximaDosisReal,
          alarmId,
          alarmCallbackLogic,
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: true,
          params: {
            'currentNotificationId': Random().nextInt(100000),
            'nombreMedicamento': widget.tratamiento['nombreMedicamento'],
            'presentacion': widget.tratamiento['presentacion'],
            'intervaloHoras': int.parse(widget.tratamiento['intervaloDosis']),
            'fechaFinTratamientoString': (widget.tratamiento['fechaFinTratamiento'] as Timestamp).toDate().toIso8601String(),
            'prescriptionAlarmId': alarmId,
          },
        );
      } else {
        debugPrint("OMITIENDO: No hay más dosis futuras que programar.");
      }
    } 
    // --- NUEVA LÓGICA PARA ANULAR UNA OMISIÓN ---
    else {
      debugPrint("ANULANDO OMISIÓN: Cancelando cualquier alarma existente con ID: $alarmId para reevaluar.");
      await AndroidAlarmManager.cancel(alarmId);
      
      // Quitar la dosis del array de omitidas en Firestore
      await widget.docRef.update({
        'skippedDoses': FieldValue.arrayRemove([timestamp])
      });
      
      // Volver a calcular cuál es la próxima dosis real (podría ser la que acabamos de "des-omitir")
      final DateTime? proximaDosisReal = await _findNextUpcomingDose();

      if (proximaDosisReal != null) {
        debugPrint("ANULANDO OMISIÓN: La próxima alarma real es a las $proximaDosisReal. Reprogramando con ID: $alarmId");
        await AndroidAlarmManager.oneShotAt(
          proximaDosisReal,
          alarmId,
          alarmCallbackLogic,
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: true,
           params: {
            'currentNotificationId': Random().nextInt(100000),
            'nombreMedicamento': widget.tratamiento['nombreMedicamento'],
            'presentacion': widget.tratamiento['presentacion'],
            'intervaloHoras': int.parse(widget.tratamiento['intervaloDosis']),
            'fechaFinTratamientoString': (widget.tratamiento['fechaFinTratamiento'] as Timestamp).toDate().toIso8601String(),
            'prescriptionAlarmId': alarmId,
          },
        );
      } else {
         debugPrint("ANULANDO OMISIÓN: No hay más dosis futuras que programar.");
      }
    }
  }

  Future<DateTime?> _findNextUpcomingDose() async {
    // Primero, recargamos los datos más recientes desde Firestore
    final freshSnapshot = await widget.docRef.get();
    final freshTratamiento = freshSnapshot.data() as Map<String, dynamic>;

    final DateTime inicio = (freshTratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
    final DateTime fechaFin = (freshTratamiento['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervalo = int.parse(freshTratamiento['intervaloDosis']);
    final List<DateTime> dosisOmitidas = (freshTratamiento['skippedDoses'] as List<dynamic>?)
        ?.map((ts) => (ts as Timestamp).toDate())
        .toList() ?? [];

    DateTime dosisActual = inicio;

    while (dosisActual.isBefore(fechaFin)) {
      // Buscamos la primera dosis futura que NO esté en la lista de omitidas
      if (dosisActual.isAfter(DateTime.now())) {
        final esOmitida = dosisOmitidas.any((om) => om.isAtSameMomentAs(dosisActual));
        if (!esOmitida) {
          return dosisActual; // ¡Esta es la próxima!
        }
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }
    
    return null; // No hay más dosis futuras
  }
  
  // --- Widgets de Construcción ---
  @override
  Widget build(BuildContext context) {
    final dosisDelDia = _generarDosisDelDia();
    final List<DateTime> dosisOmitidas = (widget.tratamiento['skippedDoses'] as List<dynamic>?)
        ?.map((ts) => (ts as Timestamp).toDate())
        .toList() ?? [];
    
    int tomadasHoy = 0;
    dosisDelDia.where((d) => d.isBefore(DateTime.now())).forEach((d) {
      if (!dosisOmitidas.any((om) => om.isAtSameMomentAs(d))) {
        tomadasHoy++;
      }
    });

    final double progress = dosisDelDia.isEmpty ? 0 : tomadasHoy / dosisDelDia.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDailyHeader(dosisDelDia.length, tomadasHoy, progress),
          const SizedBox(height: 20),
          ...dosisDelDia.map((dosis) {
            final fueOmitida = dosisOmitidas.any((om) => om.isAtSameMomentAs(dosis));
            final esPasada = dosis.isBefore(DateTime.now());
            return _buildDoseCard(dosis, fueOmitida, esPasada);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDailyHeader(int totalDosis, int tomadas, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: kCustomBoxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progreso del Día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('$tomadas / $totalDosis Dosis', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(DateTime dosis, bool fueOmitida, bool esPasada) {
    IconData statusIcon;
    String statusText;
    Color statusColor;
    Widget? trailingWidget;

    if (fueOmitida) {
      statusIcon = Icons.cancel;
      statusText = 'Omitida';
      statusColor = Colors.red.shade700;
      trailingWidget = OutlinedButton(onPressed: () => _toggleDosisStatus(dosis, true), child: const Text('Tomar'));
    } else if (esPasada) {
      statusIcon = Icons.check_circle;
      statusText = 'Tomada';
      statusColor = Colors.green.shade600;
      trailingWidget = IconButton(icon: const Icon(Icons.undo), tooltip: 'Anular Toma', onPressed: () => _toggleDosisStatus(dosis, false));
    } else {
      statusIcon = Icons.notifications_active;
      statusText = 'Pendiente';
      statusColor = Colors.blue.shade600;
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_getTiempoRestante(dosis), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          IconButton(icon: const Icon(Icons.alarm_off), tooltip: 'Omitir Dosis', onPressed: () => _toggleDosisStatus(dosis, false)),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: kCustomBoxShadow,
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('hh:mm a', 'es_ES').format(dosis), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(statusText, style: TextStyle(fontSize: 16, color: statusColor)),
            ],
          ),
          const Spacer(),
          trailingWidget,
        ],
      ),
    );
  }
}