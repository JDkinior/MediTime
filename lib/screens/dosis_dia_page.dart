import 'dart:async';
import 'dart:math'; // Para generar un nuevo ID de notificación
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:meditime/alarm_callback_handler.dart';

// Definición de la sombra personalizada
const kCustomBoxShadow = [
  BoxShadow(
    color: Color.fromARGB(20, 47, 109, 180),
    blurRadius: 6,
    spreadRadius: 3,
    offset: Offset(0, 4),
  ),
];

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
    final int intervalo = int.parse(widget.tratamiento['intervaloDosis']);
    List<DateTime> dosisGeneradas = [];
    DateTime dosisActual = inicio;

    while (dosisActual.isBefore(widget.selectedDay.add(const Duration(days: 1)))) {
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

  // --- FUNCIÓN CLAVE ACTUALIZADA ---
  Future<void> _toggleDosisStatus(DateTime dosisTime, bool fueOmitida) async {
    final timestamp = Timestamp.fromDate(dosisTime);
    final int alarmId = widget.tratamiento['prescriptionAlarmId'];
    
    // Si estamos marcando una dosis como OMITIDA
    if (!fueOmitida) {
      // 1. Cancelar la cadena de alarmas actual para que no se dispare la que acabamos de omitir
      debugPrint("Cancelando cadena de alarmas con ID: $alarmId");
      await AndroidAlarmManager.cancel(alarmId);

      // 2. Añadir la dosis al array de omitidas en Firestore
      await widget.docRef.update({
        'skippedDoses': FieldValue.arrayUnion([timestamp])
      });

      // 3. Calcular la siguiente dosis y reprogramar la cadena de alarmas desde ahí
      final int intervaloHoras = int.parse(widget.tratamiento['intervaloDosis']);
      final DateTime proximaDosis = dosisTime.add(Duration(hours: intervaloHoras));
      final DateTime fechaFin = (widget.tratamiento['fechaFinTratamiento'] as Timestamp).toDate();

      if (proximaDosis.isBefore(fechaFin)) {
        debugPrint("Reprogramando siguiente alarma para las $proximaDosis con ID: $alarmId");
        await AndroidAlarmManager.oneShotAt(
          proximaDosis,
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
            'intervaloHoras': intervaloHoras,
            'fechaFinTratamientoString': fechaFin.toIso8601String(),
            'prescriptionAlarmId': alarmId,
          },
        );
      } else {
        debugPrint("No se reprograma, la siguiente dosis estaría fuera del tratamiento.");
      }
    } else {
      // Si estamos ANULANDO una omisión (marcando como tomada)
      // Simplemente la quitamos del array. No necesitamos tocar las alarmas,
      // porque la cadena ya se reprogramó para la siguiente dosis.
      await widget.docRef.update({
        'skippedDoses': FieldValue.arrayRemove([timestamp])
      });
    }
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
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}