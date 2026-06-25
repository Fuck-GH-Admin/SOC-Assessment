import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/models/calculation_result.dart';

double _normalize(double value, double min, double max) {
  final n = ((value - min) / (max - min)) * 100;
  return n.clamp(0, 100);
}

class ComparisonRadarChart extends StatelessWidget {
  final CalculationResult result1;
  final CalculationResult result2;
  final String label1;
  final String label2;

  const ComparisonRadarChart({
    super.key,
    required this.result1,
    required this.result2,
    this.label1 = '当前',
    this.label2 = '对比',
  });

  List<double> _buildData(CalculationResult r) => [
        _normalize(r.soc, 0, 25),
        _normalize(r.carbonStorage, 0, 10),
        _normalize(r.carbonDensity, 0, 50),
        _normalize(r.recoveryRate, 0, 1),
        _normalize(r.netChange, -5, 5),
      ];

  @override
  Widget build(BuildContext context) {
    final data1 = _buildData(result1);
    final data2 = _buildData(result2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('土壤碳库多维度对比',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                RadarDataSet(
                  fillColor: const Color(0xFF4A9EFF).withValues(alpha: 0.15),
                  borderColor: const Color(0xFF4A9EFF),
                  borderWidth: 2,
                  entryRadius: 0,
                  dataEntries:
                      data1.map((v) => RadarEntry(value: v)).toList(),
                ),
                RadarDataSet(
                  fillColor: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  borderColor: const Color(0xFFFF6B6B),
                  borderWidth: 2,
                  entryRadius: 0,
                  dataEntries:
                      data2.map((v) => RadarEntry(value: v)).toList(),
                ),
              ],
              tickCount: 5,
              titleTextStyle:
                  TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
              titlePositionPercentageOffset: 0.25,
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
              radarTouchData: RadarTouchData(
                enabled: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(const Color(0xFF4A9EFF), label1),
            const SizedBox(width: 24),
            _legendItem(const Color(0xFFFF6B6B), label2),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
