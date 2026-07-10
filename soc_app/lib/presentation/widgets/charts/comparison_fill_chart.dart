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
        .map((d) => calculateSOCValue(fert, erosion, d))
        .toList();
    final reference = depths.map((d) => calculateSOCValue(fert, 0, d)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '当前侵蚀 vs 无侵蚀 SOC分布对比',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const Text('纵轴：SOC (g/kg)；横轴：土层范围', style: TextStyle(fontSize: 10)),
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
                  isCurved: false,
                  color: const Color(0xFF4A9EFF).withValues(alpha: 0.9),
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: reference
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: false,
                  color: const Color(0xFF00D9A5).withValues(alpha: 0.9),
                  barWidth: 2,
                  dashArray: [5, 5],
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: const TextStyle(fontSize: 10),
                    ),
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
                      return Text(
                        _depthLabels[idx],
                        style: const TextStyle(fontSize: 9),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
            ),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: Color(0xFF4A9EFF), label: '当前侵蚀'),
            SizedBox(width: 18),
            _Legend(color: Color(0xFF00D9A5), label: '同施肥CK'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
