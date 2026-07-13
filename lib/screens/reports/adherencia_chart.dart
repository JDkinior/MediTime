import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

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

  const WeeklyComplianceChart({
    super.key,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    // Asegurarse de tener exactamente 7 valores
    final chartValues = values.length == 7 ? values : List.filled(7, 0.0);
    
    // Obtener el día actual de la semana (1 = Lunes, 7 = Domingo)
    final int currentDayOfWeek = DateTime.now().weekday;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.primaryColor,
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
                final style = TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                );
                String text = '';
                switch (value.toInt()) {
                  case 0: text = 'L'; break;
                  case 1: text = 'M'; break;
                  case 2: text = 'M'; break;
                  case 3: text = 'J'; break;
                  case 4: text = 'V'; break;
                  case 5: text = 'S'; break;
                  case 6: text = 'D'; break;
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8,
                  child: Text(text, style: style),
                );
              },
              reservedSize: 28,
            ),
          ),
        ),
        barGroups: List.generate(7, (index) {
          final val = chartValues[index];
          // El color principal se aplica al día actual de la semana
          final isToday = (index + 1) == currentDayOfWeek;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: val,
                // Color corporativo clínico para hoy, o un tono azul claro pastel para otros días
                color: isToday 
                    ? AppTheme.primaryColor 
                    : const Color(0xFFB4C6FF),
                width: 14,
                borderRadius: BorderRadius.circular(10), // Totalmente redondeado/cápsula
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: const Color(0xFFEFF4FF).withOpacity(0.5),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}