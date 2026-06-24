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
            ? kEmeraldColor
            : (percentage >= 50 ? Colors.orange : Colors.red));

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
                  value: hasData ? percentage / 100 : 0.0,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasData ? "${percentage.toStringAsFixed(0)}%" : "N/A",
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

  Widget _buildStreakAndInsightCard(int racha, double? percentage) {
    String insightText = "";
    Color insightColor = Colors.blue;
    IconData insightIcon = Icons.info_outline;

    if (percentage == null) {
      insightText = "No hay dosis programadas en este período. Registra o activa tus medicamentos para ver tu progreso.";
      insightColor = Colors.grey.shade500;
      insightIcon = Icons.info_outline;
    } else if (percentage >= 80) {
      insightText = "¡Excelente nivel! Tu constancia es la clave para la efectividad de tus tratamientos.";
      insightColor = kEmeraldColor;
      insightIcon = Icons.stars_rounded;
    } else if (percentage >= 50) {
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
            ? kEmeraldColor
            : (adherencia >= 50 ? Colors.orange : Colors.redAccent));

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
                    tratamiento.nombreMedicamento,
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
                    color: progressColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tieneDosis ? "${adherencia.toStringAsFixed(0)}%" : "N/A",
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
                value: tieneDosis ? (adherencia == 0 ? 0.05 : adherencia / 100) : 0.0,
                minHeight: 8,
                backgroundColor: progressColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tieneDosis
                      ? "Dosis: $dosisTomadas de $dosisProgramadas tomadas"
                      : "Sin dosis programadas en este período",
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

  Widget _buildIntervalSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6), // Slate / light grey
        borderRadius: BorderRadius.circular(16),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      return _buildTratamientoCard(tratamiento, dateRange);
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
