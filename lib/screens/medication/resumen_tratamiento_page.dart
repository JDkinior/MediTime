// lib/screens/medication/resumen_tratamiento_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';

class ResumenTratamientoPage extends StatelessWidget {
  final Tratamiento tratamiento;

  const ResumenTratamientoPage({super.key, required this.tratamiento});

  int _calcularTotalDosis() {
    final DateTime inicio = tratamiento.fechaInicioTratamiento;
    final DateTime fin = tratamiento.fechaFinTratamiento;
    final int intervaloMinutos = tratamiento.intervaloDosis.inMinutes;

    if (inicio.isAfter(fin) || intervaloMinutos <= 0) {
      return 0;
    }

    final totalMinutes = fin.difference(inicio).inMinutes;
    return (totalMinutes / intervaloMinutos).ceil().clamp(0, 100000);
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMedicamento = tratamiento.nombreMedicamento;
    final DateTime fechaInicio = tratamiento.fechaInicioTratamiento;
    final DateTime fechaFin = tratamiento.fechaFinTratamiento;

    // Consolidar dosis omitidas desde skippedDoses y doseStatus
    final Set<DateTime> omittedDatesSet = {...tratamiento.skippedDoses};
    int tomadasEnStatus = 0;
    tratamiento.doseStatus.forEach((key, status) {
      if (status == DoseStatus.tomada) {
        tomadasEnStatus++;
      } else if (status == DoseStatus.omitida) {
        final parsed = DateTime.tryParse(key);
        if (parsed != null) {
          omittedDatesSet.add(parsed);
        }
      }
    });

    final List<DateTime> dosisOmitidas = omittedDatesSet.toList()..sort();
    final int totalDosis = _calcularTotalDosis();
    final int numOmitidas = dosisOmitidas.length;
    final int numTomadas = tomadasEnStatus > 0
        ? tomadasEnStatus
        : (tratamiento.isFinalizado && totalDosis > numOmitidas
            ? totalDosis - numOmitidas
            : 0);
    final double cumplimiento =
        totalDosis > 0 ? ((numTomadas / totalDosis) * 100).clamp(0.0, 100.0) : 0.0;

    return Scaffold(
      appBar: ModernAppBar(
        child: AppBar(
          centerTitle: true,
          title: const Text('Resumen del Tratamiento'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.primaryTextColor,
        ),
      ),
      body: ModernContentFade(
        height: 28,
        child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildHeaderCard(
    String nombreMedicamento,
    DateTime fechaInicio,
    DateTime fechaFin,
  ) {
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
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
              tratamiento.presentacion,
              style: TextStyle(color: Colors.blue.shade800),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            avatar: Icon(Icons.medication, color: Colors.blue.shade800),
            side: BorderSide.none,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateColumn('Inicio', formatter.format(fechaInicio)),
              _buildDateColumn('Fin', formatter.format(fechaFin)),
            ],
          ),
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
            color: Colors.white.withValues(alpha: 0.8),
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
          'Programadas',
          total.toString(),
          Icons.inventory,
          Colors.blue,
        ),
        _buildStatCard(
          'Tomadas',
          tomadas.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Omitidas',
          omitidas.toString(),
          Icons.cancel,
          AppTheme.errorColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCard(BuildContext context, double cumplimiento) {
    final color =
        cumplimiento >= 80
            ? Colors.green.shade600
            : (cumplimiento >= 50
                ? Colors.orange.shade600
                : AppTheme.errorColor);
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
                color: Colors.black54,
              ),
            ),
          ),
        if (skipped.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border_purple500_outlined, color: Colors.green),
                SizedBox(width: 12),
                Text(
                  '¡Tratamiento perfecto!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
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
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(formatter.format(dt)),
                  trailing: Text(
                    AppUtils.formatDoseTime(dt),
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
