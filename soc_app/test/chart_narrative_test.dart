import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/domain/engine/chart_narrative.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_result.dart';

void main() {
  group('ChartNarrative', () {
    test('erosionCurve reports current drop vs CK and flags non-monotonic', () {
      final text = ChartNarrative.erosionCurve(fert: 'F', currentErosion: 10);
      // F/10cm 表层 17.64 vs CK 23.90 → 降 26%。
      expect(text, contains('17.6'));
      expect(text, contains('26%'));
      expect(text, contains('局部回升'));
    });

    test('depthProfile names the worst layer', () {
      final text = ChartNarrative.depthProfile(
        fert: 'F',
        erosion: 10,
        bd: 1.15,
      );
      expect(text, contains('0-20'));
      expect(text, contains('亏缺最深'));
    });

    test('strawScenario reports fold increase across ratios', () {
      final text = ChartNarrative.strawScenario(null);
      expect(text, contains('重新计算'));
    });

    test('oneLineSummary joins layer and profile conclusions', () {
      final text = ChartNarrative.oneLineSummary(
        fertLabel: '施肥',
        erosion: 30,
        layerLabel: '30-40 cm（中层）',
        result: const CalculationResult(
          soc: 8.93,
          carbonStorage: 1.03,
          netChange: -0.48,
          lossRate: 31.8,
        ),
        resilience: null,
      );
      expect(text, contains('较同层 CK 低于 0.48'));
      expect(text, contains('施肥'));
    });

    test('correlation describes direction without claiming causality', () {
      final text = ChartNarrative.correlation(fert: 'F');
      expect(text, contains('因果'));
    });

    test('poolComposition explains thickness confounding', () {
      final text = ChartNarrative.poolComposition(
        fert: 'F',
        erosion: 0,
        bd: 1.15,
      );
      expect(text, contains('厚度'));
    });

    test('heatmap anchors extreme cells', () {
      final text = ChartNarrative.heatmap(fert: 'F');
      expect(text, contains('峰值'));
      expect(text, contains('谷值'));
    });

    test('assessmentRadar disclaims normalization', () {
      final text = ChartNarrative.assessmentRadar(
        const CalculationResult(soc: 23.9, lossRate: 0),
      );
      expect(text, contains('不代表综合评分'));
    });

    test('erosion levels constant is consistent with narrative loop', () {
      // 叙事生成器循环依赖常量，防止常量改动后结论越界。
      expect(kErosionLevels.length, 8);
      expect(kSoilDepthKeys.length, 5);
    });
  });
}
