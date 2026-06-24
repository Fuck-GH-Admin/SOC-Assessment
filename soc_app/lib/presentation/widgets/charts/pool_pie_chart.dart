import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

const _poolLabels = ['0-20cm', '20-30cm', '30-40cm', '40-50cm', '50-60cm'];

const _poolColors = [
  Color(0xFF4A9EFF),
  Color(0xFF00D9A5),
  Color(0xFFFFC107),
  Color(0xFFE94560),
  Color(0xFF9C27B0),
];

class PoolPieChart extends StatelessWidget {
  final String fert;
  final int erosion;

  const PoolPieChart({
    super.key,
    required this.fert,
    required this.erosion,
  });

  @override
  Widget build(BuildContext context) {
    final depths = [10, 25, 35, 45, 55];
    final vals = depths
        .map((d) => lookupBaseSOC(fert, erosion, d) ?? 0.0)
        .toList();
    final total = vals.fold(0.0, (a, b) => a + b);
    final percentages = vals
        .map((v) => double.parse(((v / total) * 100).toStringAsFixed(1)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('各土层碳库组成比例',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: percentages
                        .asMap()
                        .entries
                        .map((e) => PieChartSectionData(
                              value: e.value,
                              color: _poolColors[e.key],
                              title: '${e.value}%',
                              titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              radius: 50,
                            ))
                        .toList(),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _poolLabels
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: _poolColors[e.key],
                              ),
                              const SizedBox(width: 6),
                              Text(_poolLabels[e.key],
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
