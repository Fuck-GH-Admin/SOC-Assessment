import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TimeLineChart extends StatelessWidget {
  final String fert;

  const TimeLineChart({super.key, required this.fert});

  @override
  Widget build(BuildContext context) {
    final fData = fert == 'F'
        ? [23.9, 21.5, 19.2, 17.8, 16.6]
        : [23.9, 22.1, 20.5, 19.1, 17.7];
    final unfData = fert == 'F'
        ? [23.9, 22.1, 20.5, 19.1, 17.7]
        : [23.9, 21.5, 19.2, 17.8, 16.6];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SOC含量随时间变化趋势',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: fData
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: const Color(0xFF4A9EFF),
                  barWidth: 2,
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF4A9EFF).withValues(alpha: 0.1),
                  ),
                ),
                LineChartBarData(
                  spots: unfData
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: const Color(0xFFE94560),
                  barWidth: 2,
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFFE94560).withValues(alpha: 0.1),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      const labels = ['0年', '5年', '10年', '15年', '20年'];
                      final idx = v.toInt();
                      if (idx < 0 || idx >= labels.length) {
                        return const Text('');
                      }
                      return Text(labels[idx],
                          style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
            ),
          ),
        ),
      ],
    );
  }
}
