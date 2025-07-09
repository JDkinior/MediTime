import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart'; // <-- CAMBIO: Importamos el modelo
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class DosisDiaPage extends StatelessWidget {
  // CAMBIO: Recibimos el objeto Tratamiento completo
  final Tratamiento tratamiento;
  final DateTime selectedDay;

  const DosisDiaPage({
    super.key,
    required this.tratamiento,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('d \'de\' MMMM', 'es_ES');
    // Ya no necesitamos un StreamBuilder, porque tenemos todos los datos.
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tratamiento.nombreMedicamento),
            Text(
              formatter.format(selectedDay),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (tratamiento.notas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Notas del Medicamento'),
                    content: Text(tratamiento.notas),
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
      // El cuerpo ahora es un widget que recibe el tratamiento.
      body: DosisDiaView(
        tratamiento: tratamiento,
        selectedDay: selectedDay,
      ),
    );
  }
}

class DosisDiaView extends StatefulWidget {
  final Tratamiento tratamiento;
  final DateTime selectedDay;

  const DosisDiaView({
    super.key,
    required this.tratamiento,
    required this.selectedDay,
  });

  @override
  State<DosisDiaView> createState() => _DosisDiaViewState();
}

class _DosisDiaViewState extends State<DosisDiaView> {
  Timer? _timer;
  late Tratamiento _tratamientoState; // Estado local para reflejar cambios

  @override
  void initState() {
    super.initState();
    _tratamientoState = widget.tratamiento;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  List<DateTime> _generarDosisDelDia() {
    final DateTime inicio = _tratamientoState.fechaInicioTratamiento;
    final DateTime fechaFin = _tratamientoState.fechaFinTratamiento;
    final int intervalo = int.parse(_tratamientoState.intervaloDosis);
    List<DateTime> dosisGeneradas = [];
    DateTime dosisActual = inicio;

    while (dosisActual.isBefore(fechaFin)) {
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
    final firestoreService = context.read<FirestoreService>();
    final docRef = firestoreService.getMedicamentoDocRef(FirebaseAuth.instance.currentUser!.uid, _tratamientoState.id);
    final timestamp = Timestamp.fromDate(dosisTime);
    
    // CAMBIO: Pasamos el objeto _tratamientoState directamente al servicio.
    // Ya no es necesario obtener un Map de la base de datos.
    if (!fueOmitida) {
      await docRef.update({'skippedDoses': FieldValue.arrayUnion([timestamp])});
      // Le pasamos nuestro objeto de estado local.
      await NotificationService.omitDoseAndReschedule(tratamiento: _tratamientoState, docRef: docRef);
      setState(() {
        _tratamientoState.skippedDoses.add(dosisTime);
      });
    } else {
      await docRef.update({'skippedDoses': FieldValue.arrayRemove([timestamp])});
      // Le pasamos nuestro objeto de estado local.
      await NotificationService.undoOmissionAndReschedule(tratamiento: _tratamientoState, docRef: docRef);
      setState(() {
        _tratamientoState.skippedDoses.removeWhere((d) => d.isAtSameMomentAs(dosisTime));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dosisDelDia = _generarDosisDelDia();
    final List<DateTime> dosisOmitidas = _tratamientoState.skippedDoses;
    
    int tomadasHoy = dosisDelDia
        .where((d) => d.isBefore(DateTime.now()) && !dosisOmitidas.any((om) => om.isAtSameMomentAs(d)))
        .length;

    final double progress = dosisDelDia.isEmpty ? 0 : tomadasHoy / dosisDelDia.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDailyHeader(dosisDelDia.length, tomadasHoy, progress),
          const SizedBox(height: 20),
          if (dosisDelDia.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No hay dosis para este día.", textAlign: TextAlign.center),
            )
          else
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