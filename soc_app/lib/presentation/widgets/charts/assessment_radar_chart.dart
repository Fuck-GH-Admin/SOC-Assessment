import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/models/calculation_result.dart';

double _normalize(double value, double min, double max) {
  final n = ((value - min) / (max - min)) * 100;
  return n.clamp(0, 100);
}

class AssessmentRadarChart extends StatelessWidget {
  final CalculationResult result;

  const AssessmentRadarChart({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final data = [
      _normalize(result.soc, 0, 25),
      _normalize(result.carbonStorage, 0, 10),
      _normalize(result.carbonDensity, 0, 50),
      _normalize(result.recoveryRate, 0, 1),
      _normalize(result.netChange, -5, 5),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('土壤碳库多维度综合评估',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                RadarDataSet(
                  fillColor: const Color(0xFF4A9EFF).withValues(alpha: 0.2),
                  borderColor: const Color(0xFF4A9EFF),
                  entryRadius: 3,
                  dataEntries: data
                      .map((v) => RadarEntry(value: v))
                      .toList(),
                ),
              ],
              tickCount: 5,
              titleTextStyle:
                  const TextStyle(fontSize: 11, color: Colors.black87),
              titlePositionPercentageOffset: 0.15,
              getTitle: (idx, _) {
                const labels = [
                  'SOC含量',
                  '碳库储量',
                  '碳密度',
                  '年恢复速率',
                  '碳库净变化'
                ];
                return RadarChartTitle(text: labels[idx]);
              },
            ),
          ),
        ),
      ],
    );
  }
}
