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