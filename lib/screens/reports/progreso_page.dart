// lib/screens/reports/progreso_page.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'adherencia_chart.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/services/pdf_report_service.dart';
import 'package:meditime/core/subscription_guard.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/reports/omission_analysis_sheet.dart';
import 'package:meditime/widgets/reports/treatment_accordion_card.dart';
import 'package:meditime/widgets/reports/full_treatment_breakdown_sheet.dart';
import 'package:meditime/widgets/reports/full_history_sheet.dart';
import 'package:meditime/widgets/reports/streak_celebration_sheet.dart';

enum ProgresoInterval { semana, mes, anio, todo }

enum TreatmentSortOrder {
  adherenceAsc,
  adherenceDesc,
  alphabeticalAsc,
  alphabeticalDesc,
}

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
  bool _isSortAscending = false;
  bool _showScrollToTop = false;
  final Set<String> _expandedTreatments = <String>{};
  TreatmentSortOrder _treatmentSortOrder = TreatmentSortOrder.adherenceAsc;
  int? _selectedTimelineDayIndex;
  DoseStatus? _selectedStatusFilter;
  bool _isGeneratingPdf = false;
  final PdfReportService _pdfService = PdfReportService();
  final GlobalKey _ringChartKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  Stream<List<Map<String, dynamic>>>? _combinedStream;
  List<CaregiverProfile>? _lastProfiles;
  bool _lastIsGeneral = false;
  String? _lastActiveProfileId;
  String? _lastUserId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  // Caché en memoria para evitar recalcular estadísticas repetidamente
  final Map<String, Map<String, int>> _statsCache = {};

  Map<String, int> _calcularEstadisticas(Tratamiento tratamiento, Map<String, DateTime> dateRange) {
    final start = dateRange['start']!;
    final end = dateRange['end']!;
    final cacheKey = "${tratamiento.id}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}_${tratamiento.doseStatus.length}";
    if (_statsCache.containsKey(cacheKey)) {
      return _statsCache[cacheKey]!;
    }

    int tomadas = 0;
    int omitidas = 0;
    int aplazadas = 0;
    int notificadas = 0;

    final now = DateTime.now();

    final List<DateTime> recordedTimes = [];
    tratamiento.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null &&
          !parsedTime.isBefore(start) &&
          !parsedTime.isAfter(end) &&
          parsedTime.isBefore(now)) {
        recordedTimes.add(parsedTime);
        switch (status) {
          case DoseStatus.tomada:
            tomadas++;
            break;
          case DoseStatus.omitida:
            omitidas++;
            break;
          case DoseStatus.aplazada:
            aplazadas++;
            break;
          case DoseStatus.notificada:
            notificadas++;
            break;
          case DoseStatus.pendiente:
            omitidas++;
            break;
        }
      }
    });

    // Ordenar para búsqueda lineal optimizada O(N + M)
    recordedTimes.sort();

    final todasLasDosis = TratamientoService.generarDosisEnRango(tratamiento, start, end);
    final intervaloMinutos = tratamiento.intervaloDosis.inMinutes > 0 ? tratamiento.intervaloDosis.inMinutes : 240;
    final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);

    int recIdx = 0;
    final int recLen = recordedTimes.length;

    for (final doseTime in todasLasDosis) {
      if (!doseTime.isBefore(start) && !doseTime.isAfter(end) && doseTime.isBefore(now)) {
        while (recIdx < recLen && doseTime.difference(recordedTimes[recIdx]).inMinutes > maxToleranceMinutes) {
          recIdx++;
        }

        bool isRecorded = false;
        int checkIdx = recIdx;
        while (checkIdx < recLen) {
          final diffMinutes = recordedTimes[checkIdx].difference(doseTime).inMinutes;
          if (diffMinutes.abs() <= maxToleranceMinutes) {
            isRecorded = true;
            break;
          }
          if (diffMinutes > maxToleranceMinutes) {
            break;
          }
          checkIdx++;
        }

        if (!isRecorded) {
          omitidas++;
        }
      }
    }

    final int programadasPasadas = tomadas + omitidas + aplazadas + notificadas;

    final result = {
      'tomadas': tomadas,
      'omitidas': omitidas,
      'aplazadas': aplazadas,
      'notificadas': notificadas,
      'programadasPasadas': programadasPasadas,
    };
    _statsCache[cacheKey] = result;
    return result;
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
            final stats = _calcularEstadisticas(t, range);
            totalProg += stats['programadasPasadas']!;
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
            final stats = _calcularEstadisticas(t, range);
            tomadas += stats['tomadas']!;
            programadas += stats['programadasPasadas']!;
          }
          values.add(programadas > 0 ? (tomadas / programadas) * 100 : 0.0);
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
        final weekEnd = (i == 4)
            ? DateTime(now.year, now.month + 1, 0, 23, 59, 59)
            : weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        final range = {'start': weekStart, 'end': weekEnd};

        if (isGeneralMode) {
          int totalProg = 0;
          final Map<CaregiverProfile, int> tomadasMap = {};
          for (var item in items) {
            final t = item['tratamiento'] as Tratamiento;
            final p = item['profile'] as CaregiverProfile?;
            if (p == null) continue;
            final stats = _calcularEstadisticas(t, range);
            totalProg += stats['programadasPasadas']!;
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
            final stats = _calcularEstadisticas(t, range);
            tomadas += stats['tomadas']!;
            programadas += stats['programadasPasadas']!;
          }
          values.add(programadas > 0 ? (tomadas / programadas) * 100 : 0.0);
        }
      }
    } else {
      labels = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
      final targetYear = now.year;

      for (int m = 1; m <= 12; m++) {
        final monthStart = DateTime(targetYear, m, 1, 0, 0, 0);
        final monthEnd = DateTime(targetYear, m + 1, 0, 23, 59, 59);
        final range = {'start': monthStart, 'end': monthEnd};

        if (isGeneralMode) {
          int totalProg = 0;
          final Map<CaregiverProfile, int> tomadasMap = {};
          for (var item in items) {
            final t = item['tratamiento'] as Tratamiento;
            final p = item['profile'] as CaregiverProfile?;
            if (p == null) continue;
            final stats = _calcularEstadisticas(t, range);
            totalProg += stats['programadasPasadas']!;
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
            final stats = _calcularEstadisticas(t, range);
            tomadas += stats['tomadas']!;
            programadas += stats['programadasPasadas']!;
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

    // Agrupar estados por fecha (YYYY-MM-DD) en una sola pasada rápida O(TotalDosis)
    final Map<String, List<DoseStatus>> dayStatuses = {};

    for (var t in tratamientos) {
      t.doseStatus.forEach((key, status) {
        final parsed = DateTime.tryParse(key);
        if (parsed != null && parsed.isBefore(now)) {
          final dateStr =
              "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
          dayStatuses.putIfAbsent(dateStr, () => []).add(status);
        }
      });
    }

    for (int i = 0; i < 30; i++) {
      final dateToCheck = now.subtract(Duration(days: i));
      final dateStr =
          "${dateToCheck.year}-${dateToCheck.month.toString().padLeft(2, '0')}-${dateToCheck.day.toString().padLeft(2, '0')}";

      final statuses = dayStatuses[dateStr];
      if (statuses != null && statuses.isNotEmpty) {
        final bool perfectDay = statuses.every((s) => s == DoseStatus.tomada);
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

    // Optimización de rendimiento para intervalos extensos:
    // Limitar la ventana de generación de dosis a los últimos 45 días en 'Año' o 'Todo'
    // para mantener 120 FPS sin saturar la memoria con miles de objetos.
    final effectiveStart = (_selectedInterval == ProgresoInterval.anio || _selectedInterval == ProgresoInterval.todo)
        ? (end.subtract(const Duration(days: 45)).isAfter(start)
            ? end.subtract(const Duration(days: 45))
            : start)
        : start;

    for (var item in items) {
      final Tratamiento t = item['tratamiento'];
      final CaregiverProfile? p = item['profile'];

      final todasLasDosis = TratamientoService.generarDosisEnRango(t, effectiveStart, end);

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

  Color _parseProfileColorHex(String hexString, {Color? defaultColor}) {
    final fallback = defaultColor ?? AppTheme.primaryColor;
    try {
      String cleanHex = hexString.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  void _toggleStatusFilter(DoseStatus status) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedStatusFilter == status) {
        _selectedStatusFilter = null;
      } else {
        _selectedStatusFilter = status;
      }
    });
  }

  Widget _buildRingCenterContent({
    required DoseStatus? selectedStatus,
    required double? percentage,
    required int tomadas,
    required int omitidas,
    required int aplazadas,
    required int notificadas,
    required AppLocalizations? l10n,
    required bool isEs,
  }) {
    if (selectedStatus != null) {
      String countText;
      String labelText;
      Color statusColor;

      switch (selectedStatus) {
        case DoseStatus.tomada:
          countText = "$tomadas";
          labelText = isEs ? "Tomadas" : "Taken";
          statusColor = AppTheme.successColor;
          break;
        case DoseStatus.omitida:
          countText = "$omitidas";
          labelText = isEs ? "Omitidas" : "Missed";
          statusColor = AppTheme.errorColor;
          break;
        case DoseStatus.aplazada:
          countText = "$aplazadas";
          labelText = isEs ? "Aplazadas" : "Snoozed";
          statusColor = Colors.orange;
          break;
        case DoseStatus.notificada:
          countText = "$notificadas";
          labelText = isEs ? "Notificadas" : "Notified";
          statusColor = Colors.amber;
          break;
        case DoseStatus.pendiente:
          countText = "0";
          labelText = isEs ? "Pendientes" : "Pending";
          statusColor = Colors.grey;
          break;
      }

      return Column(
        key: ValueKey(selectedStatus),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            countText,
            style: TextStyle(
              color: statusColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            labelText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    final hasData = percentage != null;
    return Column(
      key: const ValueKey('adherence_overall'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hasData ? "${percentage.toStringAsFixed(0)}%" : "N/A",
          style: TextStyle(
            color: AppTheme.primaryTextColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          l10n?.adherence ?? "Adherencia",
          style: TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenceRingCard(
    double? percentage,
    int tomadas,
    int omitidas, {
    int aplazadas = 0,
    int notificadas = 0,
    int programadas = 0,
    bool isGeneralMode = false,
    Map<CaregiverProfile, Map<String, int>>? statsPorPaciente,
  }) {
    final l10n = AppLocalizations.of(context);
    final hasData = percentage != null;

    Widget chartWidget;
    Widget legendWidget;

    if (isGeneralMode && statsPorPaciente != null && statsPorPaciente.isNotEmpty) {
      final List<RingSegment> segments = [];
      final totalDosis = tomadas + omitidas + aplazadas + notificadas;

      statsPorPaciente.forEach((profile, stats) {
        final pTomadas = stats['tomadas'] ?? 0;
        final pProg = stats['programadas'] ?? 0;
        final pColor = _parseProfileColorHex(profile.colorHex);

        final double value = pTomadas > 0
            ? pTomadas.toDouble()
            : (totalDosis == 0 ? 1.0 : (pProg > 0 ? 0.3 : 0.1));

        segments.add(
          RingSegment(
            value: value,
            color: pColor,
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
              key: _ringChartKey,
              child: CustomPaint(
                painter: SegmentRingPainter(
                  segments: segments,
                  trackColor: AppTheme.surfaceColor,
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
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                l10n?.adherence ?? "Adherencia",
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
      final segments = <RingSegment>[
        if (tomadas > 0)
          RingSegment(
            value: tomadas.toDouble(),
            color: AppTheme.successColor,
            status: DoseStatus.tomada,
            isSelected: _selectedStatusFilter == DoseStatus.tomada,
            isDimmed: _selectedStatusFilter != null && _selectedStatusFilter != DoseStatus.tomada,
          ),
        if (aplazadas > 0)
          RingSegment(
            value: aplazadas.toDouble(),
            color: Colors.orange,
            status: DoseStatus.aplazada,
            isSelected: _selectedStatusFilter == DoseStatus.aplazada,
            isDimmed: _selectedStatusFilter != null && _selectedStatusFilter != DoseStatus.aplazada,
          ),
        if (notificadas > 0)
          RingSegment(
            value: notificadas.toDouble(),
            color: Colors.amber,
            status: DoseStatus.notificada,
            isSelected: _selectedStatusFilter == DoseStatus.notificada,
            isDimmed: _selectedStatusFilter != null && _selectedStatusFilter != DoseStatus.notificada,
          ),
        if (omitidas > 0)
          RingSegment(
            value: omitidas.toDouble(),
            color: AppTheme.errorColor,
            status: DoseStatus.omitida,
            isSelected: _selectedStatusFilter == DoseStatus.omitida,
            isDimmed: _selectedStatusFilter != null && _selectedStatusFilter != DoseStatus.omitida,
          ),
      ];

      final langCode = Localizations.localeOf(context).languageCode;
      final isEs = langCode.startsWith('es');
      final isPt = langCode.startsWith('pt');

      chartWidget = _PressableScale(
        scaleFactor: 0.95,
        onTap: () {
          if (_selectedStatusFilter != null) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedStatusFilter = null;
            });
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 105,
              height: 105,
              child: RepaintBoundary(
                key: _ringChartKey,
                child: CustomPaint(
                  painter: SegmentRingPainter(
                    segments: segments,
                    trackColor: AppTheme.surfaceColor,
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _buildRingCenterContent(
                selectedStatus: _selectedStatusFilter,
                percentage: percentage,
                tomadas: tomadas,
                omitidas: omitidas,
                aplazadas: aplazadas,
                notificadas: notificadas,
                l10n: l10n,
                isEs: isEs,
              ),
            ),
          ],
        ),
      );

      String headlineValue;
      String headlineTotal;
      String headlineSubtitle;
      Color headlineColor;

      if (_selectedStatusFilter != null) {
        headlineTotal = " / $programadas dosis";
        switch (_selectedStatusFilter!) {
          case DoseStatus.tomada:
            headlineValue = "$tomadas";
            headlineSubtitle = isEs ? "Dosis tomadas a tiempo" : "Doses taken on time";
            headlineColor = AppTheme.successColor;
            break;
          case DoseStatus.omitida:
            headlineValue = "$omitidas";
            headlineSubtitle = isEs ? "Dosis omitidas en el periodo" : "Missed doses in period";
            headlineColor = AppTheme.errorColor;
            break;
          case DoseStatus.aplazada:
            headlineValue = "$aplazadas";
            headlineSubtitle = isEs ? "Dosis pospuestas" : "Postponed doses";
            headlineColor = Colors.orange;
            break;
          case DoseStatus.notificada:
            headlineValue = "$notificadas";
            headlineSubtitle = isEs ? "Dosis por confirmar" : "Pending confirmation";
            headlineColor = Colors.amber;
            break;
          case DoseStatus.pendiente:
            headlineValue = "0";
            headlineSubtitle = isEs ? "Dosis pendientes" : "Pending doses";
            headlineColor = Colors.grey;
            break;
        }
      } else {
        headlineValue = "$tomadas";
        headlineTotal = " / $programadas dosis";
        headlineSubtitle = isEs ? "Dosis tomadas a tiempo" : "Doses taken on time";
        headlineColor = AppTheme.primaryTextColor;
      }

      legendWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                headlineValue,
                style: TextStyle(
                  color: headlineColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                headlineTotal,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            headlineSubtitle,
            style: TextStyle(
              color: _selectedStatusFilter != null ? headlineColor : AppTheme.secondaryTextColor,
              fontSize: 11.5,
              fontWeight: _selectedStatusFilter != null ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: (percentage != null && percentage >= 80)
                  ? AppTheme.successColor.withValues(alpha: 0.14)
                  : AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (percentage != null && percentage >= 80)
                    ? AppTheme.successColor.withValues(alpha: 0.3)
                    : AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (percentage != null && percentage >= 80)
                      ? Icons.verified_rounded
                      : Icons.flag_rounded,
                  size: 13,
                  color: (percentage != null && percentage >= 80)
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 5),
                Text(
                  (percentage != null && percentage >= 80)
                      ? (isEs ? "Meta clínica superada (80%)" : (isPt ? "Meta clínica atingida (80%)" : "Target reached (80%)"))
                      : (isEs ? "Meta clínica: 80%" : (isPt ? "Meta clínica: 80%" : "Clinical target: 80%")),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: (percentage != null && percentage >= 80)
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (percentage != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                percentage >= 80
                    ? (isEs
                        ? "¡Excelente constancia! Estás superando el objetivo clínico recomendado."
                        : (isPt
                            ? "Excelente constância! Você está superando a meta clínica recomendada."
                            : "Outstanding discipline! You are exceeding the recommended clinical target."))
                    : (isEs
                        ? "Faltan ${(programadas * 0.8 - tomadas).ceil().clamp(1, programadas)} dosis a tiempo para alcanzar la meta clínica del 80%."
                        : (isPt
                            ? "Faltam ${(programadas * 0.8 - tomadas).ceil().clamp(1, programadas)} doses no horário para atingir a meta clínica de 80%."
                            : "Take ${(programadas * 0.8 - tomadas).ceil().clamp(1, programadas)} more on-time doses to reach the 80% clinical goal.")),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.secondaryTextColor,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Theme.of(context).cardColor,
                  Color.alphaBlend(AppTheme.primaryColor.withValues(alpha: 0.05), Theme.of(context).cardColor),
                ]
              : [
                  Colors.white,
                  Color.alphaBlend(AppTheme.primaryColor.withValues(alpha: 0.025), Colors.white),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.overallPerformance ?? "Tu desempeño general",
            style: TextStyle(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 4),
              chartWidget,
              const SizedBox(width: 18),
              Expanded(child: legendWidget),
              const SizedBox(width: 4),
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
        container: TutorialTooltip(
          icon: Icons.donut_large_rounded,
          title: l10n?.tutorialStep9Title ?? 'Estadísticas y Modo Cuidador',
          description: l10n?.tutorialStep9Desc ?? 'Mide tu porcentaje general de adherencia, dosis tomadas vs omitidas y el cumplimiento por paciente si usas el Modo Cuidador.',
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isActiveFilter = false,
  }) {
    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast || isActiveFilter;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Color.alphaBlend(color.withValues(alpha: isActiveFilter ? 0.16 : 0.05), Theme.of(context).cardColor),
              Color.alphaBlend(color.withValues(alpha: isActiveFilter ? 0.28 : 0.14), Theme.of(context).cardColor),
            ]
          : [
              Color.alphaBlend(color.withValues(alpha: isActiveFilter ? 0.08 : 0.02), Colors.white),
              Color.alphaBlend(color.withValues(alpha: isActiveFilter ? 0.18 : 0.08), Colors.white),
            ],
    );

    return _PressableScale(
      onTap: onTap,
      scaleFactor: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: showBorder
              ? Border.all(
                  color: isActiveFilter ? color : AppTheme.borderColor,
                  width: isActiveFilter ? 1.3 : 1.0,
                )
              : null,
          boxShadow: isActiveFilter
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 7,
                    offset: const Offset(0, 2.5),
                  ),
                ]
              : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActiveFilter ? color : AppTheme.secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isActiveFilter ? 0.25 : 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActiveFilter)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Filtro",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiMetricsGrid({
    required int tomadas,
    required int omitidas,
    required int aplazadas,
    int notificadas = 0,
    required int programadas,
    required bool isGeneralMode,
  }) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isEs = langCode.startsWith('es');

    Color activeFilterColor = AppTheme.primaryColor;
    String activeFilterLabel = "";
    int activeFilterCount = 0;

    if (_selectedStatusFilter != null) {
      switch (_selectedStatusFilter!) {
        case DoseStatus.tomada:
          activeFilterColor = AppTheme.successColor;
          activeFilterLabel = isEs ? "Tomadas" : "Taken";
          activeFilterCount = tomadas;
          break;
        case DoseStatus.omitida:
          activeFilterColor = AppTheme.errorColor;
          activeFilterLabel = isEs ? "Omitidas" : "Missed";
          activeFilterCount = omitidas;
          break;
        case DoseStatus.aplazada:
          activeFilterColor = Colors.orange;
          activeFilterLabel = isEs ? "Aplazadas" : "Snoozed";
          activeFilterCount = aplazadas;
          break;
        case DoseStatus.notificada:
          activeFilterColor = Colors.amber;
          activeFilterLabel = isEs ? "Notificadas" : "Notified";
          activeFilterCount = notificadas;
          break;
        case DoseStatus.pendiente:
          activeFilterColor = Colors.grey;
          activeFilterLabel = isEs ? "Pendientes" : "Pending";
          activeFilterCount = 0;
          break;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: isEs ? 'Tomadas' : (l10n?.taken ?? 'Tomadas'),
                value: '$tomadas',
                subtitle: programadas > 0
                    ? "${((tomadas / programadas) * 100).round()}% ${isEs ? 'a tiempo' : 'on time'}"
                    : (isEs ? "Sin dosis" : "No doses"),
                icon: Icons.check_circle_rounded,
                color: AppTheme.successColor,
                isActiveFilter: _selectedStatusFilter == DoseStatus.tomada,
                onTap: () => _toggleStatusFilter(DoseStatus.tomada),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: isEs ? 'Omitidas' : (l10n?.skipped ?? 'Omitidas'),
                value: '$omitidas',
                subtitle: programadas > 0
                    ? "${((omitidas / programadas) * 100).round()}% ${isEs ? 'sin tomar' : 'missed'}"
                    : (isEs ? "Sin dosis" : "No doses"),
                icon: Icons.cancel_rounded,
                color: AppTheme.errorColor,
                isActiveFilter: _selectedStatusFilter == DoseStatus.omitida,
                onTap: () => _toggleStatusFilter(DoseStatus.omitida),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: isEs ? 'Aplazadas' : (l10n?.doseStatusSnoozed ?? 'Aplazadas'),
                value: '$aplazadas',
                subtitle: aplazadas > 0
                    ? (isEs ? "Pospuestas" : "Postponed")
                    : (isEs ? "Sin retrasos" : "On schedule"),
                icon: Icons.schedule_rounded,
                color: Colors.orange,
                isActiveFilter: _selectedStatusFilter == DoseStatus.aplazada,
                onTap: () => _toggleStatusFilter(DoseStatus.aplazada),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: isEs ? 'Notificadas' : (l10n?.doseStatusNotified ?? 'Notificadas'),
                value: '$notificadas',
                subtitle: notificadas > 0
                    ? (isEs ? "Por confirmar" : "Pending action")
                    : (isEs ? "Al día" : "Up to date"),
                icon: Icons.notifications_active_rounded,
                color: Colors.amber,
                isActiveFilter: _selectedStatusFilter == DoseStatus.notificada,
                onTap: () => _toggleStatusFilter(DoseStatus.notificada),
              ),
            ),
          ],
        ),
        if (_selectedStatusFilter != null) ...[
          const SizedBox(height: 10),
          _PressableScale(
            scaleFactor: 0.97,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedStatusFilter = null);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: activeFilterColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: activeFilterColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_alt_rounded, size: 16, color: activeFilterColor),
                      const SizedBox(width: 8),
                      Text(
                        isEs
                            ? "Filtrando por $activeFilterLabel ($activeFilterCount)"
                            : "Filtering by $activeFilterLabel ($activeFilterCount)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: activeFilterColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        isEs ? "Ver todas ($programadas)" : "Show all ($programadas)",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: activeFilterColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.close_rounded, size: 16, color: activeFilterColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStreakAndInsightCard({
    required int racha,
    required double? percentage,
    required List<Tratamiento> tratamientos,
    required int totalOmitidas,
    required int totalTomadas,
  }) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isEs = langCode.startsWith('es');
    final isPt = langCode.startsWith('pt');

    String insightTitle;
    String insightText;
    Color insightColor;
    IconData insightIcon;
    final bool canOpenAnalysis = tratamientos.isNotEmpty;

    // Analizar omisiones por franja horaria dentro de los tratamientos
    int morningOmissions = 0;
    int afternoonOmissions = 0;
    int nightOmissions = 0;
    int earlyOmissions = 0;

    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(dateString);
          if (doseTime != null) {
            final hour = doseTime.hour;
            if (hour >= 6 && hour < 12) {
              morningOmissions++;
            } else if (hour >= 12 && hour < 18) {
              afternoonOmissions++;
            } else if (hour >= 18 && hour < 24) {
              nightOmissions++;
            } else {
              earlyOmissions++;
            }
          }
        }
      });
    }

    if (percentage == null) {
      insightTitle = l10n?.insightNoDataTitle ?? "Sin datos";
      insightText = isEs 
          ? "Agrega medicamentos para analizar tus patrones."
          : (isPt ? "Adicione remédios para analisar padrões." : "Add meds to analyze your patterns.");
      insightColor = Colors.grey;
      insightIcon = Icons.info_outline_rounded;
    } else if (totalOmitidas > 0) {
      // Detección del periodo crítico de omisión
      int maxOmissions = morningOmissions;
      String periodKey = 'morning';

      if (afternoonOmissions > maxOmissions) {
        maxOmissions = afternoonOmissions;
        periodKey = 'afternoon';
      }
      if (nightOmissions > maxOmissions) {
        maxOmissions = nightOmissions;
        periodKey = 'night';
      }
      if (earlyOmissions > maxOmissions) {
        maxOmissions = earlyOmissions;
        periodKey = 'early';
      }

      insightColor = (percentage < 65) ? AppTheme.errorColor : Colors.orange;
      insightIcon = Icons.lightbulb_outline_rounded;

      if (periodKey == 'morning') {
        insightTitle = isEs ? "Olvidos matutinos" : (isPt ? "Omissões matinais" : "Morning omissions");
        insightText = isEs
            ? "La mayoría de omisiones son en la mañana. Vincula la toma con tu desayuno."
            : (isPt ? "A maioria das omissões ocorre pela manhã. Vincule ao café da manhã." : "Most omissions occur in the morning. Pair them with breakfast.");
      } else if (periodKey == 'afternoon') {
        insightTitle = isEs ? "Olvidos en la tarde" : (isPt ? "Omissões à tarde" : "Afternoon omissions");
        insightText = isEs
            ? "Sueles olvidar dosis vespertinas. Configura alarmas audibles o usa un pastillero."
            : (isPt ? "Você costuma esquecer doses à tarde. Configure alarmes audíveis." : "You tend to miss afternoon doses. Set loud alarms or use a pillbox.");
      } else if (periodKey == 'night') {
        insightTitle = isEs ? "Olvidos nocturnos" : (isPt ? "Omissões noturnas" : "Night omissions");
        insightText = isEs
            ? "El horario nocturno concentra más olvidos. Deja tu medicina visible antes de dormir."
            : (isPt ? "A noite concentra mais omissões. Deixe o remédio visível antes de dormir." : "Nighttime has more missed doses. Keep meds visible before bed.");
      } else {
        insightTitle = isEs ? "Olvidos en madrugada" : (isPt ? "Omissões na madrugada" : "Overnight omissions");
        insightText = isEs
            ? "Tienes omisiones en madrugada. Consulta con tu médico si puedes reajustar horarios."
            : (isPt ? "Omissões na madrugada. Consulte o médico sobre ajuste de horários." : "Overnight omissions detected. Ask your doctor about schedule adjustments.");
      }
    } else if (percentage >= 85) {
      insightTitle = isEs ? "¡Ritmo impecable!" : (isPt ? "Ritmo impecável!" : "Flawless rhythm!");
      insightText = isEs
          ? "Excelente constancia médica. La disciplina maximiza la eficacia de tu tratamiento."
          : (isPt ? "Excelente constância médica. A disciplina maximiza a eficácia do tratamento." : "Great consistency. Perfect discipline ensures maximum medical effectiveness.");
      insightColor = AppTheme.successColor;
      insightIcon = Icons.verified_rounded;
    } else {
      insightTitle = l10n?.insightGoodTitle ?? "¡Buen ritmo!";
      insightText = l10n?.insightGoodText ?? "Pequeños hábitos, grandes resultados. ¡Sigue así!";
      insightColor = AppTheme.primaryColor;
      insightIcon = Icons.thumb_up_alt_outlined;
    }

    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const streakColor = Color(0xFFFF6B00);
    final streakGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Color.alphaBlend(streakColor.withValues(alpha: 0.04), Theme.of(context).cardColor),
              Color.alphaBlend(streakColor.withValues(alpha: 0.15), Theme.of(context).cardColor),
            ]
          : [
              Color.alphaBlend(streakColor.withValues(alpha: 0.02), Colors.white),
              Color.alphaBlend(streakColor.withValues(alpha: 0.09), Colors.white),
            ],
    );

    final insightGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Color.alphaBlend(insightColor.withValues(alpha: 0.04), Theme.of(context).cardColor),
              Color.alphaBlend(insightColor.withValues(alpha: 0.14), Theme.of(context).cardColor),
            ]
          : [
              Color.alphaBlend(insightColor.withValues(alpha: 0.02), Colors.white),
              Color.alphaBlend(insightColor.withValues(alpha: 0.08), Colors.white),
            ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Streak Card estilo Duolingo (Tappable modal)
          Expanded(
            flex: 4,
            child: _PressableScale(
              scaleFactor: 0.96,
              onTap: () {
                HapticFeedback.lightImpact();
                StreakCelebrationSheet.show(
                  context,
                  racha: racha,
                  tratamientos: tratamientos,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: streakGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: showBorder
                      ? Border.all(color: AppTheme.borderColor)
                      : null,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            size: 20,
                            color: Color(0xFFFF6B00),
                          ),
                        ),
                        if (racha >= 7)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Top",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B00),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.streakDays(racha) ?? "$racha ${racha == 1 ? 'día' : 'días'}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      racha > 0
                          ? (l10n?.activeStreak ?? "Racha activa")
                          : (isEs ? "Sin racha" : (isPt ? "Sem sequência" : "No streak")),
                      style: TextStyle(fontSize: 11, color: AppTheme.secondaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(7, (i) {
                        final bool isActive = racha > 0 && i < racha.clamp(0, 7);
                        return Expanded(
                          child: Container(
                            height: 3.5,
                            margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? streakColor
                                  : streakColor.withValues(alpha: isDark ? 0.25 : 0.18),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Insight Card (Clickable to open Omission Analysis Sheet)
          Expanded(
            flex: 6,
            child: _PressableScale(
              scaleFactor: 0.96,
              onTap: canOpenAnalysis
                  ? () => OmissionAnalysisSheet.show(context, tratamientos)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  gradient: insightGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: showBorder
                      ? Border.all(color: AppTheme.borderColor)
                      : null,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: insightColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(insightIcon, color: insightColor, size: 17),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              insightTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (canOpenAnalysis)
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppTheme.secondaryTextColor.withValues(alpha: 0.7),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        insightText,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.secondaryTextColor,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (canOpenAnalysis) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isEs ? "Ver análisis horario" : (isPt ? "Ver análise horária" : "View time analysis"),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: insightColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: insightColor,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _captureChartPng() async {
    try {
      if (_ringChartKey.currentContext == null) return null;
      final boundary = _ringChartKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturando gráfico del reporte: $e");
      return null;
    }
  }

  Future<Uint8List> _generateFallbackChartImage({
    required int tomadas,
    required int omitidas,
    required int aplazadas,
    int notificadas = 0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 300));
    final center = const Offset(150, 150);
    const radius = 110.0;
    const strokeWidth = 28.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final total = tomadas + omitidas + aplazadas + notificadas;
    if (total > 0) {
      double startAngle = -pi / 2;
      void drawArcSegment(int count, Color color) {
        if (count <= 0) return;
        final sweep = (count / total) * 2 * pi;
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
        startAngle += sweep;
      }

      drawArcSegment(tomadas, const Color(0xFF10B981));
      drawArcSegment(aplazadas, const Color(0xFFF59E0B));
      drawArcSegment(notificadas, const Color(0xFFFBBF24));
      drawArcSegment(omitidas, const Color(0xFFEF4444));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(300, 300);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _exportPdfReport({
    required List<Tratamiento> tratamientos,
    required Map<String, DateTime> dateRange,
    required int tomadas,
    required int omitidas,
    required int aplazadas,
    int notificadas = 0,
    required int programadas,
  }) async {
    final canProceed = await SubscriptionGuard.canExportPdf(context);
    if (!canProceed || !mounted) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      Uint8List? chartBytes = await _captureChartPng();
      chartBytes ??= await _generateFallbackChartImage(
        tomadas: tomadas,
        omitidas: omitidas,
        aplazadas: aplazadas,
        notificadas: notificadas,
      );

      final List<Map<String, dynamic>> tratamientosData = [];
      for (var t in tratamientos) {
        final stats = _calcularEstadisticas(t, dateRange);
        final int prog = stats['programadasPasadas'] ?? 0;
        final int tom = stats['tomadas'] ?? 0;
        if (prog > 0) {
          tratamientosData.add({
            'nombreMedicamento': t.nombreMedicamento,
            'adherencia': (tom / prog) * 100,
            'tomadas': tom,
            'programadas': prog,
          });
        }
      }

      String intervalText;
      switch (_selectedInterval) {
        case ProgresoInterval.semana:
          intervalText = "SEMANAL";
          break;
        case ProgresoInterval.mes:
          intervalText = "MENSUAL";
          break;
        case ProgresoInterval.anio:
          intervalText = "ANUAL";
          break;
        case ProgresoInterval.todo:
          intervalText = "HISTÓRICO ACUMULADO";
          break;
      }

      await _pdfService.generateAndShowPdf(
        intervalText: intervalText,
        tomadas: tomadas,
        omitidas: omitidas,
        aplazadas: aplazadas,
        notificadas: notificadas,
        tratamientos: tratamientosData,
        chartImage: chartBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al generar el informe médico: $e"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Widget _buildPdfExportCard({
    required List<Tratamiento> tratamientos,
    required Map<String, DateTime> dateRange,
    required int tomadas,
    required int omitidas,
    required int aplazadas,
    int notificadas = 0,
    required int programadas,
  }) {
    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;
    final langCode = Localizations.localeOf(context).languageCode;
    final isEs = langCode.startsWith('es');
    final isPt = langCode.startsWith('pt');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const pdfColor = Color(0xFF2563EB);
    final pdfGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Color.alphaBlend(pdfColor.withValues(alpha: 0.04), Theme.of(context).cardColor),
              Color.alphaBlend(pdfColor.withValues(alpha: 0.13), Theme.of(context).cardColor),
            ]
          : [
              Color.alphaBlend(pdfColor.withValues(alpha: 0.02), Colors.white),
              Color.alphaBlend(pdfColor.withValues(alpha: 0.08), Colors.white),
            ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: pdfGradient,
        borderRadius: BorderRadius.circular(22),
        border: showBorder
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pdfColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 28,
              color: pdfColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEs ? "Reporte Médico PDF" : (isPt ? "Relatório Médico PDF" : "Medical Report PDF"),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEs
                      ? "Descarga o comparte un informe con tu especialista."
                      : (isPt
                          ? "Baixe ou compartilhe um relatório com seu médico."
                          : "Download or share an adherence report with your doctor."),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryTextColor,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PressableScale(
            scaleFactor: 0.95,
            onTap: _isGeneratingPdf
                ? null
                : () => _exportPdfReport(
                      tratamientos: tratamientos,
                      dateRange: dateRange,
                      tomadas: tomadas,
                      omitidas: omitidas,
                      aplazadas: aplazadas,
                      notificadas: notificadas,
                      programadas: programadas,
                    ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: pdfColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: pdfColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isGeneratingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          isEs ? "Exportar" : (isPt ? "Exportar" : "Export"),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  IconData _getSortOrderIcon(TreatmentSortOrder order) {
    switch (order) {
      case TreatmentSortOrder.adherenceAsc:
        return Icons.trending_down_rounded;
      case TreatmentSortOrder.adherenceDesc:
        return Icons.trending_up_rounded;
      case TreatmentSortOrder.alphabeticalAsc:
      case TreatmentSortOrder.alphabeticalDesc:
        return Icons.sort_by_alpha_rounded;
    }
  }

  String _getSortOrderShortLabel(TreatmentSortOrder order, bool isEs, bool isPt) {
    switch (order) {
      case TreatmentSortOrder.adherenceAsc:
        return isEs ? "Menor" : (isPt ? "Menor" : "Lowest");
      case TreatmentSortOrder.adherenceDesc:
        return isEs ? "Mayor" : (isPt ? "Maior" : "Highest");
      case TreatmentSortOrder.alphabeticalAsc:
        return "A - Z";
      case TreatmentSortOrder.alphabeticalDesc:
        return "Z - A";
    }
  }

  PopupMenuItem<TreatmentSortOrder> _buildSortMenuItem({
    required TreatmentSortOrder order,
    required IconData icon,
    required String label,
    String? subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return PopupMenuItem<TreatmentSortOrder>(
      value: order,
      height: subtitle != null ? 50 : 42,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: AppTheme.primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildTreatmentBreakdownSection(
    List<Tratamiento> tratamientos,
    Map<String, DateTime> dateRange,
  ) {
    if (tratamientos.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final isEs = langCode.startsWith('es');
    final isPt = langCode.startsWith('pt');
    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;

    final title = isEs
        ? "Rendimiento por medicamento"
        : (isPt ? "Desempenho por medicamento" : "Performance by medicine");

    // Precalcular estadísticas del periodo para cada tratamiento
    final Map<String, Map<String, int>> treatmentStatsMap = {};
    for (var t in tratamientos) {
      treatmentStatsMap[t.id] = _calcularEstadisticas(t, dateRange);
    }

    // Filtrar SOLO los tratamientos con dosis o actividad en este periodo de tiempo
    final activeTreatments = tratamientos.where((t) {
      final stats = treatmentStatsMap[t.id]!;
      final prog = stats['programadasPasadas'] ?? 0;
      final tom = stats['tomadas'] ?? 0;
      final omi = stats['omitidas'] ?? 0;
      final apl = stats['aplazadas'] ?? 0;
      return (prog > 0 || tom > 0 || omi > 0 || apl > 0);
    }).toList();

    // Ordenar según el criterio seleccionado por el usuario
    switch (_treatmentSortOrder) {
      case TreatmentSortOrder.adherenceAsc:
        activeTreatments.sort((a, b) {
          final statsA = treatmentStatsMap[a.id]!;
          final statsB = treatmentStatsMap[b.id]!;
          final progA = statsA['programadasPasadas'] ?? 0;
          final progB = statsB['programadasPasadas'] ?? 0;
          final pctA = progA > 0 ? ((statsA['tomadas'] ?? 0) / progA) : 1.0;
          final pctB = progB > 0 ? ((statsB['tomadas'] ?? 0) / progB) : 1.0;
          final cmp = pctA.compareTo(pctB);
          if (cmp != 0) return cmp;
          return a.nombreMedicamento.toLowerCase().compareTo(b.nombreMedicamento.toLowerCase());
        });
        break;
      case TreatmentSortOrder.adherenceDesc:
        activeTreatments.sort((a, b) {
          final statsA = treatmentStatsMap[a.id]!;
          final statsB = treatmentStatsMap[b.id]!;
          final progA = statsA['programadasPasadas'] ?? 0;
          final progB = statsB['programadasPasadas'] ?? 0;
          final pctA = progA > 0 ? ((statsA['tomadas'] ?? 0) / progA) : 1.0;
          final pctB = progB > 0 ? ((statsB['tomadas'] ?? 0) / progB) : 1.0;
          final cmp = pctB.compareTo(pctA);
          if (cmp != 0) return cmp;
          return a.nombreMedicamento.toLowerCase().compareTo(b.nombreMedicamento.toLowerCase());
        });
        break;
      case TreatmentSortOrder.alphabeticalAsc:
        activeTreatments.sort((a, b) =>
            a.nombreMedicamento.toLowerCase().compareTo(b.nombreMedicamento.toLowerCase()));
        break;
      case TreatmentSortOrder.alphabeticalDesc:
        activeTreatments.sort((a, b) =>
            b.nombreMedicamento.toLowerCase().compareTo(a.nombreMedicamento.toLowerCase()));
        break;
    }

    if (activeTreatments.isEmpty) {
      return Column(
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
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: showBorder ? Border.all(color: AppTheme.borderColor) : null,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.medication_outlined,
                  size: 32,
                  color: AppTheme.secondaryTextColor.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  isEs
                      ? "Sin medicamentos programados para este periodo"
                      : (isPt
                          ? "Nenhum medicamento agendado neste período"
                          : "No medications scheduled in this period"),
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final hasMore = activeTreatments.length > 3;
    final displayTreatments = activeTreatments.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEs
                        ? "${activeTreatments.length} ${activeTreatments.length == 1 ? 'medicamento activo' : 'medicamentos activos'} en este periodo"
                        : (isPt
                            ? "${activeTreatments.length} ${activeTreatments.length == 1 ? 'medicamento ativo' : 'medicamentos ativos'} no período"
                            : "${activeTreatments.length} active ${activeTreatments.length == 1 ? 'medication' : 'medications'} in period"),
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (activeTreatments.length > 1) ...[
              const SizedBox(width: 14),
              PopupMenuButton<TreatmentSortOrder>(
                initialValue: _treatmentSortOrder,
                tooltip: isEs ? "Ordenar medicamentos" : "Sort medications",
                position: PopupMenuPosition.under,
                offset: const Offset(0, 6),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppTheme.borderColor.withValues(alpha: isDark ? 0.4 : 0.8),
                    width: 1,
                  ),
                ),
                onSelected: (TreatmentSortOrder order) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _treatmentSortOrder = order;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  _buildSortMenuItem(
                    order: TreatmentSortOrder.adherenceAsc,
                    icon: Icons.trending_down_rounded,
                    label: isEs ? "Menor adherencia" : (isPt ? "Menor adesão" : "Lowest adherence"),
                    subtitle: isEs ? "Prioridad clínica" : "Clinical priority",
                    isSelected: _treatmentSortOrder == TreatmentSortOrder.adherenceAsc,
                    isDark: isDark,
                  ),
                  _buildSortMenuItem(
                    order: TreatmentSortOrder.adherenceDesc,
                    icon: Icons.trending_up_rounded,
                    label: isEs ? "Mayor adherencia" : (isPt ? "Maior adesão" : "Highest adherence"),
                    subtitle: isEs ? "Mejor desempeño" : "Best performance",
                    isSelected: _treatmentSortOrder == TreatmentSortOrder.adherenceDesc,
                    isDark: isDark,
                  ),
                  _buildSortMenuItem(
                    order: TreatmentSortOrder.alphabeticalAsc,
                    icon: Icons.sort_by_alpha_rounded,
                    label: isEs ? "Nombre (A - Z)" : "Name (A - Z)",
                    isSelected: _treatmentSortOrder == TreatmentSortOrder.alphabeticalAsc,
                    isDark: isDark,
                  ),
                  _buildSortMenuItem(
                    order: TreatmentSortOrder.alphabeticalDesc,
                    icon: Icons.sort_by_alpha_rounded,
                    label: isEs ? "Nombre (Z - A)" : "Name (Z - A)",
                    isSelected: _treatmentSortOrder == TreatmentSortOrder.alphabeticalDesc,
                    isDark: isDark,
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: isDark ? 0.4 : 0.8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSortOrderIcon(_treatmentSortOrder),
                        size: 13,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _getSortOrderShortLabel(_treatmentSortOrder, isEs, isPt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...displayTreatments.map((t) {
          final stats = treatmentStatsMap[t.id] ?? _calcularEstadisticas(t, dateRange);
          final isExpanded = _expandedTreatments.contains(t.id);
          return TreatmentAccordionCard(
            tratamiento: t,
            stats: stats,
            isExpanded: isExpanded,
            onToggle: () {
              setState(() {
                if (isExpanded) {
                  _expandedTreatments.remove(t.id);
                } else {
                  _expandedTreatments.add(t.id);
                }
              });
            },
          );
        }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Center(
              child: _PressableScale(
                scaleFactor: 0.96,
                onTap: () {
                  HapticFeedback.lightImpact();
                  FullTreatmentBreakdownSheet.show(
                    context,
                    tratamientos: activeTreatments,
                    dateRange: dateRange,
                    statsCalculator: (t, r) => _calcularEstadisticas(t, r),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.8,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.035,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEs
                            ? "Ver desglose completo (${activeTreatments.length}) →"
                            : (isPt
                                ? "Ver detalhamento completo (${activeTreatments.length}) →"
                                : "View full breakdown (${activeTreatments.length}) →"),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWeeklyDayBadge({
    required DateTime date,
    required String dayLabel,
    required bool isSelected,
    required bool isToday,
    required bool isFuture,
    required List<TodayDose> dayDoses,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    IconData? statusIcon;

    if (isFuture) {
      statusColor = AppTheme.secondaryTextColor.withValues(alpha: 0.25);
      statusIcon = null;
    } else if (dayDoses.isEmpty) {
      statusColor = AppTheme.secondaryTextColor.withValues(alpha: 0.2);
      statusIcon = null;
    } else {
      final hasSkipped = dayDoses.any((d) => d.status == DoseStatus.omitida);
      final allTaken = dayDoses.every((d) => d.status == DoseStatus.tomada);
      final hasSnoozed = dayDoses.any((d) => d.status == DoseStatus.aplazada);

      if (hasSkipped) {
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.close_rounded;
      } else if (allTaken) {
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_rounded;
      } else if (hasSnoozed) {
        statusColor = Colors.orange;
        statusIcon = Icons.schedule_rounded;
      } else {
        statusColor = Colors.amber;
        statusIcon = Icons.notifications_none_rounded;
      }
    }

    return Expanded(
      child: _PressableScale(
        onTap: onTap,
        scaleFactor: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.14)
                : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.45) : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${date.day}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusIcon != null ? statusColor : Colors.transparent,
                  border: statusIcon == null ? Border.all(color: statusColor, width: 1.5) : null,
                ),
                child: statusIcon != null
                    ? Icon(statusIcon, size: 12, color: Colors.white)
                    : Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.secondaryTextColor.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyHabitStrip(List<TodayDose> allWeekDoses) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    final langCode = Localizations.localeOf(context).languageCode;
    final defaultLabels = langCode == 'en'
        ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final date = startOfWeek.add(Duration(days: i));
          final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
          final isFuture = date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
          final isSelected = _selectedTimelineDayIndex == i;

          final dayDoses = allWeekDoses.where((d) =>
              d.hora.year == date.year &&
              d.hora.month == date.month &&
              d.hora.day == date.day).toList();

          return _buildWeeklyDayBadge(
            date: date,
            dayLabel: defaultLabels[i],
            isSelected: isSelected,
            isToday: isToday,
            isFuture: isFuture,
            dayDoses: dayDoses,
            onTap: () {
              setState(() {
                if (_selectedTimelineDayIndex == i) {
                  _selectedTimelineDayIndex = null;
                } else {
                  _selectedTimelineDayIndex = i;
                }
              });
            },
          );
        }),
      ),
    );
  }

  Widget _buildStatusFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? Color.alphaBlend(color.withValues(alpha: 0.18), Theme.of(context).cardColor)
        : Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);

    return _PressableScale(
      onTap: onTap,
      scaleFactor: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Theme.of(context).cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.borderColor.withValues(alpha: 0.7),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? color : AppTheme.secondaryTextColor),
              const SizedBox(width: 6),
            ] else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : AppTheme.secondaryTextColor.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? (isDark ? Colors.white : color) : AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.25) : AppTheme.secondaryTextColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : AppTheme.secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTimeline(List<TodayDose> doses, List<Tratamiento> tratamientos) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final isEs = langCode.startsWith('es');
    final isPt = langCode.startsWith('pt');

    String title = l10n?.weekSummary ?? "Resumen de la semana";
    switch (_selectedInterval) {
      case ProgresoInterval.semana:
        title = l10n?.weekSummary ?? "Resumen de la semana";
        break;
      case ProgresoInterval.mes:
        title = l10n?.monthSummary ?? "Resumen del mes";
        break;
      case ProgresoInterval.anio:
        title = l10n?.yearSummary ?? "Resumen del año";
        break;
      case ProgresoInterval.todo:
        title = l10n?.cumulativeSummary ?? "Resumen acumulado";
        break;
    }

    final now = DateTime.now();

    final sortedDoses = List<TodayDose>.from(doses);
    if (_isSortAscending) {
      sortedDoses.sort((a, b) => a.hora.compareTo(b.hora));
    } else {
      sortedDoses.sort((a, b) => b.hora.compareTo(a.hora));
    }

    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    DateTime? selectedFilterDate;
    if (_selectedInterval == ProgresoInterval.semana && _selectedTimelineDayIndex != null) {
      selectedFilterDate = startOfWeek.add(Duration(days: _selectedTimelineDayIndex!));
    }

    final dayFilteredDoses = selectedFilterDate != null
        ? sortedDoses.where((d) =>
            d.hora.year == selectedFilterDate!.year &&
            d.hora.month == selectedFilterDate.month &&
            d.hora.day == selectedFilterDate.day).toList()
        : sortedDoses;

    final totalCount = dayFilteredDoses.length;
    final takenCount = dayFilteredDoses.where((d) => d.status == DoseStatus.tomada).length;
    final missedCount = dayFilteredDoses.where((d) => d.status == DoseStatus.omitida).length;
    final snoozedCount = dayFilteredDoses.where((d) => d.status == DoseStatus.aplazada).length;
    final notifiedCount = dayFilteredDoses.where((d) => d.status == DoseStatus.notificada).length;

    final displayDoses = _selectedStatusFilter == null
        ? dayFilteredDoses
        : dayFilteredDoses.where((d) => d.status == _selectedStatusFilter).toList();

    final visibleDoses = displayDoses.take(4).toList();

    final timelineCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
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
                      selectedFilterDate != null
                          ? "${DateFormat('EEEE d MMMM', isEs ? 'es_ES' : (isPt ? 'pt_BR' : 'en_US')).format(selectedFilterDate)} · ${displayDoses.length} ${displayDoses.length == 1 ? 'dosis' : 'dosis'}"
                          : (_selectedStatusFilter != null
                              ? "${displayDoses.length} de $totalCount dosis"
                              : (l10n?.dosesInPeriod(doses.length) ?? "${doses.length} dosis en periodo")),
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (displayDoses.isNotEmpty)
                _PressableScale(
                  scaleFactor: 0.95,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSortAscending = !_isSortAscending;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: (context.watch<PreferenceNotifier>().showCardBorder ||
                              context.watch<PreferenceNotifier>().highContrast)
                          ? Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            )
                          : null,
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
                          _isSortAscending ? (l10n?.oldestFirst ?? "Más antiguos") : (l10n?.mostRecent ?? "Más recientes"),
                          style: TextStyle(
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
          const SizedBox(height: 16),
          if (_selectedInterval == ProgresoInterval.semana) ...[
            _buildWeeklyHabitStrip(sortedDoses),
            if (selectedFilterDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEs ? "Dosis de este día:" : (isPt ? "Doses deste dia:" : "Doses on this day:"),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTimelineDayIndex = null;
                        });
                      },
                      child: Text(
                        isEs ? "Ver toda la semana" : (isPt ? "Ver toda a semana" : "View full week"),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (dayFilteredDoses.isNotEmpty && (takenCount > 0 || missedCount > 0 || snoozedCount > 0 || notifiedCount > 0)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2, right: 2),
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStatusFilterChip(
                      label: isEs ? "Todas" : (isPt ? "Todas" : "All"),
                      count: totalCount,
                      isSelected: _selectedStatusFilter == null,
                      color: AppTheme.primaryColor,
                      onTap: () => setState(() => _selectedStatusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusFilterChip(
                      label: isEs ? "Tomadas" : (isPt ? "Tomadas" : "Taken"),
                      count: takenCount,
                      isSelected: _selectedStatusFilter == DoseStatus.tomada,
                      color: AppTheme.successColor,
                      icon: Icons.check_circle_outline_rounded,
                      onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == DoseStatus.tomada ? null : DoseStatus.tomada),
                    ),
                    if (missedCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        label: isEs ? "Omitidas" : (isPt ? "Omitidas" : "Missed"),
                        count: missedCount,
                        isSelected: _selectedStatusFilter == DoseStatus.omitida,
                        color: AppTheme.errorColor,
                        icon: Icons.cancel_outlined,
                        onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == DoseStatus.omitida ? null : DoseStatus.omitida),
                      ),
                    ],
                    if (snoozedCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        label: isEs ? "Aplazadas" : (isPt ? "Adiadas" : "Snoozed"),
                        count: snoozedCount,
                        isSelected: _selectedStatusFilter == DoseStatus.aplazada,
                        color: Colors.orange,
                        icon: Icons.schedule_rounded,
                        onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == DoseStatus.aplazada ? null : DoseStatus.aplazada),
                      ),
                    ],
                    if (notifiedCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        label: isEs ? "Notificadas" : (isPt ? "Notificadas" : "Notified"),
                        count: notifiedCount,
                        isSelected: _selectedStatusFilter == DoseStatus.notificada,
                        color: Colors.amber,
                        icon: Icons.notifications_active_outlined,
                        onTap: () => setState(() => _selectedStatusFilter = _selectedStatusFilter == DoseStatus.notificada ? null : DoseStatus.notificada),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (displayDoses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _selectedStatusFilter != null
                      ? (isEs ? "No hay dosis con este estado." : "No doses with this status.")
                      : (selectedFilterDate != null
                          ? (isEs ? "No hay dosis programadas para este día." : "No doses scheduled for this day.")
                          : (l10n?.calendarNoEvents ?? "No hay dosis programadas para este periodo.")),
                  style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
                ),
              ),
            )
          else ...[
            ...visibleDoses.asMap().entries.map((entry) {
              final index = entry.key;
              final dose = entry.value;
              final isTodayDose = dose.hora.year == now.year && dose.hora.month == now.month && dose.hora.day == now.day;
              final timeStr = isTodayDose 
                  ? DateFormat('hh:mm a', langCode == 'en' ? 'en_US' : 'es_ES').format(dose.hora)
                  : DateFormat('d MMM, hh:mm a', langCode == 'en' ? 'en_US' : 'es_ES').format(dose.hora);
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
              String displayStatus = l10n?.doseStatusScheduled ?? 'Programada';

              final isPast = dose.hora.isBefore(DateTime.now());

              if (dose.status == DoseStatus.tomada) {
                nodeColor = AppTheme.successColor;
                nodeWidget = Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                );
                displayStatus = l10n?.doseStatusTaken ?? 'Tomada';
              } else if (dose.status == DoseStatus.omitida) {
                nodeColor = AppTheme.errorColor;
                nodeWidget = Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                );
                displayStatus = l10n?.doseStatusSkipped ?? 'Omitida';
              } else if (dose.status == DoseStatus.aplazada) {
                nodeColor = Colors.orange;
                nodeWidget = Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
                  child: const Icon(Icons.watch_later_outlined, color: Colors.white, size: 12),
                );
                displayStatus = l10n?.doseStatusSnoozed ?? 'Aplazada';
              } else if (dose.status == DoseStatus.notificada || (dose.status == DoseStatus.pendiente && isPast)) {
                nodeColor = Colors.amber;
                nodeWidget = Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
                  child: const Icon(Icons.notifications, color: Colors.white, size: 12),
                );
                displayStatus = l10n?.doseStatusNotified ?? 'Notificada';
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
                                color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0.0 : 16.0),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${AppUtils.localizePresentation(context, dose.presentacion)} • $displayStatus",
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
                                  color: Color(int.parse(dose.profile!.colorHex.replaceFirst('#', 'FF'), radix: 16)).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Color(int.parse(dose.profile!.colorHex.replaceFirst('#', 'FF'), radix: 16)).withValues(alpha: 0.2)),
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
            }),
            if (displayDoses.length > 4) ...[
              const SizedBox(height: 14),
              Center(
                child: _PressableScale(
                  scaleFactor: 0.96,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    FullHistorySheet.show(
                      context,
                      tratamientos,
                      rawEntries: displayDoses.map((d) => {
                        'treatmentName': d.nombreMedicamento,
                        'presentation': d.presentacion,
                        'time': d.hora,
                        'status': d.status,
                        'profileName': d.profile?.name,
                        'profileColorHex': d.profile?.colorHex,
                      }).toList(),
                      sheetTitle: title,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: (context.watch<PreferenceNotifier>().showCardBorder ||
                              context.watch<PreferenceNotifier>().highContrast)
                          ? Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.25),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isEs
                              ? "Ver historial completo (${displayDoses.length} dosis)"
                              : (isPt
                                  ? "Ver histórico completo (${displayDoses.length} doses)"
                                  : "View full history (${displayDoses.length} doses)"),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppTheme.primaryColor.withValues(alpha: 0.75),
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
        container: TutorialTooltip(
          icon: Icons.filter_list_rounded,
          title: l10n?.tutorialStep10Title ?? 'Filtros y Resumen Desplegable',
          description: l10n?.tutorialStep10Desc ?? 'Filtra tu progreso por Semana, Mes o Año. Usa "Ver más" para desplegar la lista y cambia el orden entre "Más recientes" y "Más antiguos".',
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
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
              text = l10n?.intervalWeek ?? 'Semana';
              break;
            case ProgresoInterval.mes:
              text = l10n?.intervalMonth ?? 'Mes';
              break;
            case ProgresoInterval.anio:
              text = l10n?.intervalYear ?? 'Año';
              break;
            case ProgresoInterval.todo:
              text = l10n?.intervalAll ?? 'Todo';
              break;
          }

          return Expanded(
            child: _PressableScale(
              scaleFactor: 0.95,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedInterval = interval;
                  _expandedTreatments.clear();
                  _selectedTimelineDayIndex = null;
                  _selectedStatusFilter = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.28),
                            blurRadius: 8,
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
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13.5,
                        letterSpacing: isSelected ? -0.2 : 0,
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
    final l10n = AppLocalizations.of(context);
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isModern = preferenceNotifier.interfaceStyle == 'modern';
    final user = authService.currentUser;
    final isAnimal = preferenceNotifier.isAnimalMode;
    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;
    final isGeneralMode = isManagedMode && caregiverNotifier.isGeneralMode;
    final activeProfile = isManagedMode ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal) : null;
    final profiles = isAnimal
        ? caregiverNotifier.managedProfiles.where((p) => p.isAnimal).toList()
        : caregiverNotifier.managedProfiles.where((p) => !p.isAnimal).toList();
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
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) => true,
        child: Stack(
          children: [
          Column(
            children: [
              _buildIntervalSelector(),
              Expanded(
                child: ModernContentFade(
                  topOffset: 0.0,
                  height: 32,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                  key: ValueKey('${isGeneralMode}_${activeProfile?.id}_$isManagedMode'),
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
                    int totalDosisAplazadas = 0;
                    int totalDosisNotificadas = 0;
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
                      totalDosisAplazadas += stats['aplazadas'] ?? 0;
                      totalDosisNotificadas += stats['notificadas'] ?? 0;
                      
                      if (profile != null) {
                        statsPorPaciente.putIfAbsent(profile, () => {'programadas': 0, 'tomadas': 0, 'omitidas': 0, 'aplazadas': 0, 'notificadas': 0});
                        statsPorPaciente[profile]!['programadas'] = statsPorPaciente[profile]!['programadas']! + stats['programadasPasadas']!;
                        statsPorPaciente[profile]!['tomadas'] = statsPorPaciente[profile]!['tomadas']! + stats['tomadas']!;
                        statsPorPaciente[profile]!['omitidas'] = statsPorPaciente[profile]!['omitidas']! + stats['omitidas']!;
                        statsPorPaciente[profile]!['aplazadas'] = (statsPorPaciente[profile]!['aplazadas'] ?? 0) + (stats['aplazadas'] ?? 0);
                        statsPorPaciente[profile]!['notificadas'] = (statsPorPaciente[profile]!['notificadas'] ?? 0) + (stats['notificadas'] ?? 0);
                      }
                    }

                    final double? adherencia = totalDosisProgramadas > 0
                        ? (totalDosisTomadas / totalDosisProgramadas) * 100
                        : null;

                    final racha = _calcularRacha(tratamientos);
                    final dosisDelPeriodo = _obtenerDosisDelPeriodo(items, dateRange);

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis == Axis.vertical) {
                          final show = notification.metrics.pixels > 350;
                          if (show != _showScrollToTop) {
                            setState(() {
                              _showScrollToTop = show;
                            });
                          }
                        }
                        return false;
                      },
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 8.0,
                          bottom: isModern ? 100.0 : 8.0,
                        ),
                        children: [
                          _buildAdherenceRingCard(
                            adherencia,
                            totalDosisTomadas,
                            totalDosisOmitidas,
                            aplazadas: totalDosisAplazadas,
                            notificadas: totalDosisNotificadas,
                            programadas: totalDosisProgramadas,
                            isGeneralMode: isGeneralMode,
                            statsPorPaciente: statsPorPaciente,
                          ),
                          const SizedBox(height: 14),
                          _buildKpiMetricsGrid(
                            tomadas: totalDosisTomadas,
                            omitidas: totalDosisOmitidas,
                            aplazadas: totalDosisAplazadas,
                            notificadas: totalDosisNotificadas,
                            programadas: totalDosisProgramadas,
                            isGeneralMode: isGeneralMode,
                          ),
                          const SizedBox(height: 14),
                          _buildStreakAndInsightCard(
                            racha: racha,
                            percentage: adherencia,
                            tratamientos: tratamientos,
                            totalOmitidas: totalDosisOmitidas,
                            totalTomadas: totalDosisTomadas,
                          ),
                          const SizedBox(height: 14),
                          _buildPdfExportCard(
                            tratamientos: tratamientos,
                            dateRange: dateRange,
                            tomadas: totalDosisTomadas,
                            omitidas: totalDosisOmitidas,
                            aplazadas: totalDosisAplazadas,
                            notificadas: totalDosisNotificadas,
                            programadas: totalDosisProgramadas,
                          ),
                          const SizedBox(height: 20),
                          
                          if (isGeneralMode && statsPorPaciente.isNotEmpty) ...[
                            Text(
                              l10n?.progressByPatient ?? "Progreso por paciente",
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

                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              final pGradient = LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        Color.alphaBlend(profileColor.withValues(alpha: 0.04), Theme.of(context).cardColor),
                                        Color.alphaBlend(profileColor.withValues(alpha: 0.12), Theme.of(context).cardColor),
                                      ]
                                    : [
                                        Color.alphaBlend(profileColor.withValues(alpha: 0.015), Colors.white),
                                        Color.alphaBlend(profileColor.withValues(alpha: 0.07), Colors.white),
                                      ],
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: pGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  border: (preferenceNotifier.showCardBorder || preferenceNotifier.highContrast)
                                      ? Border.all(color: AppTheme.borderColor)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: profileColor.withValues(alpha: 0.15),
                                      child: Text(
                                        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: profileColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            profile.name,
                                            style: TextStyle(
                                              color: AppTheme.primaryTextColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
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
                                              backgroundColor: profileColor.withValues(alpha: 0.15),
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

                          _buildTreatmentBreakdownSection(tratamientos, dateRange),
                          const SizedBox(height: 24),

                          _buildTodayTimeline(dosisDelPeriodo, tratamientos),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n?.complianceChartTitle ?? "Gráfico de cumplimiento",
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
                              border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                                  ? Border.all(color: AppTheme.borderColor)
                                  : null,
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedInterval == ProgresoInterval.semana 
                                      ? (l10n?.complianceWeekly ?? "Cumplimiento de la semana")
                                      : _selectedInterval == ProgresoInterval.mes
                                          ? (l10n?.complianceMonthly ?? "Cumplimiento del mes")
                                          : _selectedInterval == ProgresoInterval.anio
                                              ? (l10n?.complianceYearly ?? "Cumplimiento del año")
                                              : (l10n?.complianceHistorical ?? "Cumplimiento histórico"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedInterval == ProgresoInterval.semana 
                                      ? (l10n?.complianceWeeklySubtitle ?? "Porcentaje de tomas por día")
                                      : _selectedInterval == ProgresoInterval.mes
                                          ? (l10n?.complianceMonthlySubtitle ?? "Porcentaje de tomas por bloques de 5 días")
                                          : _selectedInterval == ProgresoInterval.anio
                                              ? (l10n?.complianceYearlySubtitle ?? "Porcentaje de tomas por mes")
                                              : (l10n?.complianceHistoricalSubtitle ?? "Porcentaje de tomas en los últimos 6 meses"),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 20),
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
                      ),
                    );
                  },
                ),
              ),
            ),
            ],
          ),
          Positioned(
            bottom: isModern ? 124.0 : 24.0,
            right: 16.0,
            child: AnimatedScale(
              scale: _showScrollToTop ? 1.0 : 0.88,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showScrollToTop ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !_showScrollToTop,
                  child: _PressableScale(
                    scaleFactor: 0.92,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Material(
                      elevation: 6,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                      shape: const CircleBorder(),
                      color: AppTheme.primaryColor,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

/// Emil Kowalski craft: Micro-interacción física táctil (Apple style)
/// Proporciona compresión elástica instantánea al presionar (scale down a 0.96-0.97)
/// y rebote suave con curvas físicas (Curves.easeOutCubic) en lugar de saltos bruscos.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const _PressableScale({
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class RingSegment {
  final double value;
  final Color color;
  final DoseStatus? status;
  final bool isSelected;
  final bool isDimmed;

  const RingSegment({
    required this.value,
    required this.color,
    this.status,
    this.isSelected = false,
    this.isDimmed = false,
  });
}

class SegmentRingPainter extends CustomPainter {
  final List<RingSegment> segments;
  final Color trackColor;

  SegmentRingPainter({
    required this.segments,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;
    final radius = (size.width - strokeWidth) / 2;

    // Background track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final validSegments = segments.where((s) => s.value > 0).toList();
    if (validSegments.isEmpty) return;

    final double total = validSegments.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final n = validSegments.length;

    if (n == 1) {
      final seg = validSegments.first;
      if (seg.isSelected) {
        final glowPaint = Paint()
          ..color = seg.color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -pi / 2,
          2 * pi,
          false,
          glowPaint,
        );
      }

      final Color paintColor = seg.isDimmed ? seg.color.withValues(alpha: 0.32) : seg.color;
      final double segStroke = seg.isSelected ? strokeWidth + 1.2 : (seg.isDimmed ? strokeWidth - 0.5 : strokeWidth);

      final paint = Paint()
        ..color = paintColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = segStroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi,
        false,
        paint,
      );
      return;
    }

    // Gap angle to ensure distinct rounded caps
    final capRadiusAngle = (strokeWidth / 2) / radius;
    final gapAngle = (2 * capRadiusAngle) + 0.08;
    final totalGap = n * gapAngle;
    final availableAngle = (2 * pi) - totalGap;

    double currentAngle = -pi / 2;

    for (final seg in validSegments) {
      final fraction = seg.value / total;
      final sweepAngle = (fraction * availableAngle).clamp(0.02, availableAngle);

      // Sutil halo de brillo al seleccionar (delicado y equilibrado)
      if (seg.isSelected) {
        final glowPaint = Paint()
          ..color = seg.color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentAngle + (gapAngle / 2),
          sweepAngle,
          false,
          glowPaint,
        );
      }

      final Color paintColor = seg.isDimmed
          ? seg.color.withValues(alpha: 0.32)
          : seg.color;

      final double segStroke = seg.isSelected
          ? strokeWidth + 1.2
          : (seg.isDimmed ? strokeWidth - 0.5 : strokeWidth);

      final segmentPaint = Paint()
        ..color = paintColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = segStroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle + (gapAngle / 2),
        sweepAngle,
        false,
        segmentPaint,
      );

      currentAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant SegmentRingPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length ||
        oldDelegate.trackColor != trackColor) {
      return true;
    }
    for (int i = 0; i < segments.length; i++) {
      if (oldDelegate.segments[i].value != segments[i].value ||
          oldDelegate.segments[i].color != segments[i].color ||
          oldDelegate.segments[i].isSelected != segments[i].isSelected ||
          oldDelegate.segments[i].isDimmed != segments[i].isDimmed) {
        return true;
      }
    }
    return false;
  }
}
