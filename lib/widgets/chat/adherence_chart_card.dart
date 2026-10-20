// lib/widgets/chat/adherence_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:meditime/models/tratamiento.dart';

import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/reports/reportes_page.dart';
import 'package:meditime/widgets/chat/chat_helpers.dart';

class AdherenceChartCard extends StatelessWidget {
  final Map<String, dynamic>? arguments;

  const AdherenceChartCard({super.key, this.arguments});

  ({
    DateTime startDate,
    DateTime endDate,
    String label,
    ReportInterval targetInterval,
  })
  _resolvePeriodConfig() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    ReportInterval targetInterval = ReportInterval.semana;

    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final args = arguments ?? {};
    final String? periodoType =
        args['periodo']?.toString().toLowerCase().trim();
    final dynamic diasRaw = args['dias'];
    final int? daysCount =
        diasRaw is int
            ? diasRaw
            : (diasRaw is String
                ? int.tryParse(diasRaw)
                : (diasRaw is num ? diasRaw.toInt() : null));
    final String? inicioStr = args['fechaInicio']?.toString().trim();
    final String? finStr = args['fechaFin']?.toString().trim();

    DateTime? customStart =
        inicioStr != null ? DateTime.tryParse(inicioStr) : null;
    DateTime? customEnd = finStr != null ? DateTime.tryParse(finStr) : null;

    if (customEnd != null) {
      endDate = DateTime(
        customEnd.year,
        customEnd.month,
        customEnd.day,
        23,
        59,
        59,
        999,
      );
    }

    String label;
    if (customStart != null) {
      startDate = DateTime(
        customStart.year,
        customStart.month,
        customStart.day,
      );
      targetInterval = ReportInterval.todo;
      label =
          '${startDate.day} ${months[startDate.month - 1]} - ${endDate.day} ${months[endDate.month - 1]} ${endDate.year}';
    } else if (periodoType == 'dia' || periodoType == 'hoy' || daysCount == 1) {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      targetInterval = ReportInterval.semana;
      label = '${now.day} ${months[now.month - 1]} ${now.year} (Hoy)';
    } else if (periodoType == 'mes' || daysCount == 30) {
      startDate = DateTime(now.year, now.month, 1);
      targetInterval = ReportInterval.mes;
      label =
          '${startDate.day} ${months[startDate.month - 1]} - ${now.day} ${months[now.month - 1]} ${now.year} (Mes en curso)';
    } else if (periodoType == 'anio' ||
        periodoType == 'año' ||
        daysCount == 365) {
      startDate = DateTime(now.year, 1, 1);
      targetInterval = ReportInterval.anio;
      label = '${now.year} (Año en curso)';
    } else if (daysCount != null && daysCount > 0) {
      startDate = now.subtract(Duration(days: daysCount - 1));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      targetInterval =
          daysCount <= 7
              ? ReportInterval.semana
              : (daysCount <= 31 ? ReportInterval.mes : ReportInterval.anio);
      label =
          '${startDate.day} ${months[startDate.month - 1]} - ${now.day} ${months[now.month - 1]} ${now.year} (Últimos $daysCount días)';
    } else {
      startDate = now.subtract(const Duration(days: 6));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      targetInterval = ReportInterval.semana;
      label =
          '${startDate.day} ${months[startDate.month - 1]} - ${now.day} ${months[now.month - 1]} ${now.year} (Últimos 7 días)';
    }

