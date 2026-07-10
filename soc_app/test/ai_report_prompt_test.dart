import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/data/ai_report_prompt.dart';

void main() {
  test(
    'default prompt clearly separates measured, auxiliary and scenario data',
    () {
      expect(defaultPrompt, contains('辅助观测参数'));
      expect(defaultPrompt, contains('未进入当前SOC查表与碳库换算公式'));
      expect(defaultPrompt, contains('秸秆情景参数'));
      expect(defaultPrompt, contains('不得表述为真实时间趋势'));
      expect(systemPrompt, contains('不得表述为真实时间序列预测'));
    },
  );

  test('fillPrompt replaces every supported placeholder', () {
    final filled = fillPrompt(defaultPrompt, {
      'algorithmVersion': 2,
      'fert': 'UNF',
      'erosion': 30,
      'depthLabel': '30-40 cm（中层）',
      'bd': 1.5,
      'ph': 6.5,
      'wc': 25,
      'clay': 30,
      'tn': 1.5,
      'cropBiomass': 8500,
      'strawCarbonRatio': 0.45,
      'litterCarbonInput': 0.15,
      'soc': 10.54,
      'carbonStorage': 1.58,
      'carbonDensity': 15.81,
      'layerPoolDifference': -0.67,
      'layerAnnualizedDifference': -0.034,
      'lossRate': 29.9,
      'carbonPool020': 3.2,
      'carbonPool060': 6.4,
      'netChange20yr': -1.2,
      'netChange100yr': -0.5,
      'recoveryRateAnnual': -0.06,
      'resilienceStatus': '低于CK',
      'strawScenarios': '30%秸秆还田',
    });

    expect(filled, contains('不施肥'));
    expect(filled, contains('30-40 cm（中层）'));
    expect(filled, contains('30%秸秆还田'));
    expect(filled, isNot(contains(r'${')));
  });
}
