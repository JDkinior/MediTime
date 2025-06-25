import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Definimos la sombra como una constante para reutilizarla y mantener la consistencia.
const kCustomBoxShadow = [
  BoxShadow(
    color: Color.fromARGB(20, 47, 109, 180), // Sombra azul sutil
    blurRadius: 6,
    spreadRadius: 3,
    offset: Offset(0, 4),
  ),
];

class ResumenTratamientoPage extends StatelessWidget {
  final Map<String, dynamic> tratamiento;

  const ResumenTratamientoPage({super.key, required this.tratamiento});

  // Función para calcular el total de dosis que debieron tomarse
  int _calcularTotalDosis() {
    final DateTime inicio =
        (tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
    final DateTime fin =
        (tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervaloHoras = int.parse(tratamiento['intervaloDosis']);

    if (inicio.isAfter(fin) || intervaloHoras <= 0) {
      return 0;
    }

    int totalDosis = 0;
    DateTime dosisActual = inicio;

    while (dosisActual.isBefore(fin)) {
      totalDosis++;
      dosisActual = dosisActual.add(Duration(hours: intervaloHoras));
    }
    return totalDosis;
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMedicamento = tratamiento['nombreMedicamento'] ?? 'N/A';
    final DateTime fechaInicio =
        (tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
    final DateTime fechaFin =
        (tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
    final List<dynamic> dosisOmitidasRaw = tratamiento['skippedDoses'] ?? [];
    final List<DateTime> dosisOmitidas =
        dosisOmitidasRaw.map((ts) => (ts as Timestamp).toDate()).toList();

    final int totalDosis = _calcularTotalDosis();
    final int numOmitidas = dosisOmitidas.length;
    final int numTomadas =
        totalDosis > numOmitidas ? totalDosis - numOmitidas : 0;
    final double cumplimiento =
        totalDosis > 0 ? (numTomadas / totalDosis) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del Tratamiento'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(nombreMedicamento, fechaInicio, fechaFin),
            const SizedBox(height: 24),
            _buildStatsGrid(totalDosis, numTomadas, numOmitidas),
            const SizedBox(height: 24),
            _buildComplianceCard(context, cumplimiento),
            const SizedBox(height: 24),
            _buildSkippedDosesList(dosisOmitidas),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
      String nombreMedicamento, DateTime fechaInicio, DateTime fechaFin) {
    final DateFormat formatter = DateFormat('d MMM y', 'es_ES');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [Color(0xFF3FB8EE), Color(0xFF4092E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombreMedicamento,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(
              tratamiento['presentacion'] ?? 'N/A',
              style: TextStyle(color: Colors.blue.shade800),
            ),
            backgroundColor: Colors.white.withOpacity(0.9),
            avatar: Icon(Icons.medication, color: Colors.blue.shade800),
            // --- ESTA ES LA CORRECCIÓN DEFINITIVA ---
            side: BorderSide.none,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateColumn('Inicio', formatter.format(fechaInicio)),
              _buildDateColumn('Fin', formatter.format(fechaFin)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDateColumn(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        Text(
          date,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(int total, int tomadas, int omitidas) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
            'Programadas', total.toString(), Icons.inventory, Colors.blue),
        _buildStatCard(
            'Tomadas', tomadas.toString(), Icons.check_circle, Colors.green),
        _buildStatCard(
            'Omitidas', omitidas.toString(), Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCard(BuildContext context, double cumplimiento) {
    final color = cumplimiento >= 80
        ? Colors.green.shade600
        : (cumplimiento >= 50 ? Colors.orange.shade600 : Colors.red.shade600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: kCustomBoxShadow,
      ),
      child: Row(
        children: [
          const Text(
            'Tasa de Cumplimiento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            '${cumplimiento.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkippedDosesList(List<DateTime> skipped) {
    final DateFormat formatter = DateFormat('EEEE, d MMM', 'es_ES');
    final timeFormatter = DateFormat('hh:mm a', 'es_ES');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (skipped.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Historial de Dosis Omitidas',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
          ),
        if (skipped.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border_purple500_outlined, color: Colors.green),
                SizedBox(width: 12),
                Text('¡Tratamiento perfecto!',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        else
          ListView.builder(
            itemCount: skipped.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final dt = skipped[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: kCustomBoxShadow,
                ),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  title: Text(formatter.format(dt)),
                  trailing: Text(
                    timeFormatter.format(dt),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}