    return (
      startDate: startDate,
      endDate: endDate,
      label: label,
      targetInterval: targetInterval,
    );
  }

  /// Calculates statistics for a treatment in the given date range using tolerance matching
  Map<String, int> _calcularEstadisticas(
    Tratamiento tratamiento,
    DateTime startDate,
    DateTime endDate,
  ) {
    int tomadas = 0;
    int omitidas = 0;
    int notificadas = 0;
    int aplazadas = 0;

    final now = DateTime.now();
    final end = endDate.isBefore(now) ? endDate : now;

    // 1. Recopilar dosis registradas explícitamente en doseStatus dentro del rango [startDate, endDate]
    final List<DateTime> recordedTimes = [];
    tratamiento.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null &&
          !parsedTime.isBefore(startDate) &&
          !parsedTime.isAfter(endDate)) {
        recordedTimes.add(parsedTime);
        switch (status) {
          case DoseStatus.tomada:
            tomadas++;
            break;
          case DoseStatus.omitida:
            omitidas++;
            break;
          case DoseStatus.notificada:
            notificadas++;
            break;
          case DoseStatus.aplazada:
            aplazadas++;
            break;
          case DoseStatus.pendiente:
            omitidas++;
            break;
        }
      }
    });

    // 2. Generar dosis programadas en el rango [startDate, endDate] y verificar las ya pasadas con tolerancia
    final todasLasDosis = TratamientoService.generarDosisEnRango(
      tratamiento,
      startDate,
      endDate,
    );
    final intervaloMinutos =
        tratamiento.intervaloDosis.inMinutes > 0
            ? tratamiento.intervaloDosis.inMinutes
            : 240;
    final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);

    for (final doseTime in todasLasDosis) {
      if (!doseTime.isBefore(startDate) &&
          !doseTime.isAfter(end) &&
          doseTime.isBefore(now)) {
        bool isRecorded = false;
        for (final rec in recordedTimes) {
          if (rec.difference(doseTime).inMinutes.abs() <= maxToleranceMinutes) {
            isRecorded = true;
            break;
          }
        }
        if (!isRecorded) {
          omitidas++;
        }
      }
    }

    final int programadasPasadas = tomadas + omitidas + notificadas + aplazadas;

    return {
      'tomadas': tomadas,
      'omitidas': omitidas,
      'notificadas': notificadas,
      'aplazadas': aplazadas,
      'programadasPasadas': programadasPasadas,
    };
  }

  /// Gets recent dose history entries
  List<Map<String, dynamic>> _getRecentHistory(
    List<Tratamiento> tratamientos, [
    DateTime? startDate,
  ]) {
    final List<Map<String, dynamic>> history = [];
    final now = DateTime.now();
    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.tryParse(dateString);
        if (doseTime != null &&
            (startDate == null || !doseTime.isBefore(startDate)) &&
            doseTime.isBefore(now) &&
            (status == DoseStatus.tomada ||
                status == DoseStatus.omitida ||
                status == DoseStatus.notificada)) {
          history.add({'treatment': t, 'time': doseTime, 'status': status});
        }
      });
    }
    history.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );
    return history.take(4).toList();
  }

  /// Analyzes omission patterns by time of day
  Map<String, String> _analyzeOmissionsPattern(
    List<Tratamiento> tratamientos,
    int totalOmitidas,
    DateTime startDate,
    String periodLabel,
  ) {
    if (totalOmitidas == 0) {
      return {
        'icon': '🎉',
        'title': '¡Gran constancia!',
        'subtitle':
            'No presentas omisiones registradas en el período evaluado.',
      };
    }

    int morningOmissions = 0;
    int afternoonOmissions = 0;
    int nightOmissions = 0;
    int earlyOmissions = 0;

    final now = DateTime.now();

    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(dateString);
          if (doseTime != null &&
              !doseTime.isBefore(startDate) &&
              doseTime.isBefore(now)) {
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

    final maxVal = [
      morningOmissions,
      afternoonOmissions,
      nightOmissions,
      earlyOmissions,
    ].reduce((a, b) => a > b ? a : b);

    if (maxVal > 0) {
      if (maxVal == morningOmissions) {
        return {
          'icon': '🌅',
          'title': 'Mayor omisión: Mañana',
          'subtitle': 'Tip: Deja tu pastillero cerca del desayuno.',
        };
      } else if (maxVal == afternoonOmissions) {
        return {
          'icon': '☀️',
          'title': 'Mayor omisión: Tarde',
          'subtitle': 'Tip: Activa recordatorios extra en ese horario.',
        };
      } else if (maxVal == nightOmissions) {
        return {
          'icon': '🌙',
          'title': 'Mayor omisión: Noche',
          'subtitle': 'Tip: Alarma 15 min antes de dormir.',
        };
      } else {
        return {
          'icon': '🌃',
          'title': 'Mayor omisión: Madrugada',
          'subtitle': 'Tip: Ajusta horarios para no interrumpir el sueño.',
        };
      }
    }

    return {
      'icon': '💡',
      'title': 'Oportunidad de mejora',
      'subtitle':
          'Registras $totalOmitidas dosis pendientes o no confirmadas en este período.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Text('Inicia sesión para ver tu progreso.'),
      );
    }

    return StreamBuilder<List<Tratamiento>>(
      stream: firestoreService.getMedicamentosStream(
        user.uid,
        getActiveCaregiverProfile(context),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final allTreatments = snapshot.data ?? [];
        final tratamientos =
            allTreatments.where((t) => t.isActivo || !t.isFinalizado).toList();

        if (tratamientos.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Text(
              'Aún no tienes medicamentos activos registrados para calcular tu progreso de adherencia.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }

        // Calculate global stats
        final periodConfig = _resolvePeriodConfig();
        final startDate = periodConfig.startDate;
        final endDate = periodConfig.endDate;
        final periodLabel = periodConfig.label;
        final targetInterval = periodConfig.targetInterval;

        int totalTomadas = 0;
        int totalOmitidas = 0;
        int totalNotificadas = 0;
        int totalProgramadas = 0;

        final List<Map<String, dynamic>> perTreatmentStats = [];

        for (var t in tratamientos) {
          final stats = _calcularEstadisticas(t, startDate, endDate);
          totalTomadas += stats['tomadas']!;
          totalOmitidas += stats['omitidas']!;
          totalNotificadas += stats['notificadas']!;
          totalProgramadas += stats['programadasPasadas']!;
          perTreatmentStats.add({'treatment': t, 'stats': stats});
        }

        final double overallAdherence =
            totalProgramadas > 0
                ? (totalTomadas / totalProgramadas) * 100
                : 0.0;

        final recentHistory = _getRecentHistory(tratamientos, startDate);
        final omissionsInfo = _analyzeOmissionsPattern(
          tratamientos,
          totalOmitidas,
          startDate,
          periodLabel,
        );

        final bool isGoodAdherence = overallAdherence >= 80;

        void navigateToReportes() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportesPage(initialInterval: targetInterval),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: navigateToReportes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 1. HEADER: Overall Adherence ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reporte de Adherencia',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                periodLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isGoodAdherence
                                    ? AppTheme.successColor.withValues(
                                      alpha: 0.12,
                                    )
                                    : AppTheme.errorColor.withValues(
                                      alpha: 0.12,
                                    ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isGoodAdherence ? '✓ Buena' : '⚠ Mejorable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  isGoodAdherence
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── 2. CIRCULAR PROGRESS + LEGEND ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Circular progress
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  value: overallAdherence / 100,
                                  strokeWidth: 8,
                                  backgroundColor: AppTheme.borderColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    overallAdherence >= 80
                                        ? AppTheme.successColor
                                        : overallAdherence >= 50
                                        ? Colors.orange
                                        : AppTheme.errorColor,
                                  ),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Text(
                                '${overallAdherence.toInt()}%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Legend
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem(
                                AppTheme.successColor,
                                'Tomadas',
                                totalTomadas,
                              ),
                              const SizedBox(height: 6),
                              _buildLegendItem(
                                AppTheme.errorColor,
                                'Omitidas',
                                totalOmitidas,
                              ),
                              const SizedBox(height: 6),
                              _buildLegendItem(
                                Colors.amber,
                                'Notificadas',
                                totalNotificadas,
                              ),
                              const SizedBox(height: 6),
                              _buildLegendItem(
                                AppTheme.primaryColor,
                                'Programadas',
                                totalProgramadas,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── 3. QUICK STATS ROW ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.check_circle_outline,
                          color: AppTheme.successColor,
                          value: totalTomadas.toString(),
                          label: 'Tomadas',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildStatChip(
                          icon: Icons.cancel_outlined,
                          color: AppTheme.errorColor,
                          value: totalOmitidas.toString(),
                          label: 'Omitidas',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildStatChip(
                          icon: Icons.notifications_outlined,
                          color: Colors.amber[700]!,
                          value: totalNotificadas.toString(),
                          label: 'Notificadas',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildStatChip(
                          icon: Icons.percent,
                          color: AppTheme.primaryColor,
                          value: '${overallAdherence.toInt()}%',
                          label: 'Total',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: AppTheme.borderColor,
                    indent: 16,
                    endIndent: 16,
                  ),
                  const SizedBox(height: 14),

                  // ─── 4. PER-TREATMENT BREAKDOWN ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text(
                      'Desglose por tratamiento',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...perTreatmentStats.map((entry) {
                    final t = entry['treatment'] as Tratamiento;
                    final stats = entry['stats'] as Map<String, int>;
                    final tomadas = stats['tomadas']!;
                    final omitidas = stats['omitidas']!;
                    final notificadas = stats['notificadas']!;
                    final programadas = stats['programadasPasadas']!;
                    final double adherence =
                        programadas > 0 ? (tomadas / programadas) * 100 : 100.0;

                    final Color color =
                        adherence >= 80
                            ? AppTheme.successColor
                            : adherence >= 50
                            ? Colors.orange
                            : AppTheme.errorColor;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  t.nombreMedicamento,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${adherence.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Segmented bar: tomadas | omitidas | notificadas | remaining
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              height: 8,
                              child:
                                  programadas > 0
                                      ? Row(
                                        children: [
                                          if (tomadas > 0)
                                            Expanded(
                                              flex: tomadas,
                                              child: Container(
                                                color: AppTheme.successColor,
                                              ),
                                            ),
                                          if (omitidas > 0)
                                            Expanded(
                                              flex: omitidas,
                                              child: Container(
                                                color: AppTheme.errorColor,
                                              ),
                                            ),
                                          if (notificadas > 0)
                                            Expanded(
                                              flex: notificadas,
                                              child: Container(
                                                color: Colors.amber,
                                              ),
                                            ),
                                          if (programadas -
                                                  tomadas -
                                                  omitidas -
                                                  notificadas >
                                              0)
                                            Expanded(
                                              flex:
                                                  programadas -
                                                  tomadas -
                                                  omitidas -
                                                  notificadas,
                                              child: Container(
                                                color: AppTheme.borderColor,
                                              ),
                                            ),
                                        ],
                                      )
                                      : Container(color: AppTheme.borderColor),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tomadas $tomadas · Omitidas $omitidas · Notif. $notificadas',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // ─── 5. RECENT HISTORY ───
                  if (recentHistory.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      color: AppTheme.borderColor,
                      indent: 16,
                      endIndent: 16,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text(
                        'Historial reciente',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...recentHistory.map((item) {
                      final date = item['time'] as DateTime;
                      final status = item['status'] as DoseStatus;
                      final t = item['treatment'] as Tratamiento;

                      Color statusColor;
                      IconData statusIcon;
                      String statusText;

                      switch (status) {
                        case DoseStatus.tomada:
                          statusColor = AppTheme.successColor;
                          statusIcon = Icons.check_circle_rounded;
                          statusText = 'Tomada';
                          break;
                        case DoseStatus.omitida:
                          statusColor = AppTheme.errorColor;
                          statusIcon = Icons.cancel_rounded;
                          statusText = 'Omitida';
                          break;
                        case DoseStatus.notificada:
                          statusColor = Colors.amber;
                          statusIcon = Icons.notifications_rounded;
                          statusText = 'Notificada';
                          break;
                        default:
                          statusColor = Colors.grey;
                          statusIcon = Icons.hourglass_empty;
                          statusText = 'Pendiente';
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.nombreMedicamento,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DateFormat('dd MMM, hh:mm a').format(date),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // ─── 6. OMISSION PATTERN INSIGHT ───
                  const SizedBox(height: 4),
                  Divider(
                    height: 1,
                    color: AppTheme.borderColor,
                    indent: 16,
                    endIndent: 16,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                                : AppTheme.primaryColor.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            omissionsInfo['icon']!,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  omissionsInfo['title']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  omissionsInfo['subtitle']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── 7. SUGGESTION BANNER ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isGoodAdherence
                                ? (isDark
                                    ? const Color(0xFF0F2918)
                                    : const Color(0xFFF0FDF4))
                                : (isDark
                                    ? const Color(0xFF1E1A12)
                                    : const Color(0xFFFFFBEB)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isGoodAdherence
                                  ? (isDark
                                      ? const Color(0xFF1A4028)
                                      : const Color(0xFFBBF7D0))
                                  : (isDark
                                      ? const Color(0xFF3E3018)
                                      : const Color(0xFFFDE68A)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGoodAdherence
                                ? Icons.emoji_events_rounded
                                : Icons.lightbulb_outline,
                            color:
                                isGoodAdherence
                                    ? AppTheme.successColor
                                    : const Color(0xFFF59E0B),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isGoodAdherence
                                  ? '¡Excelente trabajo! Mantén esta constancia con tus medicamentos.'
                                  : 'Tu adherencia puede mejorar. Intenta activar recordatorios 15 min antes de cada dosis.',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    isGoodAdherence
                                        ? (isDark
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFF166534))
                                        : (isDark
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFF92400E)),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── 8. TAP FOOTER HINT ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                      border: Border(
                        top: BorderSide(color: AppTheme.borderColor),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Toca para ver el reporte completo y tendencias',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, int value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
