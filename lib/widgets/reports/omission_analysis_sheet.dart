import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
// lib/widgets/reports/omission_analysis_sheet.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';

/// Hoja modal con el análisis de patrones temporales de omisión de dosis.
class OmissionAnalysisSheet extends StatelessWidget {
  final List<Tratamiento> tratamientos;

  const OmissionAnalysisSheet({super.key, required this.tratamientos});

  static Future<void> show(
    BuildContext context,
    List<Tratamiento> tratamientos,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => OmissionAnalysisSheet(tratamientos: tratamientos),
    );
  }

  Widget _buildOmissionTimeBar(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              Text(
                '$count ($percentage%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? count / total : 0,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationText(
    int morning,
    int afternoon,
    int night,
    int early,
  ) {
    String mainPeriod = 'la mañana';
    int maxOmissions = morning;

    if (afternoon > maxOmissions) {
      mainPeriod = 'la tarde';
      maxOmissions = afternoon;
    }
    if (night > maxOmissions) {
      mainPeriod = 'la noche';
      maxOmissions = night;
    }
    if (early > maxOmissions) {
      mainPeriod = 'la madrugada';
      maxOmissions = early;
    }

    String recommendation = '';
    if (mainPeriod == 'la mañana') {
      recommendation =
          'La mayoría de tus omisiones ocurren por la mañana. Intenta vincular la toma de tus medicamentos con tu rutina de desayuno o coloca los medicamentos cerca de tu cafetera o cepillo de dientes.';
    } else if (mainPeriod == 'la tarde') {
      recommendation =
          'Sueles olvidar dosis durante la tarde, probablemente por actividades laborales o salidas. Configura alarmas audibles o lleva un pastillero de bolsillo contigo.';
    } else if (mainPeriod == 'la noche') {
      recommendation =
          'El horario nocturno concentra más olvidos. Vincula tu medicación con el momento de ir a la cama o activa el recordatorio inteligente antes de acostarte.';
    } else {
      recommendation =
          'Tienes omisiones en horario de madrugada. Si tu tratamiento no requiere tomas nocturnas estrictas, consulta con tu médico la posibilidad de ajustar los horarios para no interrumpir tu descanso.';
    }

    return Text(
      recommendation,
      style: TextStyle(
        fontSize: 13,
        color: AppTheme.secondaryTextColor,
        height: 1.6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int morningOmissions = 0;
    int afternoonOmissions = 0;
    int nightOmissions = 0;
    int earlyOmissions = 0;
    final Map<String, int> medicationOmissions = {};

    for (var t in tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(dateString);
          if (doseTime == null) return;
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
          medicationOmissions[t.nombreMedicamento] =
              (medicationOmissions[t.nombreMedicamento] ?? 0) + 1;
        }
      });
    }

    final totalOmissions =
        morningOmissions + afternoonOmissions + nightOmissions + earlyOmissions;
    final sortedMedications =
        medicationOmissions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    PreferenceNotifier? pref;
    try {
      pref = context.watch<PreferenceNotifier>();
    } catch (_) {}
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isModern = pref?.interfaceStyle == 'modern' || pref == null;
    final highContrast = pref?.highContrast ?? false;
    final useGlass = isModern && !highContrast;

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder:
          (ctx, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            child: BackdropFilter(
              filter: useGlass
                  ? ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0)
                  : ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
              child: Container(
                decoration: BoxDecoration(
                  color: useGlass
                      ? (isDark
                          ? Theme.of(context).cardColor.withValues(alpha: 0.78)
                          : Colors.white.withValues(alpha: 0.85))
                      : Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: useGlass
                        ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.12 : 0.08)
                        : ((pref?.showCardBorder ?? false) || highContrast ? AppTheme.borderColor : Colors.transparent),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Análisis de omisiones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Patrones y momentos críticos detectados',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribución por franja horaria',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildOmissionTimeBar(
                        'Mañana (6:00 - 12:00)',
                        morningOmissions,
                        totalOmissions,
                        const Color(0xFFFFB703),
                      ),
                      _buildOmissionTimeBar(
                        'Tarde (12:00 - 18:00)',
                        afternoonOmissions,
                        totalOmissions,
                        Colors.orange,
                      ),
                      _buildOmissionTimeBar(
                        'Noche (18:00 - 24:00)',
                        nightOmissions,
                        totalOmissions,
                        AppTheme.errorColor,
                      ),
                      _buildOmissionTimeBar(
                        'Madrugada (0:00 - 6:00)',
                        earlyOmissions,
                        totalOmissions,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
                if (sortedMedications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medicamentos más omitidos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...sortedMedications.take(5).map((entry) {
                          final pct =
                              totalOmissions > 0
                                  ? (entry.value / totalOmissions * 100).round()
                                  : 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryTextColor,
                                  ),
                                ),
                                Text(
                                  '${entry.value} veces ($pct%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recomendación personalizada',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildRecommendationText(
                        morningOmissions,
                        afternoonOmissions,
                        nightOmissions,
                        earlyOmissions,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
