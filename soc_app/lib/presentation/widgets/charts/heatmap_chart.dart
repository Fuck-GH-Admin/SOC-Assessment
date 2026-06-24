import 'package:flutter/material.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';

Color _heatmapColor(double value, double min, double max) {
  if (max == min) return const Color.fromRGBO(74, 158, 255, 0.8);
  final t = (value - min) / (max - min);
  final r = (233 - t * 159).round().clamp(0, 255);
  final g = (69 + t * 116).round().clamp(0, 255);
  final b = (96 - t * 96).round().clamp(0, 255);
  return Color.fromRGBO(r, g, b, 0.85);
}

class HeatmapChart extends StatelessWidget {
  final String fert;

  const HeatmapChart({super.key, required this.fert});

  @override
  Widget build(BuildContext context) {
    const erosionLevels = [0, 10, 20, 30, 40, 50, 60, 70];
    const depthKeys = [10, 25, 35, 45, 55];
    const depthLabels = ['0-20cm', '20-30cm', '30-40cm', '40-50cm', '50-60cm'];

    final cells = <_HeatmapCell>[];
    for (final e in erosionLevels) {
      for (var di = 0; di < depthKeys.length; di++) {
        final v = lookupBaseSOC(fert, e, depthKeys[di]) ?? 0.0;
        cells.add(_HeatmapCell(e, di, v));
      }
    }
    final maxV = cells.map((c) => c.value).reduce((a, b) => a > b ? a : b);
    final minV = cells.map((c) => c.value).reduce((a, b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('侵蚀强度 × 土层深度 SOC分布热力图',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _HeatmapPainter(
              cells: cells,
              minValue: minV,
              maxValue: maxV,
              erosionLevels: erosionLevels,
              depthLabels: depthLabels,
            ),
            size: const Size(double.infinity, 200),
          ),
        ),
      ],
    );
  }
}

class _HeatmapCell {
  final int erosion;
  final int depthIdx;
  final double value;

  const _HeatmapCell(this.erosion, this.depthIdx, this.value);
}

class _HeatmapPainter extends CustomPainter {
  final List<_HeatmapCell> cells;
  final double minValue;
  final double maxValue;
  final List<int> erosionLevels;
  final List<String> depthLabels;

  _HeatmapPainter({
    required this.cells,
    required this.minValue,
    required this.maxValue,
    required this.erosionLevels,
    required this.depthLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / erosionLevels.length;
    final cellH = size.height / depthLabels.length;
    final labelPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final cell in cells) {
      final x = erosionLevels.indexOf(cell.erosion) * cellW;
      final y = cell.depthIdx * cellH;
      final color = _heatmapColor(cell.value, minValue, maxValue);

      final rect = Rect.fromLTWH(x, y, cellW, cellH);
      canvas.drawRect(rect, Paint()..color = color);

      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      labelPaint.text = TextSpan(
        text: '${(cell.value * 10).round() / 10}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(
          x + (cellW - labelPaint.width) / 2,
          y + (cellH - labelPaint.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => true;
}
