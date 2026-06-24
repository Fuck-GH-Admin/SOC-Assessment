import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

class CorrelationScatterChart extends StatelessWidget {
  final String fert;

  const CorrelationScatterChart({super.key, required this.fert});

  @override
  Widget build(BuildContext context) {
    final erosionLevels = [0, 10, 20, 30, 40, 50, 60, 70];
    final spots = erosionLevels
        .map((e) => ScatterSpot(
              e.toDouble(),
              lookupBaseSOC(fert, e, 10) ?? 0,
              dotPainter: FlDotCirclePainter(
                radius: 8,
                color: const Color(0xFF4A9EFF).withValues(alpha: 0.8),
              ),
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('侵蚀强度与SOC含量关联分析',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: spots,
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
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(fontSize: 9)),
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
