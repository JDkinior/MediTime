// lib/screens/reports/progreso_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'adherencia_chart.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:intl/intl.dart';

enum ProgresoInterval { semana, mes, anio, todo }

class TodayDose {
  final String idTratamiento;
  final String nombreMedicamento;
  final String presentacion;
  final DateTime hora;
  final DoseStatus status;

  TodayDose({
    required this.idTratamiento,
    required this.nombreMedicamento,
    required this.presentacion,
    required this.hora,
    required this.status,
  });
}

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

  Map<String, int> _calcularEstadisticas(Tratamiento tratamiento, Map<String, DateTime> dateRange) {
    int tomadas = 0;
    int omitidas = 0;
    int programadasPasadas = 0;

    final now = DateTime.now();
    final start = dateRange['start']!;
    final end = dateRange['end']!;

    if (tratamiento.doseStatus.isEmpty) {
      final todasLasDosis = TratamientoService().generarDosisEnRango(tratamiento, start, end);
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

  Map<String, int> _calcularEstadisticasCompletasDelDia(Tratamiento tratamiento, Map<String, DateTime> dateRange) {
    int tomadas = 0;
    int totalProgramadas = 0;

    final start = dateRange['start']!;
    final end = dateRange['end']!;

    if (tratamiento.doseStatus.isEmpty) {
      final todasLasDosis = TratamientoService().generarDosisEnRango(tratamiento, start, end);
      for (var doseTime in todasLasDosis) {
        if (!doseTime.isBefore(start) && !doseTime.isAfter(end)) {
          totalProgramadas++;
        }
      }
    } else {
      tratamiento.doseStatus.forEach((key, status) {
        final doseTime = DateTime.parse(key);
        if (!doseTime.isBefore(start) && !doseTime.isAfter(end)) {
          totalProgramadas++;
          if (status == DoseStatus.tomada) {
            tomadas++;
          }
        }
      });
    }

    return {
      'tomadas': tomadas,
      'totalProgramadas': totalProgramadas,
    };
  }

  List<double> _calcularCumplimientoSemanal(List<Tratamiento> tratamientos) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);

    List<double> porcentajes = [];

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

      int tomadas = 0;
      int programadas = 0;

      for (var t in tratamientos) {
        final range = {'start': dayStart, 'end': dayEnd};
        final stats = _calcularEstadisticasCompletasDelDia(t, range);
        tomadas += stats['tomadas']!;
        programadas += stats['totalProgramadas']!;
      }

      if (programadas > 0) {
        porcentajes.add((tomadas / programadas) * 100);
      } else {
        if (day.isAfter(now)) {
          porcentajes.add(0.0);
        } else {
          porcentajes.add(100.0);
        }
      }
    }

    return porcentajes;
  }

  int _calcularRacha(List<Tratamiento> tratamientos) {
    if (tratamientos.isEmpty) return 0;
    int racha = 0;
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final dateToCheck = now.subtract(Duration(days: i));
      final dateStr =
          "${dateToCheck.year}-${dateToCheck.month.toString().padLeft(2, '0')}-${dateToCheck.day.toString().padLeft(2, '0')}";

      bool perfectDay = true;
      bool hasDosesOnDay = false;

      for (var t in tratamientos) {
        t.doseStatus.forEach((key, status) {
          if (key.startsWith(dateStr)) {
            hasDosesOnDay = true;
            final doseTime = DateTime.parse(key);
            if (doseTime.isBefore(now)) {
              if (status != DoseStatus.tomada) {
                perfectDay = false;
              }
            }
          }
        });
      }

      if (hasDosesOnDay) {
        if (perfectDay) {
          racha++;
        } else {
          break;
        }
      }
    }
    return racha;
  }

  List<TodayDose> _obtenerDosisDeHoy(List<Tratamiento> tratamientos) {
    final List<TodayDose> list = [];
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    for (var t in tratamientos) {
      t.doseStatus.forEach((key, status) {
        if (key.startsWith(todayStr)) {
          final doseTime = DateTime.parse(key);
          list.add(TodayDose(
            idTratamiento: t.id,
            nombreMedicamento: t.nombreMedicamento,
            presentacion: t.presentacion,
            hora: doseTime,
            status: status,
          ));
        }
      });
    }

    list.sort((a, b) => a.hora.compareTo(b.hora));
    return list;
  }

  Widget _buildAdherenceRingCard(double? percentage, int tomadas, int omitidas) {
    final hasData = percentage != null;
    final color = !hasData
        ? Colors.grey.shade400
        : (percentage >= 80
            ? AppTheme.successColor
            : (percentage >= 50 ? Colors.orange : AppTheme.errorColor));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tu desempeño general",
            style: TextStyle(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(flex: 1),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: hasData ? percentage / 100 : 0.0,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppTheme.surfaceColor,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasData ? "${percentage.toStringAsFixed(0)}%" : "N/A",
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Adherencia",
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(flex: 2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tomadas",
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$tomadas",
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Omitidas",
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$omitidas",
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakAndInsightCard(int racha, double? percentage) {
    String insightTitle = "Info";
    String insightText = "";
    Color insightColor = AppTheme.primaryColor;
    IconData insightIcon = Icons.info_outline;

    if (percentage == null) {
      insightTitle = "Sin datos";
      insightText = "No hay dosis programadas. Agrega medicamentos para ver tu progreso.";
      insightColor = Colors.grey;
      insightIcon = Icons.info_outline;
    } else if (percentage >= 80) {
      insightTitle = "¡Buen ritmo!";
      insightText = "Pequeños hábitos, grandes resultados. ¡Sigue así!";
      insightColor = AppTheme.successColor;
      insightIcon = Icons.lightbulb_outline;
    } else if (percentage >= 50) {
      insightTitle = "Atención";
      insightText = "Buen ritmo, pero has tenido algunas omisiones.";
      insightColor = Colors.orange;
      insightIcon = Icons.lightbulb_outline;
    } else {
      insightTitle = "¡Alerta!";
      insightText = "Tu nivel de adherencia actual es bajo. Revisa tus alarmas.";
      insightColor = AppTheme.errorColor;
      insightIcon = Icons.warning_amber_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Streak Card
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 28,
                    color: Color(0xFFFF6B00),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$racha ${racha == 1 ? 'día' : 'días'}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        Text(
                          "Racha activa",
                          style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Insight Card
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(insightIcon, color: insightColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          insightTitle,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insightText,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.secondaryTextColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTimeline(List<TodayDose> doses) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Resumen de hoy",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              Text(
                "${doses.length} ${doses.length == 1 ? 'dosis programada' : 'dosis programadas'}",
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (doses.isEmpty)
            Center(
              child: Text(
                "No tienes dosis programadas para hoy.",
                style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doses.length,
              itemBuilder: (context, index) {
                final dose = doses[index];
                final timeStr = DateFormat('hh:mm a', 'es_ES').format(dose.hora);
                final isLast = index == doses.length - 1;

                // Estilo según estado
                Color nodeColor = const Color(0xFFC3C6D7);
                Widget nodeWidget = Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                );
                String displayStatus = 'Programada';

                final isPast = dose.hora.isBefore(DateTime.now());

                if (dose.status == DoseStatus.tomada) {
                  nodeColor = AppTheme.successColor;
                  nodeWidget = Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  );
                  displayStatus = 'Tomada';
                } else if (dose.status == DoseStatus.omitida) {
                  nodeColor = AppTheme.errorColor;
                  nodeWidget = Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                  );
                  displayStatus = 'Omitida';
                } else if (dose.status == DoseStatus.aplazada) {
                  nodeColor = Colors.orange;
                  nodeWidget = Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
                    child: const Icon(Icons.watch_later_outlined, color: Colors.white, size: 12),
                  );
                  displayStatus = 'Aplazada';
                } else if (dose.status == DoseStatus.notificada || (dose.status == DoseStatus.pendiente && isPast)) {
                  nodeColor = Colors.amber;
                  nodeWidget = Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                    child: const Icon(Icons.notifications, color: Colors.white, size: 12),
                  );
                  displayStatus = 'Notificada';
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            nodeWidget,
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: const Color(0xFFC3C6D7).withOpacity(0.4),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dose.nombreMedicamento,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${dose.presentacion} • $displayStatus",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }


  Widget _buildIntervalSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: ProgresoInterval.values.map((interval) {
          final isSelected = _selectedInterval == interval;
          String text = '';
          switch (interval) {
            case ProgresoInterval.semana:
              text = 'Semana';
              break;
            case ProgresoInterval.mes:
              text = 'Mes';
              break;
            case ProgresoInterval.anio:
              text = 'Año';
              break;
            case ProgresoInterval.todo:
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
                  borderRadius: BorderRadius.circular(24),
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
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
                        color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
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
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildIntervalSelector(),
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
                int totalDosisTomadas = 0;
                final todosLosTratamientos = snapshot.data!;

                for (var tratamiento in todosLosTratamientos) {
                  final stats = _calcularEstadisticas(tratamiento, dateRange);
                  totalDosisProgramadas += stats['programadasPasadas']!;
                  totalDosisOmitidas += stats['omitidas']!;
                  totalDosisTomadas += stats['tomadas']!;
                }

                final double? adherencia = totalDosisProgramadas > 0
                    ? (totalDosisTomadas / totalDosisProgramadas) * 100
                    : null;

                final racha = _calcularRacha(todosLosTratamientos);
                final dosisDeHoy = _obtenerDosisDeHoy(todosLosTratamientos);

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  children: [
                    _buildAdherenceRingCard(adherencia, totalDosisTomadas, totalDosisOmitidas),
                    const SizedBox(height: 16),
                    _buildStreakAndInsightCard(racha, adherencia),
                    const SizedBox(height: 20),
                    _buildTodayTimeline(dosisDeHoy),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Gráfico de cumplimiento",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        Text(
                          adherencia != null ? "${adherencia.round()}%" : "0%",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: WeeklyComplianceChart(
                              values: _calcularCumplimientoSemanal(todosLosTratamientos),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
