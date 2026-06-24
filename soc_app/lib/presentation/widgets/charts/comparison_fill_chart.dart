import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

const _depthLabels = ['0-20cm', '20-30cm', '30-40cm', '40-50cm', '50-60cm'];

class ComparisonFillChart extends StatelessWidget {
  final String fert;
  final int erosion;

  const ComparisonFillChart({
    super.key,
    required this.fert,
    required this.erosion,
  });

  @override
  Widget build(BuildContext context) {
    final depths = [10, 25, 35, 45, 55];
    final eroded = depths
        .map((d) => lookupBaseSOC(fert, erosion, d) ?? 0.0)
        .toList();
    final reference = depths
        .map((d) => lookupBaseSOC(fert, 0, d) ?? 0.0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('当前侵蚀 vs 无侵蚀 SOC分布对比',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: eroded
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: const Color(0xFF4A9EFF).withValues(alpha: 0.9),
                  barWidth: 2,
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF4A9EFF).withValues(alpha: 0.8),
                  ),
                ),
                LineChartBarData(
                  spots: reference
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: const Color(0xFF00D9A5).withValues(alpha: 0.9),
                  barWidth: 2,
                  dashArray: [5, 5],
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF00D9A5).withValues(alpha: 0.3),
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
                      final idx = v.toInt();
                      if (idx < 0 || idx >= _depthLabels.length) {
                        return const Text('');
                      }
                      return Text(_depthLabels[idx],
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
