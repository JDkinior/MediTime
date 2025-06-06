import 'dart:async'; // Importamos 'async' para poder usar el Timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- PASO 1: CONVERTIR A STATEFULWIDGET ---
class DetalleRecetaPage extends StatefulWidget {
  final Map<String, dynamic> receta;

  const DetalleRecetaPage({super.key, required this.receta});

  @override
  State<DetalleRecetaPage> createState() => _DetalleRecetaPageState();
}

class _DetalleRecetaPageState extends State<DetalleRecetaPage> {
  Timer? _timer; // El timer que refrescará la UI
  late DateTime? _nextUpcomingDose; // Guardaremos la próxima dosis en el estado

  // --- PASO 2: INICIALIZAR EL TIMER Y EL ESTADO ---
  @override
  void initState() {
    super.initState();
    // Calculamos la próxima dosis una vez al iniciar
    _nextUpcomingDose = _findNextUpcomingDose();

    // Si hay una próxima dosis, configuramos el timer
    if (_nextUpcomingDose != null) {
      // El timer se activa cada segundo
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // Verificamos si la dosis ya pasó
        if (DateTime.now().isAfter(_nextUpcomingDose!)) {
          // Si ya pasó, recalculamos la próxima y cancelamos este timer
          // para reconfigurarlo si es necesario.
          setState(() {
            _nextUpcomingDose = _findNextUpcomingDose();
          });
          timer.cancel(); 
        } else {
          // Si no ha pasado, simplemente llamamos a setState para redibujar
          // y actualizar el contador.
          setState(() {});
        }
      });
    }
  }

  // --- PASO 3: CANCELAR EL TIMER AL SALIR DE LA PANTALLA ---
  @override
  void dispose() {
    _timer?.cancel(); // Muy importante para evitar fugas de memoria
    super.dispose();
  }

  // Lógica para encontrar la próxima dosis (sin cambios)
  DateTime? _findNextUpcomingDose() {
    final horaInicial = DateFormat('HH:mm').parse(widget.receta['horaPrimeraDosis']);
    final intervalo = int.parse(widget.receta['intervaloDosis']);
    final fechaFinTratamiento = (widget.receta['fechaFinTratamiento'] as Timestamp).toDate();
    final List<dynamic> skippedDosesRaw = widget.receta['skippedDoses'] ?? [];
    final List<DateTime> dosisOmitidas = skippedDosesRaw.map((ts) => (ts as Timestamp).toDate()).toList();

    List<DateTime> dosisPotenciales = [];
    DateTime dosisActual = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      horaInicial.hour,
      horaInicial.minute,
    );

    while (dosisActual.isBefore(fechaFinTratamiento)) {
      if (dosisActual.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
        dosisPotenciales.add(dosisActual);
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }

    for (final dosis in dosisPotenciales) {
      bool esOmitida = dosisOmitidas.any((skipped) => skipped.isAtSameMomentAs(dosis));
      if (!esOmitida) {
        return dosis;
      }
    }
    return null;
  }

  // --- PASO 4: ACTUALIZAR LA LÓGICA DEL TIEMPO RESTANTE ---
  String _getTiempoRestante(DateTime proximaDosis) {
    final ahora = DateTime.now();
    final diferencia = proximaDosis.difference(ahora);

    if (diferencia.isNegative) return 'Es momento de tomar la dosis';
    
    // Si falta menos de un minuto, muestra los segundos
    if (diferencia.inMinutes < 1) {
      return 'En ${diferencia.inSeconds} segundos';
    }

    final dias = diferencia.inDays;
    final horas = diferencia.inHours % 24;
    final minutos = diferencia.inMinutes % 60;

    if (dias > 0) return 'En $dias días y $horas horas';
    if (horas > 0) return 'En $horas horas y $minutos minutos';
    return 'En $minutos minutos';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime selectedDoseTime = widget.receta['horaDosis'];
    final String duracionTratamiento = widget.receta['duracion'] ?? 'N/A';
    final DateTime fechaFin = (widget.receta['fechaFinTratamiento'] as Timestamp).toDate();
    final DateFormat formatter = DateFormat('d \'de\' MMMM \'de\' y', 'es_ES');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receta['nombreMedicamento']),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSelectedDoseDisplay(selectedDoseTime),
              const SizedBox(height: 32),
              _buildNextDoseInfo(_nextUpcomingDose, selectedDoseTime),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Medicamento:', widget.receta['nombreMedicamento']),
              _buildDetailRow('Presentación:', widget.receta['presentacion']),
              _buildDetailRow('Frecuencia:', 'Cada ${widget.receta['intervaloDosis']} horas'),
              _buildDetailRow('Duración:', '$duracionTratamiento días'),
              _buildDetailRow('Finaliza el:', formatter.format(fechaFin)),
            ],
          ),
        ),
      ),
    );
  }

  // --- El resto de los widgets de construcción (sin cambios) ---

  Widget _buildSelectedDoseDisplay(DateTime doseTime) {
    return Column(
      children: [
        const Text('Hora de esta toma', style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(DateFormat('hh:mm a', 'es_ES').format(doseTime), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.blue)),
        Text(DateFormat('EEEE, d MMMM', 'es_ES').format(doseTime), style: const TextStyle(fontSize: 18, color: Colors.black54)),
      ],
    );
  }

  Widget _buildNextDoseInfo(DateTime? nextDose, DateTime selectedDose) {
    if (nextDose == null) {
      return _buildInfoCard(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'Tratamiento Finalizado',
          subtitle: 'No hay más dosis programadas.');
    }

    if (nextDose.isAtSameMomentAs(selectedDose)) {
      return _buildInfoCard(
          icon: Icons.notifications_active,
          color: Colors.blue,
          title: 'Esta es la próxima dosis',
          subtitle: _getTiempoRestante(nextDose));
    }
    
    return _buildInfoCard(
      icon: Icons.update,
      color: Colors.orange.shade700,
      title: 'Próxima Alarma:',
      subtitle: '${DateFormat('hh:mm a, d MMM', 'es_ES').format(nextDose)}\n${_getTiempoRestante(nextDose)}',
    );
  }
  
  Widget _buildInfoCard({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}