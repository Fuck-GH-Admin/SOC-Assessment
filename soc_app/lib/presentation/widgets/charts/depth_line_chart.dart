import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

const _depthLabels = ['表层', '亚表层', '中层', '深层', '底层'];

class DepthLineChart extends StatelessWidget {
  final String fert;
  final int erosion;

  const DepthLineChart({
    super.key,
    required this.fert,
    required this.erosion,
  });

  @override
  Widget build(BuildContext context) {
    final depths = [0, 1, 2, 3, 4];
    final depthsMap = {10: 0, 25: 1, 35: 2, 45: 3, 55: 4};

    final socValues = depths.map((i) {
      for (final e in depthsMap.entries) {
        final v = lookupBaseSOC(fert, erosion, e.key);
        if (e.value == i && v != null) return v;
      }
      return 0.0;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SOC含量的垂直分布特征',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: socValues
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList(),
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: const Color(0xFF00D9A5),
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, a2, a3, a4) =>
                        FlDotCirclePainter(
                      color: const Color(0xFF00D9A5),
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF00D9A5).withValues(alpha: 0.1),
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
