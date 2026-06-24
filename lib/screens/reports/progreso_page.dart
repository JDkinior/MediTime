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

const Color kEmeraldColor = Color(0xFF10B981);

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

  Widget _buildAdherenceRingCard(double percentage, int tomadas, int omitidas) {
    final color = percentage >= 90
        ? kEmeraldColor
        : (percentage >= 70 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3C72),
            const Color(0xFF2A5298),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${percentage.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Adherencia",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tu Desempeño General",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: kEmeraldColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Tomadas: $tomadas",
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Omitidas: $omitidas",
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakAndInsightCard(int racha, double percentage) {
    String insightText = "";
    Color insightColor = Colors.blue;
    IconData insightIcon = Icons.info_outline;

    if (percentage >= 90) {
      insightText = "¡Excelente nivel! Tu constancia es la clave para la efectividad de tus tratamientos.";
      insightColor = kEmeraldColor;
      insightIcon = Icons.stars_rounded;
    } else if (percentage >= 70) {
      insightText = "Buen ritmo, pero has tenido algunas omisiones. ¿Te vendrían bien recordatorios extras?";
      insightColor = Colors.amber.shade700;
      insightIcon = Icons.lightbulb_outline;
    } else {
      insightText = "¡Alerta! Tu nivel de adherencia es bajo. Te recomendamos activar las alertas en modo Activo.";
      insightColor = Colors.redAccent;
      insightIcon = Icons.warning_amber_rounded;
    }

    return Row(
      children: [
        // Streak Card
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade100),
              boxShadow: kCustomBoxShadow,
            ),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.orange, Colors.redAccent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$racha ${racha == 1 ? 'Día' : 'Días'}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const Text(
                        "Racha Activa",
                        style: TextStyle(fontSize: 11, color: Colors.black54),
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
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: insightColor.withOpacity(0.2)),
              boxShadow: kCustomBoxShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(insightIcon, color: insightColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insightText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTimeline(List<TodayDose> doses) {
    if (doses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kCustomBoxShadow,
        ),
        child: const Center(
          child: Text(
            "No tienes dosis programadas para hoy.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCustomBoxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cronograma de Hoy",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                "${doses.length} ${doses.length == 1 ? 'dosis' : 'dosis'}",
                style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doses.length,
            itemBuilder: (context, index) {
              final dose = doses[index];
              final timeStr =
                  "${dose.hora.hour.toString().padLeft(2, '0')}:${dose.hora.minute.toString().padLeft(2, '0')}";

              IconData icon = Icons.circle_outlined;
              Color color = Colors.grey;

              if (dose.status == DoseStatus.tomada) {
                icon = Icons.check_circle_rounded;
                color = kEmeraldColor;
              } else if (dose.status == DoseStatus.omitida) {
                icon = Icons.cancel_rounded;
                color = Colors.redAccent;
              } else if (dose.status == DoseStatus.aplazada) {
                icon = Icons.watch_later_rounded;
                color = Colors.orange;
              } else if (dose.status == DoseStatus.notificada) {
                icon = Icons.notifications_active_rounded;
                color = Colors.blue;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(icon, color: color, size: 20),
                      if (index != doses.length - 1)
                        Container(
                          width: 2,
                          height: 35,
                          color: Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dose.nombreMedicamento,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "${dose.presentacion} • ${dose.status.displayName}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
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

    final progressColor = adherencia >= 90
        ? kEmeraldColor
        : (adherencia >= 70 ? Colors.orange : Colors.redAccent);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tratamiento['nombreMedicamento'] ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${adherencia.toStringAsFixed(0)}%",
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: adherencia / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Dosis: $dosisTomadas de $dosisProgramadas tomadas",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
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
      backgroundColor: const Color(0xFFF8F9FD),
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
                final double adherencia = totalDosisProgramadas > 0
                    ? (totalDosisTomadas / totalDosisProgramadas) * 100
                    : 0.0;

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
                    const Text(
                      "Gráfico de Cumplimiento",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: kCustomBoxShadow,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: AdherenceBarChart(
                              tomadas: totalDosisTomadas.toDouble(),
                              omitidas: totalDosisOmitidas.toDouble(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Desglose por Medicamento",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
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
