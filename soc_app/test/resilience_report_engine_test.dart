import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/domain/engine/resilience_report_engine.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/resilience_report.dart';

void main() {
  group('assessResilienceReport', () {
    test('F/0cm matches CK so no profile deficit', () {
      final report = assessResilienceReport('F', 0, 1.15);
      expect(report, isNotNull);
      // 侵蚀 0cm 即 CK 自身，剖面差应为 0。
      expect(report!.profileDeficit, closeTo(0, 1e-9));
      expect(report.annualizedDeficit, closeTo(0, 1e-9));
      expect(report.conclusionLevel, 'covering');
      // 每层相对 CK 差为 0，损失率 0。
      for (final layer in report.layers) {
        expect(layer.poolDifference, closeTo(0, 1e-9));
        expect(layer.lossRate, 0.0);
      }
    });

    test('F/10cm shows deficit concentrated in 0-20cm layer', () {
      final report = assessResilienceReport('F', 10, 1.15);
      expect(report, isNotNull);
      expect(report!.profileDeficit, lessThan(0));

      final surface = report.layers.firstWhere((l) => l.layerId == '0-20');
      // F/10cm 表层 SOC 17.64 vs CK 23.90，必有明显亏缺。
      expect(surface.poolDifference, lessThan(0));
      expect(surface.lossRate, greaterThan(0));

      // 薄弱层应为表层或亏缺最大层。
      final minDiff = report.layers
          .map((l) => l.poolDifference)
          .reduce((a, b) => a < b ? a : b);
      expect(
        report.layers.firstWhere((l) => l.layerId == report.weakestLayerId)
            .poolDifference,
        minDiff,
      );
    });

    test('annualized deficit uses divide-by-20 proxy convention', () {
      final report = assessResilienceReport('F', 30, 1.3);
      expect(report!.annualizedDeficit, closeTo(report.profileDeficit / 20, 1e-9));
    });

    test('erosion deficit matrix covers all 8 levels in ascending order', () {
      final report = assessResilienceReport('UNF', 20, 1.2);
      expect(report!.erosionDeficits, hasLength(kErosionLevels.length));
      final cmList = report.erosionDeficits.map((d) => d.erosionCm).toList();
      expect(cmList, [0, 10, 20, 30, 40, 50, 60, 70]);
      // 0cm 行亏缺为 0。
      expect(report.erosionDeficits.first.deficit, closeTo(0, 1e-9));
    });

    test('scenario coverage compares straw input against |annualized|', () {
      // 8500 kg/ha × 0.45 → 100% 档秸秆输入 0.3825 kg C/m²。
      final report = assessResilienceReport(
        'F',
        10,
        1.15,
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
        litterCarbonInput: 0.15,
      );
      expect(report!.scenarioCoverages, hasLength(3));
      final full = report.scenarioCoverages.last;
      expect(full.strawInput, closeTo(0.3825, 1e-9));
      // 亏缺量级：F/10cm 剖面差 = -1.351 kg C/m²，年化 ≈ -0.0676。
      expect(report.annualizedDeficit, lessThan(0));
      // 100% 档 0.3825 > 0.0676，可覆盖。
      expect(full.coverageMargin, greaterThan(0));
      expect(report.conclusionLevel, 'covering');
    });

    test('zero straw params yield deficit conclusion with guidance', () {
      final report = assessResilienceReport('F', 70, 1.4);
      expect(report!.conclusionLevel, 'deficit');
      expect(report.conclusionText, contains('秸秆生物量'));
    });

    test('round-trips through JSON without loss', () {
      final report = assessResilienceReport(
        'F',
        10,
        1.15,
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
        litterCarbonInput: 0.15,
      )!;
      final restored = ResilienceReport.fromJson(report.toJson());
      expect(restored.weakestLayerId, report.weakestLayerId);
      expect(restored.profileDeficit, report.profileDeficit);
      expect(restored.annualizedDeficit, report.annualizedDeficit);
      expect(restored.conclusionLevel, report.conclusionLevel);
      expect(restored.layers, hasLength(report.layers.length));
      expect(restored.erosionDeficits, hasLength(8));
      expect(restored.scenarioCoverages, hasLength(3));
    });
  });
}
