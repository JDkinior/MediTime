import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'adherencia_chart.dart';

enum ProgresoInterval { semana, mes, anio, todo }

class ProgresoPage extends StatefulWidget {
  const ProgresoPage({super.key});

  @override
  State<ProgresoPage> createState() => _ProgresoPageState();
}

class _ProgresoPageState extends State<ProgresoPage> {
  ProgresoInterval _selectedInterval = ProgresoInterval.todo;

  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    switch (_selectedInterval) {
      case ProgresoInterval.semana:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case ProgresoInterval.mes:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case ProgresoInterval.anio:
        startDate = DateTime(now.year, 1, 1);
        break;
      case ProgresoInterval.todo:
        startDate = DateTime(2000);
        break;
    }
    return {
      'start': DateTime(startDate.year, startDate.month, startDate.day),
      'end': now,
    };
  }

  int _calcularTotalDosis(Map<String, dynamic> tratamiento, Map<String, DateTime> dateRange) {
    DateTime inicioTratamiento = (tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
    DateTime finTratamiento = (tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervaloHoras = int.tryParse(tratamiento['intervaloDosis'] ?? '0') ?? 0;

    DateTime effectiveStart = inicioTratamiento.isAfter(dateRange['start']!)
        ? inicioTratamiento
        : dateRange['start']!;
    DateTime effectiveEnd = finTratamiento.isBefore(dateRange['end']!)
        ? finTratamiento
        : dateRange['end']!;

    if (effectiveStart.isAfter(effectiveEnd) || intervaloHoras <= 0) return 0;

    int totalDosis = 0;
    DateTime dosisActual = inicioTratamiento;

    while (dosisActual.isBefore(finTratamiento)) {
      if (!dosisActual.isBefore(effectiveStart) && !dosisActual.isAfter(effectiveEnd)) {
        totalDosis++;
      }
      dosisActual = dosisActual.add(Duration(hours: intervaloHoras));
    }
    return totalDosis;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;
    final dateRange = _getDateRange();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tu progreso.')),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: SegmentedButton<ProgresoInterval>(
              segments: const [
                ButtonSegment(value: ProgresoInterval.semana, label: Text('Semana')),
                ButtonSegment(value: ProgresoInterval.mes, label: Text('Mes')),
                ButtonSegment(value: ProgresoInterval.anio, label: Text('Año')),
                ButtonSegment(value: ProgresoInterval.todo, label: Text('Todo')),
              ],
              selected: {_selectedInterval},
              onSelectionChanged: (Set<ProgresoInterval> newSelection) {
                setState(() {
                  _selectedInterval = newSelection.first;
                });
              },
              selectedIcon: const SizedBox.shrink(),
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: const Color(0xFF4092E4),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Tratamiento>>(
              initialData: firestoreService.getCachedMedicamentos(user.uid),
              stream: firestoreService.getMedicamentosStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
                }
                if (snapshot.hasError) {
                  return EstadoVista(
                    state: ViewState.error,
                    errorMessage: "Error al cargar los datos de progreso.",
                    onRetry: () => setState(() {}),
                    child: const SizedBox.shrink(),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const EstadoVista(
                    state: ViewState.empty,
                    emptyMessage: 'Aún no tienes tratamientos registrados.',
                    child: SizedBox.shrink(),
                  );
                }

                int totalDosisProgramadas = 0;
                int totalDosisOmitidas = 0;
                final todosLosTratamientos = snapshot.data!;

                for (var tratamiento in todosLosTratamientos) {
                  final dataMap = {
                    'fechaInicioTratamiento': Timestamp.fromDate(tratamiento.fechaInicioTratamiento),
                    'fechaFinTratamiento': Timestamp.fromDate(tratamiento.fechaFinTratamiento),
                    'intervaloDosis': tratamiento.intervaloDosis.inHours.toString(),
                    'skippedDoses': tratamiento.skippedDoses.map((d) => Timestamp.fromDate(d)).toList(),
                  };
                  totalDosisProgramadas += _calcularTotalDosis(dataMap, dateRange);

                  for (var skippedDate in tratamiento.skippedDoses) {
                    if (skippedDate.isAfter(dateRange['start']!) && skippedDate.isBefore(dateRange['end']!)) {
                      totalDosisOmitidas++;
                    }
                  }
                }

                final int totalDosisTomadas = totalDosisProgramadas - totalDosisOmitidas;

                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildOverallAdherenceCard(totalDosisTomadas, totalDosisOmitidas),
                    const SizedBox(height: 24),
                    const Text("Desglose por Tratamiento", style: kSectionTitleStyle),
                    const SizedBox(height: 12),
                    ...todosLosTratamientos.map((tratamiento) {
                      final dataMap = {
                        'nombreMedicamento': tratamiento.nombreMedicamento,
                        'fechaInicioTratamiento': Timestamp.fromDate(tratamiento.fechaInicioTratamiento),
                        'fechaFinTratamiento': Timestamp.fromDate(tratamiento.fechaFinTratamiento),
                        'intervaloDosis': tratamiento.intervaloDosis.inHours.toString(),
                        'skippedDoses': tratamiento.skippedDoses.map((d) => Timestamp.fromDate(d)).toList(),
                      };
                      return _buildTratamientoCard(dataMap, dateRange);
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallAdherenceCard(int tomadas, int omitidas) {
    final int total = tomadas + omitidas;
    final double adherencia = total > 0 ? (tomadas / total) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCustomBoxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RESUMEN GENERAL",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "${adherencia.toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F71B6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Tasa de Adherencia",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: AdherenceBarChart(
              tomadas: tomadas.toDouble(),
              omitidas: omitidas.toDouble(),
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomStat("Dosis Totales", total.toString()),
              _buildBottomStat("Completadas", tomadas.toString()),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBottomStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2F71B6),
          ),
        )
      ],
    );
  }

  Widget _buildTratamientoCard(Map<String, dynamic> tratamiento, Map<String, DateTime> dateRange) {
    final int dosisProgramadas = _calcularTotalDosis(tratamiento, dateRange);
    if (dosisProgramadas == 0) return const SizedBox.shrink();

    final List<dynamic> skippedDoses = tratamiento['skippedDoses'] ?? [];
    int dosisOmitidas = 0;
    for (var timestamp in skippedDoses) {
      final skippedDate = (timestamp as Timestamp).toDate();
      if (skippedDate.isAfter(dateRange['start']!) && skippedDate.isBefore(dateRange['end']!)) {
        dosisOmitidas++;
      }
    }
    final int dosisTomadas = dosisProgramadas - dosisOmitidas;
    final double adherencia =
        dosisProgramadas > 0 ? (dosisTomadas / dosisProgramadas) * 100 : 0.0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color.fromARGB(20, 47, 109, 180),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tratamiento['nombreMedicamento'] ?? 'N/A',
                style: kSectionTitleStyle.copyWith(color: kSecondaryColor)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Cumplimiento", style: kBodyTextStyle),
                Text("${adherencia.toStringAsFixed(1)}%",
                    style: kPageTitleStyle.copyWith(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: adherencia / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                  adherencia > 80 ? kSuccessColor : kErrorColor),
            ),
            const SizedBox(height: 8),
            Text("Tomadas: $dosisTomadas / Programadas: $dosisProgramadas",
                style: kSubtitleTextStyle),
          ],
        ),
      ),
    );
  }
}
