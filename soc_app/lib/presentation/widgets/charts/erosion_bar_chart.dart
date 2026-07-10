import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

class ErosionBarChart extends StatelessWidget {
  final String fert;
  final List<int> erosionLevels;

  const ErosionBarChart({
    super.key,
    required this.fert,
    this.erosionLevels = const [0, 10, 20, 30, 40, 50, 60, 70],
  });

  @override
  Widget build(BuildContext context) {
    final socValues = erosionLevels
        .map((e) => calculateSOCValue(fert, e, 10))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '不同侵蚀深度下的0-20cm SOC含量',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const Text(
          '纵轴：SOC (g/kg)；横轴：侵蚀深度 (cm)',
          style: TextStyle(fontSize: 10),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: socValues.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value,
                      color: const Color(0xFF4A9EFF),
                      width: 18,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                  ],
                );
              }).toList(),
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
                      if (idx < 0 || idx >= erosionLevels.length) {
                        return const Text('');
                      }
                      return Text(
                        '${erosionLevels[idx]}',
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
      ],
    );
  }
}
