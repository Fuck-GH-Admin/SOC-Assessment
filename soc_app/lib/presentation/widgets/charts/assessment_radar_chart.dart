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
    final colorScheme = Theme.of(context).colorScheme;
    final dataColor = colorScheme.primary;
    final onSurface = colorScheme.onSurface;

    final data = [
      _normalize(result.soc, 0, 25),
      _normalize(result.carbonStorage, 0, 10),
      _normalize(result.carbonDensity, 0, 50),
      _normalize(result.lossRate, 0, 100),
      _normalize(result.netChange, -5, 5),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '土壤碳库指标相对尺度',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const Text(
          '各指标按固定展示区间归一化；部分指标由同一SOC数据推导，仅用于同屏观察，不代表综合评分。',
          style: TextStyle(fontSize: 10),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              radarBorderData: BorderSide(
                color: onSurface.withValues(alpha: 0.4),
                width: 1.0,
              ),
              gridBorderData: BorderSide(
                color: onSurface.withValues(alpha: 0.2),
                width: 0.8,
              ),
              tickBorderData: BorderSide(
                color: onSurface.withValues(alpha: 0.3),
                width: 0.8,
              ),
              dataSets: [
                RadarDataSet(
                  fillColor: dataColor.withValues(alpha: 0.2),
                  borderColor: dataColor,
                  entryRadius: 3,
                  dataEntries: data.map((v) => RadarEntry(value: v)).toList(),
                ),
              ],
              tickCount: 5,
              titleTextStyle: TextStyle(fontSize: 11, color: onSurface),
              titlePositionPercentageOffset: 0.15,
              getTitle: (idx, _) {
                const labels = ['SOC含量', '碳库储量', '碳密度', '相对CK损失', '相对CK差'];
                return RadarChartTitle(text: labels[idx]);
              },
            ),
          ),
        ),
      ],
    );
  }
}
