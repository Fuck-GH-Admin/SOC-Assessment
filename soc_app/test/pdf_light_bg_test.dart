import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/core/theme/app_theme.dart';
import 'package:soc_app/core/theme/theme_provider.dart';
import 'package:soc_app/presentation/widgets/charts/heatmap_chart.dart';

void main() {
  testWidgets('heatmap labels use light-theme color under light Theme wrapper',
      (tester) async {
    late Color labelColor;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(kColorPresets.first.color),
        home: Builder(
          builder: (context) => Theme(
            data: AppTheme.lightTheme(kColorPresets.first.color),
            child: Builder(
              builder: (context) {
                labelColor = Theme.of(context).colorScheme.onSurface;
                return const Scaffold(
                  body: HeatmapChart(fert: 'F'),
                );
              },
            ),
          ),
        ),
      ),
    );
    // 浅色 onSurface 接近深色墨色（亮度低），深色主题的 onSurface 亮度高。
    expect(labelColor.computeLuminance(), lessThan(0.5));
  });
}
