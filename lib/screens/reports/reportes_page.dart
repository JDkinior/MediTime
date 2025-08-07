import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/pdf_report_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'adherencia_chart.dart';

// Enum para manejar los intervalos de forma clara
enum ReportInterval { semana, mes, anio, todo }

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  // Estado para manejar el intervalo seleccionado
  ReportInterval _selectedInterval = ReportInterval.todo;
  final GlobalKey _chartKey = GlobalKey();
  final PdfReportService _pdfService = PdfReportService();

  // Función para capturar el widget como una imagen
  Future<Uint8List?> _capturePng() async {
    try {
      if (_chartKey.currentContext == null) return null;
      RenderRepaintBoundary boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("Error capturando imagen: $e");
      return null;
    }
  }

  // Función para obtener el rango de fechas según el intervalo
  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    switch (_selectedInterval) {
      case ReportInterval.semana:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case ReportInterval.mes:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case ReportInterval.anio:
        startDate = DateTime(now.year, 1, 1);
        break;
      case ReportInterval.todo:
        startDate = DateTime(2000);
        break;
    }
    return {
      'start': DateTime(startDate.year, startDate.month, startDate.day),
      'end': now,
    };
  }

  // Lógica de cálculo de dosis, ahora con rango de fechas
  int _calcularTotalDosis(Map<String, dynamic> tratamiento,
      Map<String, DateTime> dateRange) {
    DateTime inicioTratamiento =
        (tratamiento['fechaInicioTratamiento'] as Timestamp).toDate();
    DateTime finTratamiento =
        (tratamiento['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervaloHoras =
        int.tryParse(tratamiento['intervaloDosis'] ?? '0') ?? 0;

    DateTime effectiveStart =
        inicioTratamiento.isAfter(dateRange['start']!)
            ? inicioTratamiento
            : dateRange['start']!;
    DateTime effectiveEnd = finTratamiento.isBefore(dateRange['end']!)
        ? finTratamiento
        : dateRange['end']!;

    if (effectiveStart.isAfter(effectiveEnd) || intervaloHoras <= 0) return 0;

    int totalDosis = 0;
    DateTime dosisActual = inicioTratamiento;

    while (dosisActual.isBefore(finTratamiento)) {
      if (!dosisActual.isBefore(effectiveStart) &&
          !dosisActual.isAfter(effectiveEnd)) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Adherencia'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final imageBytes = await _capturePng();
              if (imageBytes == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Error al generar el gráfico del reporte.")),
                  );
                }
                return;
              }

               final List<Tratamiento> tratamientos = await firestoreService.getMedicamentosStream(user!.uid).first;
              final dateRangePdf = _getDateRange();
              
              List<Map<String, dynamic>> tratamientosData = [];
              int totalDosisTomadasGlobal = 0;
              int totalDosisOmitidasGlobal = 0;

              // CAMBIO: Iteramos sobre la lista de objetos Tratamiento.
              for (var tratamiento in tratamientos) {
                  final dataMap = {
                    'nombreMedicamento': tratamiento.nombreMedicamento,
                    'fechaInicioTratamiento': Timestamp.fromDate(tratamiento.fechaInicioTratamiento),
                    'fechaFinTratamiento': Timestamp.fromDate(tratamiento.fechaFinTratamiento),
                    'intervaloDosis': tratamiento.intervaloDosis.inHours.toString(),
                    'skippedDoses': tratamiento.skippedDoses.map((d) => Timestamp.fromDate(d)).toList(),
                  };
                  final dosisProgramadas = _calcularTotalDosis(dataMap, dateRangePdf);
                  int dosisOmitidas = 0;

                  for (var skippedDate in tratamiento.skippedDoses) {
                      if (skippedDate.isAfter(dateRangePdf['start']!) && skippedDate.isBefore(dateRangePdf['end']!)) {
                          dosisOmitidas++;
                      }
                  }

                  if (dosisProgramadas > 0) {
                      final dosisTomadas = dosisProgramadas - dosisOmitidas;
                      totalDosisTomadasGlobal += dosisTomadas;
                      totalDosisOmitidasGlobal += dosisOmitidas;
                      tratamientosData.add({
                          'nombreMedicamento': tratamiento.nombreMedicamento,
                          'adherencia': dosisProgramadas > 0 ? (dosisTomadas / dosisProgramadas) * 100 : 0.0,
                          'tomadas': dosisTomadas,
                          'programadas': dosisProgramadas,
                      });
                  }
              }
              
              await _pdfService.generateAndShowPdf(
                intervalText: _selectedInterval.toString().split('.').last.toUpperCase(),
                tomadas: totalDosisTomadasGlobal,
                omitidas: totalDosisOmitidasGlobal,
                tratamientos: tratamientosData,
                chartImage: imageBytes,
              );
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver tus reportes.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SegmentedButton<ReportInterval>(
                    segments: const [
                      ButtonSegment(value: ReportInterval.semana, label: Text('Semana')),
                      ButtonSegment(value: ReportInterval.mes, label: Text('Mes')),
                      ButtonSegment(value: ReportInterval.anio, label: Text('Año')),
                      ButtonSegment(value: ReportInterval.todo, label: Text('Todo')),
                    ],
                    selected: {_selectedInterval},
                    onSelectionChanged: (Set<ReportInterval> newSelection) {
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
                  // CAMBIO: El StreamBuilder ahora espera una List<Tratamiento>
                  child: StreamBuilder<List<Tratamiento>>(
                    stream: firestoreService.getMedicamentosStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
                      }
                      if (snapshot.hasError) {
                        return EstadoVista(
                          state: ViewState.error,
                          errorMessage: "Error al cargar los datos para el reporte.",
                          onRetry: () => setState(() {}),
                          child: const SizedBox.shrink(),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const EstadoVista(
                          state: ViewState.empty,
                          emptyMessage: 'No hay tratamientos para generar un reporte.',
                          child: SizedBox.shrink(),
                        );
                      }

                  return EstadoVista(
                    state: ViewState.success,
                    child: Builder(builder: (context) {
                      int totalDosisProgramadas = 0;
                      int totalDosisOmitidas = 0;
                      // CAMBIO: Obtenemos la lista de tratamientos directamente.
                      final todosLosTratamientos = snapshot.data!;

                      // CAMBIO: Iteramos sobre la lista de objetos Tratamiento.
                      for (var tratamiento in todosLosTratamientos) {
                        // Pasamos el objeto a un Map para mantener la compatibilidad con _calcularTotalDosis
                        // (Idealmente, también refactorizaríamos esa función).
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
                          // CAMBIO: Usamos la lista directamente aquí también.
                          ...todosLosTratamientos.map((tratamiento) {
                             final dataMap = {
                                'nombreMedicamento': tratamiento.nombreMedicamento,
                                'fechaInicioTratamiento': Timestamp.fromDate(tratamiento.fechaInicioTratamiento),
                                'fechaFinTratamiento': Timestamp.fromDate(tratamiento.fechaFinTratamiento),
                                'intervaloDosis': tratamiento.intervaloDosis.inHours.toString(),
                                'skippedDoses': tratamiento.skippedDoses.map((d) => Timestamp.fromDate(d)).toList(),
                            };
                            return _buildTratamientoCard(dataMap, dateRange);
                          }).toList(),
                        ],
                      );
                    }),
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

    return RepaintBoundary(
      key: _chartKey,
      child: Container(
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
              color: Color(0xFF2F71B6)),
        )
      ],
    );
  }

  Widget _buildTratamientoCard(
      Map<String, dynamic> tratamiento, Map<String, DateTime> dateRange) {
    final int dosisProgramadas = _calcularTotalDosis(tratamiento, dateRange);
    if (dosisProgramadas == 0) return const SizedBox.shrink();

    final List<dynamic> skippedDoses = tratamiento['skippedDoses'] ?? [];
    int dosisOmitidas = 0;
    for (var timestamp in skippedDoses) {
      final skippedDate = (timestamp as Timestamp).toDate();
      if (skippedDate.isAfter(dateRange['start']!) &&
          skippedDate.isBefore(dateRange['end']!)) {
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