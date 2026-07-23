// lib/screens/reports/progreso_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:fl_chart/fl_chart.dart';
import 'adherencia_chart.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';

enum ProgresoInterval { semana, mes, anio, todo }

class TodayDose {
  final String idTratamiento;
  final String nombreMedicamento;
  final String presentacion;
  final DateTime hora;
  final DoseStatus status;
  final CaregiverProfile? profile;

  TodayDose({
    required this.idTratamiento,
    required this.nombreMedicamento,
    required this.presentacion,
    required this.hora,
    required this.status,
    this.profile,
  });
}

class ProgresoPage extends StatefulWidget {
  final GlobalKey? progressRingKey;
  final GlobalKey? progressTimelineKey;

  const ProgresoPage({
    super.key,
    this.progressRingKey,
    this.progressTimelineKey,
  });

  @override
  State<ProgresoPage> createState() => _ProgresoPageState();
}

class _ProgresoPageState extends State<ProgresoPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  ProgresoInterval _selectedInterval = ProgresoInterval.semana;
  bool _isTimelineExpanded = false;
  bool _isSortAscending = false;
  Stream<List<Map<String, dynamic>>>? _combinedStream;
  List<CaregiverProfile>? _lastProfiles;
  bool _lastIsGeneral = false;
  String? _lastActiveProfileId;
  String? _lastUserId;

  void _updateStreamIfNeeded(String userId, bool isGeneral, List<CaregiverProfile> profiles, CaregiverProfile? activeProfile, FirestoreService firestoreService) {
    final activeProfileId = activeProfile?.id;
    if (_combinedStream != null &&
        _lastUserId == userId &&
        _lastIsGeneral == isGeneral &&
        _lastActiveProfileId == activeProfileId &&
        _lastProfiles != null &&
        _lastProfiles!.length == profiles.length) {
      bool same = true;
      for (int i = 0; i < profiles.length; i++) {
        if (_lastProfiles![i].id != profiles[i].id) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    _lastUserId = userId;
    _lastIsGeneral = isGeneral;
    _lastActiveProfileId = activeProfileId;
    _lastProfiles = List.from(profiles);

    if (!isGeneral) {
      _combinedStream = firestoreService.getMedicamentosStream(userId, activeProfile).map((tratamientos) {
        return tratamientos.map((t) => {'tratamiento': t, 'profile': activeProfile}).toList();
      });
      return;
    }

    if (profiles.isEmpty) {
      _combinedStream = Stream.value([]);
      return;
    }

    List<Stream<List<Map<String, dynamic>>>> streams = profiles.map((profile) {
      return firestoreService.getMedicamentosStream(userId, profile).map((tratamientos) {
        return tratamientos.map((t) => {'tratamiento': t, 'profile': profile}).toList();
      });
    }).toList();

    _combinedStream = _combineLatest(streams).map((listOfLists) {
      return listOfLists.expand((list) => list).toList();
    });
  }

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

    final todasLasDosis = TratamientoService.generarDosisEnRango(tratamiento, start, end);

    final Map<int, DoseStatus> statusMap = {};
    tratamiento.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null) {
        statusMap[parsedTime.millisecondsSinceEpoch] = status;
      }
    });

    for (var doseTime in todasLasDosis) {
      if (!doseTime.isBefore(start) && !doseTime.isAfter(end)) {
        if (doseTime.isBefore(now)) {
          programadasPasadas++;
          final status = statusMap[doseTime.millisecondsSinceEpoch];
          if (status == DoseStatus.tomada) {
            tomadas++;
          } else {
            omitidas++;
          }
        }
      }
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

    final todasLasDosis = TratamientoService.generarDosisEnRango(tratamiento, start, end);

    final Map<int, DoseStatus> statusMap = {};
    tratamiento.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null) {
        statusMap[parsedTime.millisecondsSinceEpoch] = status;
      }
    });

    for (var doseTime in todasLasDosis) {
      if (!doseTime.isBefore(start) && !doseTime.isAfter(end)) {
        totalProgramadas++;
        final status = statusMap[doseTime.millisecondsSinceEpoch];
        if (status == DoseStatus.tomada) {
          tomadas++;
        }
      }
    }

    return {
      'tomadas': tomadas,
      'totalProgramadas': totalProgramadas,
    };
  }



  Map<String, dynamic> _calcularCumplimientoSegunIntervalo(
    List<Tratamiento> tratamientos,
    List<Map<String, dynamic>> items,
    bool isGeneralMode,
  ) {
    final now = DateTime.now();
    List<String> labels = [];
    List<double> values = [];
    List<Map<CaregiverProfile, double>> stackedValues = [];

    if (_selectedInterval == ProgresoInterval.semana) {
      labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);

      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
        final range = {'start': dayStart, 'end': dayEnd};

        if (isGeneralMode) {
          int totalProg = 0;
          final Map<CaregiverProfile, int> tomadasMap = {};
          for (var item in items) {
            final t = item['tratamiento'] as Tratamiento;
            final p = item['profile'] as CaregiverProfile?;
            if (p == null) continue;
            final stats = _calcularEstadisticasCompletasDelDia(t, range);
            totalProg += stats['totalProgramadas']!;
            tomadasMap.putIfAbsent(p, () => 0);
            tomadasMap[p] = tomadasMap[p]! + stats['tomadas']!;
          }
          final Map<CaregiverProfile, double> dayMap = {};
          if (totalProg > 0) {
            tomadasMap.forEach((p, tom) {
              if (tom > 0) dayMap[p] = (tom / totalProg) * 100;
            });
          }
          stackedValues.add(dayMap);
          values.add(0.0);
        } else {
          int tomadas = 0;
          int programadas = 0;
          for (var t in tratamientos) {
            final stats = _calcularEstadisticasCompletasDelDia(t, range);
            tomadas += stats['tomadas']!;
            programadas += stats['totalProgramadas']!;
          }
          values.add(programadas > 0 ? (tomadas / programadas) * 100 : (day.isAfter(now) ? 0.0 : 100.0));
        }
      }
    } else if (_selectedInterval == ProgresoInterval.mes) {
      labels = ['S1', 'S2', 'S3', 'S4', 'S5'];
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (int i = 0; i < 5; i++) {
        final weekStart = startOfMonth.add(Duration(days: i * 7));
        if (weekStart.month != now.month) {
          values.add(0.0);
          stackedValues.add({});
          continue;
        }
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        final range = {'start': weekStart, 'end': weekEnd};

        if (isGeneralMode) {
          int totalProg = 0;
          final Map<CaregiverProfile, int> tomadasMap = {};
          for (var item in items) {
            final t = item['tratamiento'] as Tratamiento;
            final p = item['profile'] as CaregiverProfile?;
            if (p == null) continue;
            final stats = _calcularEstadisticasCompletasDelDia(t, range);
            totalProg += stats['totalProgramadas']!;
            tomadasMap.putIfAbsent(p, () => 0);
            tomadasMap[p] = tomadasMap[p]! + stats['tomadas']!;
          }
          final Map<CaregiverProfile, double> weekMap = {};
          if (totalProg > 0) {
            tomadasMap.forEach((p, tom) {
              if (tom > 0) weekMap[p] = (tom / totalProg) * 100;
            });
          }
          stackedValues.add(weekMap);
          values.add(0.0);
        } else {
          int tomadas = 0;
          int programadas = 0;
          for (var t in tratamientos) {
            final stats = _calcularEstadisticasCompletasDelDia(t, range);
            tomadas += stats['tomadas']!;
            programadas += stats['totalProgramadas']!;
          }
          values.add(programadas > 0 ? (tomadas / programadas) * 100 : 0.0);
        }
      }
    } else {
      labels = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      final targetYear = now.year;

      for (int m = 1; m <= 12; m++) {
        final monthStart = DateTime(targetYear, m, 1);
        final monthEnd = DateTime(targetYear, m + 1, 0, 23, 59, 59);
        final range = {'start': monthStart, 'end': monthEnd};

        if (isGeneralMode) {
          int totalProg = 0;
          final Map<CaregiverProfile, int> tomadasMap = {};
          for (var item in items) {
            final t = item['tratamiento'] as Tratamiento;
            final p = item['profile'] as CaregiverProfile?;
            if (p == null) continue;
            final stats = _calcularEstadisticasCompletasDelDia(t, range);
            totalProg += stats['totalProgramadas']!;
            tomadasMap.putIfAbsent(p, () => 0);
            tomadasMap[p] = tomadasMap[p]! + stats['tomadas']!;
          }
          final Map<CaregiverProfile, double> monthMap = {};
          if (totalProg > 0) {
            tomadasMap.forEach((p, tom) {
              if (tom > 0) monthMap[p] = (tom / totalProg) * 100;
            });
          }
          stackedValues.add(monthMap);
          values.add(0.0);
        } else {
          int tomadas = 0;
          int programadas = 0;
          for (var t in tratamientos) {
            final stats = _calcularEstadisticasCompletasDelDia(t, range);
            tomadas += stats['tomadas']!;
            programadas += stats['totalProgramadas']!;
          }
          values.add(programadas > 0 ? (tomadas / programadas) * 100 : 0.0);
        }
      }
    }

    return {
      'labels': labels,
      'values': values,
      'stackedValues': isGeneralMode ? stackedValues : null,
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

  List<TodayDose> _obtenerDosisDelPeriodo(List<Map<String, dynamic>> items, Map<String, DateTime> dateRange) {
    final List<TodayDose> list = [];
    final start = dateRange['start']!;
    final end = dateRange['end']!;

    for (var item in items) {
      final Tratamiento t = item['tratamiento'];
      final CaregiverProfile? p = item['profile'];

      final todasLasDosis = TratamientoService.generarDosisEnRango(t, start, end);

      final Map<int, DoseStatus> statusMap = {};
      t.doseStatus.forEach((key, status) {
        final parsedTime = DateTime.tryParse(key);
        if (parsedTime != null) {
          statusMap[parsedTime.millisecondsSinceEpoch] = status;
        }
      });

      for (var doseTime in todasLasDosis) {
        final status = statusMap[doseTime.millisecondsSinceEpoch] ?? DoseStatus.pendiente;
        list.add(TodayDose(
          idTratamiento: t.id,
          nombreMedicamento: t.nombreMedicamento,
          presentacion: t.presentacion,
          hora: doseTime,
          status: status,
          profile: p,
        ));
      }
    }

    list.sort((a, b) => a.hora.compareTo(b.hora));
    return list;
  }

  Color _parseProfileColorHex(String hexString, {Color defaultColor = AppTheme.primaryColor}) {
    try {
      String cleanHex = hexString.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  Widget _buildAdherenceRingCard(
    double? percentage,
    int tomadas,
    int omitidas, {
    bool isGeneralMode = false,
    Map<CaregiverProfile, Map<String, int>>? statsPorPaciente,
  }) {
    final hasData = percentage != null;
    final color = !hasData
        ? Colors.grey.shade400
        : (percentage >= 80
            ? AppTheme.successColor
            : (percentage >= 50 ? Colors.orange : AppTheme.errorColor));

    Widget chartWidget;
    Widget legendWidget;

    if (isGeneralMode && statsPorPaciente != null && statsPorPaciente.isNotEmpty) {
      // Donut chart with colors for each patient
      final List<PieChartSectionData> sections = [];
      final totalDosis = tomadas + omitidas;

      statsPorPaciente.forEach((profile, stats) {
        final pTomadas = stats['tomadas'] ?? 0;
        final pProg = stats['programadas'] ?? 0;
        final pColor = _parseProfileColorHex(profile.colorHex);

        final double value = pTomadas > 0
            ? pTomadas.toDouble()
            : (totalDosis == 0 ? 1.0 : (pProg > 0 ? 0.3 : 0.1));

        sections.add(
          PieChartSectionData(
            color: pColor,
            value: value,
            title: '',
            radius: 12,
            showTitle: false,
          ),
        );
      });

      chartWidget = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 105,
            height: 105,
            child: RepaintBoundary(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  startDegreeOffset: 270,
                  sections: sections,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasData ? "${percentage.toStringAsFixed(0)}%" : "N/A",
                style: TextStyle(
                  color: AppTheme.primaryTextColor,
                  fontSize: 24,
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
      );

      legendWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: statsPorPaciente.entries.map((entry) {
          final profile = entry.key;
          final stats = entry.value;
          final pColor = _parseProfileColorHex(profile.colorHex);
          final pTomadas = stats['tomadas']!;
          final pProg = stats['programadas']!;
          final pPct = pProg > 0 ? ((pTomadas / pProg) * 100).round() : null;
          final firstName = profile.name.split(' ').first;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$firstName: ",
                  style: TextStyle(
                    color: AppTheme.primaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  pPct != null ? "$pPct%" : "Sin datos",
                  style: TextStyle(
                    color: AppTheme.primaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      chartWidget = Stack(
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
      );

      legendWidget = Column(
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
      );
    }

    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
              chartWidget,
              const Spacer(flex: 2),
              legendWidget,
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );

    if (widget.progressRingKey != null) {
      return Showcase.withWidget(
        key: widget.progressRingKey!,
        height: 220,
        width: 320,
        disableDefaultTargetGestures: true,
        container: const TutorialTooltip(
          icon: Icons.donut_large_rounded,
          title: 'Estadísticas y Modo Cuidador',
          description: 'Mide tu porcentaje general de adherencia, dosis tomadas vs omitidas y el cumplimiento por paciente si usas el Modo Cuidador.',
          stepNumber: 9,
          totalSteps: 11,
        ),
        targetShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        targetPadding: const EdgeInsets.all(4),
        child: card,
      );
    }
    return card;
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
    String title = "Resumen de la semana";
    switch (_selectedInterval) {
      case ProgresoInterval.semana:
        title = "Resumen de la semana";
        break;
      case ProgresoInterval.mes:
        title = "Resumen del mes";
        break;
      case ProgresoInterval.anio:
        title = "Resumen del año";
        break;
      case ProgresoInterval.todo:
        title = "Resumen acumulado";
        break;
    }

    final now = DateTime.now();

    final sortedDoses = List<TodayDose>.from(doses);
    if (_isSortAscending) {
      sortedDoses.sort((a, b) => a.hora.compareTo(b.hora));
    } else {
      sortedDoses.sort((a, b) => b.hora.compareTo(a.hora));
    }

    final visibleDoses = _isTimelineExpanded ? sortedDoses : sortedDoses.take(3).toList();

    final timelineCard = Container(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: doses.length > 3
                      ? () {
                          setState(() {
                            _isTimelineExpanded = !_isTimelineExpanded;
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${doses.length} ${doses.length == 1 ? 'dosis en periodo' : 'dosis en periodo'}",
                          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (doses.isNotEmpty)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isSortAscending = !_isSortAscending;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSortAscending ? "Más antiguos" : "Más recientes",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (doses.isEmpty)
            Center(
              child: Text(
                "No hay dosis programadas para este periodo.",
                style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleDoses.length,
              itemBuilder: (context, index) {
                final dose = visibleDoses[index];
                final isTodayDose = dose.hora.year == now.year && dose.hora.month == now.month && dose.hora.day == now.day;
                final timeStr = isTodayDose 
                    ? DateFormat('hh:mm a', 'es_ES').format(dose.hora)
                    : DateFormat('d MMM, hh:mm a', 'es_ES').format(dose.hora);
                final isLast = index == visibleDoses.length - 1;

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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      dose.nombreMedicamento,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.primaryTextColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                              if (dose.profile != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(dose.profile!.colorHex.replaceFirst('#', 'FF'), radix: 16)).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Color(int.parse(dose.profile!.colorHex.replaceFirst('#', 'FF'), radix: 16)).withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person, size: 12, color: Color(int.parse(dose.profile!.colorHex.replaceFirst('#', 'FF'), radix: 16))),
                                      const SizedBox(width: 4),
                                      Text(
                                        dose.profile!.name,
                                        style: TextStyle(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.bold, 
                                          color: Color(int.parse(dose.profile!.colorHex.replaceFirst('#', 'FF'), radix: 16)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (doses.length > 3) ...[
              const SizedBox(height: 4),
              Center(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isTimelineExpanded = !_isTimelineExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isTimelineExpanded
                              ? 'Ver menos'
                              : 'Ver más (${doses.length - 3} dosis más)',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isTimelineExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );

    if (widget.progressTimelineKey != null) {
      return Showcase.withWidget(
        key: widget.progressTimelineKey!,
        height: 220,
        width: 320,
        disableDefaultTargetGestures: true,
        container: const TutorialTooltip(
          icon: Icons.filter_list_rounded,
          title: 'Filtros y Resumen Desplegable',
          description: 'Filtra tu progreso por Semana, Mes o Año. Usa "Ver más" para desplegar la lista y cambia el orden entre "Más recientes" y "Más antiguos".',
          stepNumber: 10,
          totalSteps: 11,
        ),
        targetShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        targetPadding: const EdgeInsets.all(4),
        child: timelineCard,
      );
    }
    return timelineCard;
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
                  _isTimelineExpanded = false;
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
    super.build(context);
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final user = authService.currentUser;
    final isGeneralMode = caregiverNotifier.isCaregiverModeActive && caregiverNotifier.isGeneralMode;
    final activeProfile = caregiverNotifier.isCaregiverModeActive ? caregiverNotifier.activeProfile : null;
    final profiles = caregiverNotifier.managedProfiles;
    final dateRange = _getDateRange();

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: Text('Inicia sesión para ver tu progreso.')),
      );
    }
    
    _updateStreamIfNeeded(user.uid, isGeneralMode, profiles, activeProfile, firestoreService);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildIntervalSelector(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('${isGeneralMode}_${activeProfile?.id}_${caregiverNotifier.isCaregiverModeActive}'),
              stream: _combinedStream,
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
                final items = snapshot.data!;
                final tratamientos = items.map((i) => i['tratamiento'] as Tratamiento).toList();
                
                final Map<CaregiverProfile, Map<String, int>> statsPorPaciente = {};

                for (var item in items) {
                  final Tratamiento tratamiento = item['tratamiento'];
                  final CaregiverProfile? profile = item['profile'];
                  final stats = _calcularEstadisticas(tratamiento, dateRange);
                  
                  totalDosisProgramadas += stats['programadasPasadas']!;
                  totalDosisOmitidas += stats['omitidas']!;
                  totalDosisTomadas += stats['tomadas']!;
                  
                  if (profile != null) {
                    statsPorPaciente.putIfAbsent(profile, () => {'programadas': 0, 'tomadas': 0, 'omitidas': 0});
                    statsPorPaciente[profile]!['programadas'] = statsPorPaciente[profile]!['programadas']! + stats['programadasPasadas']!;
                    statsPorPaciente[profile]!['tomadas'] = statsPorPaciente[profile]!['tomadas']! + stats['tomadas']!;
                    statsPorPaciente[profile]!['omitidas'] = statsPorPaciente[profile]!['omitidas']! + stats['omitidas']!;
                  }
                }

                final double? adherencia = totalDosisProgramadas > 0
                    ? (totalDosisTomadas / totalDosisProgramadas) * 100
                    : null;

                final racha = _calcularRacha(tratamientos);
                final dosisDelPeriodo = _obtenerDosisDelPeriodo(items, dateRange);

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  children: [
                    _buildAdherenceRingCard(
                      adherencia,
                      totalDosisTomadas,
                      totalDosisOmitidas,
                      isGeneralMode: isGeneralMode,
                      statsPorPaciente: statsPorPaciente,
                    ),
                    const SizedBox(height: 16),
                    _buildStreakAndInsightCard(racha, adherencia),
                    const SizedBox(height: 20),
                    
                    if (isGeneralMode && statsPorPaciente.isNotEmpty) ...[
                      Text(
                        "Progreso por paciente",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...statsPorPaciente.entries.map((entry) {
                        final profile = entry.key;
                        final stats = entry.value;
                        final pct = stats['programadas']! > 0 
                            ? (stats['tomadas']! / stats['programadas']!) * 100 
                            : null;
                        final profileColor = _parseProfileColorHex(profile.colorHex);
                        final pTomadas = stats['tomadas']!;
                        final pProg = stats['programadas']!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.2)),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: profileColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: profileColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pct != null ? "${pct.round()}% de adherencia" : "Sin datos",
                                      style: TextStyle(
                                        color: AppTheme.secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pProg > 0 ? "$pTomadas de $pProg dosis" : "0 dosis",
                                    style: TextStyle(
                                      color: AppTheme.primaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 70,
                                    height: 6,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (pct != null && pProg > 0) ? (pct / 100).clamp(0.0, 1.0) : 0.0,
                                        backgroundColor: profileColor.withOpacity(0.15),
                                        valueColor: AlwaysStoppedAnimation<Color>(profileColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    _buildTodayTimeline(dosisDelPeriodo),
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
                          Builder(
                            builder: (context) {
                              final data = _calcularCumplimientoSegunIntervalo(
                                tratamientos,
                                items,
                                isGeneralMode && statsPorPaciente.isNotEmpty,
                              );
                              return SizedBox(
                                height: 180,
                                child: RepaintBoundary(
                                  child: WeeklyComplianceChart(
                                    values: data['values'] as List<double>,
                                    customLabels: data['labels'] as List<String>,
                                    barColor: activeProfile != null ? _parseProfileColorHex(activeProfile.colorHex) : null,
                                    stackedValues: data['stackedValues'] as List<Map<CaregiverProfile, double>>?,
                                  ),
                                ),
                              );
                            },
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

// A simple manual stream combiner since we don't have rxdart
Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) {
    return Stream.value([]);
  }
  
  late StreamController<List<T>> controller;
  List<T?> currentValues = List.filled(streams.length, null);
  List<bool> hasValue = List.filled(streams.length, false);
  
  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      int completed = 0;
      List<dynamic> subscriptions = [];
      
      for (int i = 0; i < streams.length; i++) {
        subscriptions.add(streams[i].listen(
          (value) {
            currentValues[i] = value;
            hasValue[i] = true;
            if (!hasValue.contains(false)) {
              controller.add(List<T>.from(currentValues));
            }
          },
          onError: controller.addError,
          onDone: () {
            completed++;
            if (completed == streams.length) {
              controller.close();
            }
          },
        ));
      }
      
      controller.onCancel = () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
      };
    },
  );
  
  return controller.stream;
}
