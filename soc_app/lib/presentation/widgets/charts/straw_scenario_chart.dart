import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:soc_app/domain/engine/resilience_assessment.dart';

class StrawScenarioChart extends StatelessWidget {
  final double cropBiomass;
  final double strawCarbonRatio;
  final double litterCarbonInput;

  const StrawScenarioChart({
    super.key,
    required this.cropBiomass,
    required this.strawCarbonRatio,
    required this.litterCarbonInput,
  });

  @override
  Widget build(BuildContext context) {
    final scenarios = computeStrawScenarios(
      cropBiomass,
      strawCarbonRatio,
      litterCarbonInput,
    );
    final maxTotal = scenarios.fold<double>(
      0,
      (max, scenario) => scenario.totalInput > max ? scenario.totalInput : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '秸秆还田情景碳输入',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        const Text(
          '纵轴：碳输入 (kg C/m²)；柱体由基础凋落物与秸秆碳输入叠加',
          style: TextStyle(fontSize: 10),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: BarChart(
            BarChartData(
              maxY: maxTotal <= 0 ? 1 : maxTotal * 1.2,
              alignment: BarChartAlignment.spaceAround,
              barGroups: scenarios.asMap().entries.map((entry) {
                final scenario = entry.value;
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: scenario.totalInput,
                      width: 34,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      rodStackItems: [
                        BarChartRodStackItem(
                          0,
                          litterCarbonInput,
                          const Color(0xFF8D6E63),
                        ),
                        BarChartRodStackItem(
                          litterCarbonInput,
                          scenario.totalInput,
                          const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, _) => Text(
                      value.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= scenarios.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${(scenarios[index].returnRatio * 100).round()}%',
                        style: const TextStyle(fontSize: 10),
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
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: Color(0xFF8D6E63), label: '基础凋落物'),
            SizedBox(width: 18),
            _Legend(color: Color(0xFF2E7D32), label: '秸秆碳输入'),
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
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
