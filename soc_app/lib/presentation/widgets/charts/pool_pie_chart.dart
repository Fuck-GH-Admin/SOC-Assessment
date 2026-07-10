import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:soc_app/domain/engine/resilience_assessment.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

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
  final double bd;

  const PoolPieChart({
    super.key,
    required this.fert,
    required this.erosion,
    required this.bd,
  });

  @override
  Widget build(BuildContext context) {
    final layers = buildProfileLayers(fert, erosion, bd);
    final pools = layers
        .map((l) => computeCarbonPoolByLayer(l.socValue, l.bd, l.thickness))
        .toList();
    final total = pools.fold(0.0, (a, b) => a + b);
    final percentages = total <= 0
        ? List<double>.filled(pools.length, 0)
        : pools
              .map((v) => double.parse(((v / total) * 100).toStringAsFixed(1)))
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '0-60cm分层碳库组成比例',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const Text('各层使用同一输入容重进行换算', style: TextStyle(fontSize: 10)),
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
                        .map(
                          (e) => PieChartSectionData(
                            value: e.value,
                            color: _poolColors[e.key],
                            title: '${e.value}%',
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            radius: 50,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: layers
                    .asMap()
                    .entries
                    .map(
                      (e) => Padding(
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
                            Text(
                              '${e.value.layerId}cm',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
