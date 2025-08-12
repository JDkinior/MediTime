// lib/screens/medication/detalle_receta_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart'; // <-- CAMBIO: Importar modelo
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/widgets/treatment_form/treatment_summary_card.dart';

// CAMBIO: Convertimos a StatefulWidget para manejar el temporizador de la cuenta regresiva
class DetalleRecetaPage extends StatefulWidget {
  // CAMBIO: Recibimos el objeto Tratamiento y la hora específica de la dosis
  final Tratamiento tratamiento;
  final DateTime horaDosis;

  const DetalleRecetaPage({
    super.key,
    required this.tratamiento,
    required this.horaDosis,
  });

  @override
  State<DetalleRecetaPage> createState() => _DetalleRecetaPageState();
}

class _DetalleRecetaPageState extends State<DetalleRecetaPage> {
  Timer? _timer;
  late DateTime? _nextUpcomingDose;

  @override
  void initState() {
    super.initState();
    _nextUpcomingDose = _findNextUpcomingDose();

    if (_nextUpcomingDose != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (DateTime.now().isAfter(_nextUpcomingDose!)) {
          setState(() {
            _nextUpcomingDose = _findNextUpcomingDose();
          });
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _findNextUpcomingDose() {
    // CAMBIO: Lógica adaptada para usar el objeto Tratamiento
    final horaInicial = widget.tratamiento.horaPrimeraDosis;
    final intervalo = widget.tratamiento.intervaloDosis.inHours;
    final fechaFinTratamiento = widget.tratamiento.fechaFinTratamiento;
    final List<DateTime> dosisOmitidas = widget.tratamiento.skippedDoses;

    List<DateTime> dosisPotenciales = [];
    DateTime dosisActual = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      horaInicial.hour,
      horaInicial.minute,
    );

    while (dosisActual.isBefore(fechaFinTratamiento)) {
      if (dosisActual.isAfter(
        DateTime.now().subtract(const Duration(minutes: 1)),
      )) {
        dosisPotenciales.add(dosisActual);
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }

    for (final dosis in dosisPotenciales) {
      bool esOmitida = dosisOmitidas.any(
        (skipped) => skipped.isAtSameMomentAs(dosis),
      );
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
    final DateTime selectedDoseTime = widget.horaDosis;
    final formData = _convertToFormData();

    return Scaffold(
      appBar: AppBar(title: Text(widget.tratamiento.nombreMedicamento)),
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
              const SizedBox(height: 32),
              TreatmentSummaryCard(
                formData: formData,
                summaryInfo: _getSummaryInfo(formData),
              ),
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
        const Text(
          'Hora de esta toma',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('hh:mm a', 'es_ES').format(doseTime),
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          DateFormat('EEEE, d MMMM', 'es_ES').format(doseTime),
          style: const TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildNextDoseInfo(DateTime? nextDose, DateTime selectedDose) {
    if (nextDose == null) {
      return _buildInfoCard(
        icon: Icons.check_circle,
        color: Colors.green,
        title: 'Tratamiento Finalizado',
        subtitle: 'No hay más dosis programadas.',
      );
    }

    if (nextDose.isAtSameMomentAs(selectedDose)) {
      return _buildInfoCard(
        icon: Icons.notifications_active,
        color: Colors.blue,
        title: 'Esta es la próxima dosis',
        subtitle: _getTiempoRestante(nextDose),
      );
    }

    return _buildInfoCard(
      icon: Icons.update,
      color: Colors.orange.shade700,
      title: 'Próxima Alarma:',
      subtitle:
          '${DateFormat('hh:mm a, d MMM', 'es_ES').format(nextDose)}\n${_getTiempoRestante(nextDose)}',
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TreatmentFormData _convertToFormData() {
    // Calcular la duración real basada en las fechas de inicio y fin
    final fechaInicio = widget.tratamiento.fechaInicioTratamiento;
    final fechaFin = widget.tratamiento.fechaFinTratamiento;
    final duracionEnDias = fechaFin.difference(fechaInicio).inDays;

    // Determinar la mejor unidad y número para mostrar
    int duracionNumero;
    DurationUnit duracionUnidad;

    if (duracionEnDias >= 365) {
      // Si es más de un año, mostrar en años
      duracionNumero = (duracionEnDias / 365).round();
      duracionUnidad = DurationUnit.years;
    } else if (duracionEnDias >= 30) {
      // Si es más de un mes, mostrar en meses
      duracionNumero = (duracionEnDias / 30).round();
      duracionUnidad = DurationUnit.months;
    } else {
      // Mostrar en días
      duracionNumero = duracionEnDias;
      duracionUnidad = DurationUnit.days;
    }

    return TreatmentFormData(
      nombreMedicamento: widget.tratamiento.nombreMedicamento,
      presentacion: widget.tratamiento.presentacion,
      horaPrimeraDosis: widget.tratamiento.horaPrimeraDosis,
      intervaloDosis: widget.tratamiento.intervaloDosis.inHours,
      duracionNumero: duracionNumero,
      duracionUnidad: duracionUnidad,
      esIndefinido: false, // Los tratamientos guardados no son indefinidos
      notas: widget.tratamiento.notas,
    );
  }

  Map<String, String> _getSummaryInfo(TreatmentFormData formData) {
    final DateFormat formatter = DateFormat('d \'de\' MMMM \'de\' y', 'es_ES');
    final fechaFin = widget.tratamiento.fechaFinTratamiento;

    return {
      'durationText': formData.duracionText,
      'totalDoses': formData.totalDoses.toString(),
      'endDate': formatter.format(fechaFin),
      'Frecuencia': 'Cada ${widget.tratamiento.intervaloDosis.inHours} horas',
      'Duración': '${widget.tratamiento.duracion} días',
      'Finaliza el': formatter.format(fechaFin),
    };
  }
}
