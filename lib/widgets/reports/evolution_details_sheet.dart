import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
// lib/widgets/reports/evolution_details_sheet.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';

/// Hoja modal deslizable con el análisis detallado de la evolución de adherencia.
class EvolutionDetailsSheet extends StatelessWidget {
  final List<Tratamiento> tratamientos;
  final Map<String, dynamic> evolutionData;
  final String intervalName;

  const EvolutionDetailsSheet({
    super.key,
    required this.tratamientos,
    required this.evolutionData,
    required this.intervalName,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Tratamiento> tratamientos,
    required Map<String, dynamic> evolutionData,
    required String intervalName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder:
          (ctx) => EvolutionDetailsSheet(
            tratamientos: tratamientos,
            evolutionData: evolutionData,
            intervalName: intervalName,
          ),
    );
  }

  Widget _buildEvolutionKpiCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> details =
        (evolutionData['details'] as List<Map<String, dynamic>>?) ?? [];

    final validPoints =
        details.where((d) => (d['programadas'] as int) > 0).toList();
    double avgCompliance = 0;
    Map<String, dynamic>? bestPoint;
    Map<String, dynamic>? worstPoint;

    if (validPoints.isNotEmpty) {
      final totalComp = validPoints.fold<double>(
        0.0,
        (sum, d) => sum + (d['compliance'] as double),
      );
      avgCompliance = totalComp / validPoints.length;

      bestPoint = validPoints.reduce(
        (a, b) =>
            (a['compliance'] as double) >= (b['compliance'] as double) ? a : b,
      );
      worstPoint = validPoints.reduce(
        (a, b) =>
            (a['compliance'] as double) <= (b['compliance'] as double) ? a : b,
      );
    }

    PreferenceNotifier? pref;
    try {
      pref = context.watch<PreferenceNotifier>();
    } catch (_) {}
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isModern = pref?.interfaceStyle == 'modern' || pref == null;
    final highContrast = pref?.highContrast ?? false;
    final useGlass = isModern && !highContrast;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Evolución de adherencia",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Detalle de cumplimiento por periodo",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        intervalName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3 KPI Cards: Promedio, Mejor punto, Menor punto
                Row(
                  children: [
                    _buildEvolutionKpiCard(
                      title: "Promedio",
                      value:
                          validPoints.isNotEmpty
                              ? "${avgCompliance.round()}%"
                              : "0%",
                      icon: Icons.trending_up_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    _buildEvolutionKpiCard(
                      title: "Mayor",
                      value:
                          bestPoint != null
                              ? "${(bestPoint['compliance'] as double).round()}%"
                              : "-",
                      subtitle:
                          bestPoint != null
                              ? (bestPoint['label'] as String)
                              : null,
                      icon: Icons.star_rounded,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 10),
                    _buildEvolutionKpiCard(
                      title: "Menor",
                      value:
                          worstPoint != null
                              ? "${(worstPoint['compliance'] as double).round()}%"
                              : "-",
                      subtitle:
                          worstPoint != null
                              ? (worstPoint['label'] as String)
                              : null,
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  "Desglose por fecha / periodo",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),

                if (details.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "No hay datos registrados en este periodo.",
                        style: TextStyle(color: AppTheme.secondaryTextColor),
                      ),
                    ),
                  )
                else
                  ...details.map((item) {
                    final double comp = item['compliance'] as double;
                    final int tom = item['tomadas'] as int;
                    final int prog = item['programadas'] as int;
                    final int omi = item['omitidas'] as int;
                    final int notif = item['notificadas'] as int;
                    final int aplaz = item['aplazadas'] as int;
                    final String fullLabel = item['fullLabel'] as String;

                    Color barColor = AppTheme.primaryColor;
                    if (comp >= 80) {
                      barColor = AppTheme.successColor;
                    } else if (comp >= 50) {
                      barColor = Colors.orange;
                    } else if (prog > 0) {
                      barColor = AppTheme.errorColor;
                    } else {
                      barColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.borderColor.withValues(alpha: 0.6),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fullLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTextColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: barColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  prog > 0 ? "${comp.round()}%" : "Sin dosis",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: barColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  prog > 0 ? (comp / 100).clamp(0.0, 1.0) : 0.0,
                              backgroundColor: barColor.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                barColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                prog > 0
                                    ? "$tom de $prog dosis tomadas"
                                    : "0 dosis programadas",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (omi > 0 || notif > 0 || aplaz > 0)
                                Text(
                                  "${omi > 0 ? '$omi omitidas ' : ''}${notif > 0 ? '$notif notif. ' : ''}${aplaz > 0 ? '$aplaz aplaz.' : ''}",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
