import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/models/caregiver_profile.dart';

Color _parseColorHex(String hexString, {Color defaultColor = AppTheme.primaryColor}) {
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

class AdherenceBarChart extends StatelessWidget {
  final double tomadas;
  final double omitidas;

  const AdherenceBarChart({
    super.key,
    required this.tomadas,
    required this.omitidas,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (tomadas + omitidas) > 0 ? (tomadas + omitidas) * 1.2 : 10,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: getTitles,
              reservedSize: 38,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          makeGroupData(0, tomadas, barColor: kPrimaryColor),
          makeGroupData(1, omitidas, barColor: Colors.red.shade400),
        ],
      ),
    );
  }

  BarChartGroupData makeGroupData(int x, double y, {required Color barColor}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: barColor,
          width: 25,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget getTitles(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Colors.grey.shade600,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    switch (value.toInt()) {
      case 0:
        text = 'Tomadas';
        break;
      case 1:
        text = 'Omitidas';
        break;
      default:
        text = '';
        break;
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16,
      child: Text(text, style: style),
    );
  }
}

class WeeklyComplianceChart extends StatelessWidget {
  final List<double> values;
  final Color? barColor;
  final List<Map<CaregiverProfile, double>>? stackedValues;
  final List<String>? customLabels;

  const WeeklyComplianceChart({
    super.key,
    required this.values,
    this.barColor,
    this.stackedValues,
    this.customLabels,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStacked = stackedValues != null && stackedValues!.isNotEmpty;
    final int itemCount = isStacked
        ? stackedValues!.length
        : (values.isNotEmpty ? values.length : 7);

    final chartValues = values.length == itemCount ? values : List.filled(itemCount, 0.0);
    final int currentDayOfWeek = DateTime.now().weekday;
    final primaryBarColor = barColor ?? AppTheme.primaryColor;

    final defaultLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final labels = (customLabels != null && customLabels!.length == itemCount)
        ? customLabels!
        : (itemCount == 7 ? defaultLabels : List.generate(itemCount, (i) => '${i + 1}'));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => primaryBarColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}%',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < labels.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Text(
                      labels[idx],
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: itemCount > 7 ? 11 : 13,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
        ),
        barGroups: List.generate(itemCount, (index) {
          final isToday = itemCount == 7 && (index + 1) == currentDayOfWeek;
          final rodWidth = itemCount > 7 ? (itemCount > 10 ? 8.0 : 10.0) : 14.0;

          if (isStacked) {
            final dayMap = stackedValues![index];
            double accumulatedY = 0.0;
            final List<BarChartRodStackItem> rodStackItems = [];

            dayMap.forEach((profile, pct) {
              if (pct > 0) {
                final pColor = _parseColorHex(profile.colorHex);
                final fromY = accumulatedY;
                final toY = accumulatedY + pct;
                rodStackItems.add(BarChartRodStackItem(fromY, toY, pColor));
                accumulatedY = toY;
              }
            });

            final totalToY = accumulatedY.clamp(0.0, 100.0);

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: totalToY,
                  color: rodStackItems.isNotEmpty ? rodStackItems.first.color : primaryBarColor,
                  rodStackItems: rodStackItems,
                  width: rodWidth,
                  borderRadius: BorderRadius.circular(itemCount > 7 ? 4 : 10),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: const Color(0xFFEFF4FF).withOpacity(0.08),
                  ),
                ),
              ],
            );
          } else {
            final val = chartValues[index];
            final displayColor = isToday 
                ? primaryBarColor 
                : primaryBarColor.withOpacity(0.5);

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: displayColor,
                  width: rodWidth,
                  borderRadius: BorderRadius.circular(itemCount > 7 ? 4 : 10),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: const Color(0xFFEFF4FF).withOpacity(0.08),
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}