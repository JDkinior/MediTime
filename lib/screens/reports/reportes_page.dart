import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/pdf_report_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'adherencia_chart.dart';
import 'package:meditime/services/tratamiento_service.dart';

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
  Map<String, int> _calcularEstadisticas(Tratamiento tratamiento, Map<String, DateTime> dateRange) {
    int tomadas = 0;
    int omitidas = 0;
    int programadasPasadas = 0;

    final now = DateTime.now();
    final start = dateRange['start']!;
    final end = dateRange['end']!;

    if (tratamiento.doseStatus.isEmpty) {
      final todasLasDosis = TratamientoService().generarDosisTotales(tratamiento);
      for (var doseTime in todasLasDosis) {
        if (!doseTime.isBefore(start) && !doseTime.isAfter(end)) {
          if (doseTime.isBefore(now)) {
            programadasPasadas++;
            omitidas++;
          }
        }
      }
    } else {
      tratamiento.doseStatus.forEach((key, status) {
        final doseTime = DateTime.parse(key);
        if (!doseTime.isBefore(start) && !doseTime.isAfter(end)) {
          if (doseTime.isBefore(now)) {
            programadasPasadas++;
            if (status == DoseStatus.tomada) {
              tomadas++;
            } else if (status == DoseStatus.omitida) {
              omitidas++;
            } else {
              omitidas++;
            }
          }
        }
      });
    }

    return {
      'tomadas': tomadas,
      'omitidas': omitidas,
      'programadasPasadas': programadasPasadas,
    };
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
                  final stats = _calcularEstadisticas(tratamiento, dateRangePdf);
                  final int dosisProgramadas = stats['programadasPasadas']!;
                  final int dosisOmitidas = stats['omitidas']!;
                  final int dosisTomadas = stats['tomadas']!;

                  if (dosisProgramadas > 0) {
                      totalDosisTomadasGlobal += dosisTomadas;
                      totalDosisOmitidasGlobal += dosisOmitidas;
                      tratamientosData.add({
                          'nombreMedicamento': tratamiento.nombreMedicamento,
                          'adherencia': (dosisTomadas / dosisProgramadas) * 100,
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
          _buildIntervalSelector(),
                Expanded(
                  // CAMBIO: El StreamBuilder ahora espera una List<Tratamiento>
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
                       int totalDosisOmitidas = 0;
                       int totalDosisTomadas = 0;
                       final todosLosTratamientos = snapshot.data!;
 
                       for (var tratamiento in todosLosTratamientos) {
                         final stats = _calcularEstadisticas(tratamiento, dateRange);
                         totalDosisOmitidas += stats['omitidas']!;
                         totalDosisTomadas += stats['tomadas']!;
                       }

                      return ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildOverallAdherenceCard(totalDosisTomadas, totalDosisOmitidas),
                          const SizedBox(height: 24),
                          const Text("Desglose por Tratamiento", style: kSectionTitleStyle),
                          const SizedBox(height: 12),
                          ...todosLosTratamientos.map((tratamiento) {
                            return _buildTratamientoCard(tratamiento, dateRange);
                          }),
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
    final bool hasData = total > 0;
    final double adherencia = hasData ? (tomadas / total) * 100 : 0.0;

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
                  hasData ? "${adherencia.toStringAsFixed(1)}%" : "N/A",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: hasData ? const Color(0xFF2F71B6) : Colors.grey.shade400,
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
              child: hasData
                  ? AdherenceBarChart(
                      tomadas: tomadas.toDouble(),
                      omitidas: omitidas.toDouble(),
                    )
                  : Center(
                      child: Text(
                        "Sin datos de tomas en este período",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
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

  Widget _buildTratamientoCard(Tratamiento tratamiento, Map<String, DateTime> dateRange) {
    final stats = _calcularEstadisticas(tratamiento, dateRange);
    final int dosisProgramadas = stats['programadasPasadas']!;
    final int dosisTomadas = stats['tomadas']!;

    final bool tieneDosis = dosisProgramadas > 0;
    final double adherencia = tieneDosis
        ? (dosisTomadas / dosisProgramadas) * 100
        : 0.0;

    final progressColor = !tieneDosis
        ? Colors.grey.shade400
        : (adherencia >= 80
            ? kSuccessColor
            : (adherencia >= 50 ? Colors.orange : kErrorColor));

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
            Text(tratamiento.nombreMedicamento,
                style: kSectionTitleStyle.copyWith(color: kSecondaryColor)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Cumplimiento", style: kBodyTextStyle),
                Text(tieneDosis ? "${adherencia.toStringAsFixed(1)}%" : "N/A",
                    style: kPageTitleStyle.copyWith(
                      fontSize: 20,
                      color: progressColor,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: tieneDosis ? (adherencia == 0 ? 0.05 : adherencia / 100) : 0.0,
                backgroundColor: progressColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tieneDosis
                  ? "Tomadas: $dosisTomadas / Programadas: $dosisProgramadas"
                  : "Sin dosis programadas en este período",
              style: kSubtitleTextStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6), // Slate / light grey
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ReportInterval.values.map((interval) {
          final isSelected = _selectedInterval == interval;
          String text = '';
          switch (interval) {
            case ReportInterval.semana:
              text = 'Semana';
              break;
            case ReportInterval.mes:
              text = 'Mes';
              break;
            case ReportInterval.anio:
              text = 'Año';
              break;
            case ReportInterval.todo:
              text = 'Todo';
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedInterval = interval;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF1E3C72),
                            Color(0xFF2A5298),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1E3C72).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}