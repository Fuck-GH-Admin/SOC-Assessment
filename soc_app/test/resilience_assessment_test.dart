import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/domain/engine/resilience_assessment.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/soil_layer.dart';

void main() {
  group('computeCarbonPoolByLayer', () {
    test('computes correctly', () {
      final result = computeCarbonPoolByLayer(15, 1.3, 20);
      expect(result, closeTo(3.9, 0.01));
    });
  });

  group('computeTotalCarbonPool', () {
    test('sums over layers', () {
      final layers = [
        SoilLayer(layerId: '0-20', bd: 1.3, socValue: 15, thickness: 20),
        SoilLayer(layerId: '20-40', bd: 1.4, socValue: 10, thickness: 20),
      ];
      final result = computeTotalCarbonPool(layers);
      // (15*1.3*20)/100 + (10*1.4*20)/100 = 3.9 + 2.8 = 6.7
      expect(result, closeTo(6.7, 0.01));
    });

    test('returns 0 for empty list', () {
      expect(computeTotalCarbonPool([]), equals(0.0));
    });
  });

  group('assessResilience', () {
    test('returns error if no soilLayers', () {
      final params = CalculationParams();
      final result = assessResilience(params);
      expect(result.success, isFalse);
      expect(result.errors, contains('缺少土层数据'));
    });

    test('returns error if no initialLayers', () {
      final params = CalculationParams(
        soilLayers: [SoilLayer(layerId: '0-20', bd: 1.3, socValue: 15, thickness: 20)],
      );
      final result = assessResilience(params);
      expect(result.success, isFalse);
      expect(result.errors, contains('缺少初始年份土层数据'));
    });

    test('assesses resilience with valid layers', () {
      final params = CalculationParams(
        soilLayers: [
          SoilLayer(layerId: '0-20', bd: 1.3, socValue: 15, thickness: 20),
          SoilLayer(layerId: '20-60', bd: 1.4, socValue: 10, thickness: 40),
        ],
        initialLayers: [
          SoilLayer(layerId: '0-20', bd: 1.3, socValue: 12, thickness: 20),
          SoilLayer(layerId: '20-60', bd: 1.4, socValue: 8, thickness: 40),
        ],
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
        litterCarbonInput: 0.15,
      );
      final result = assessResilience(params);
      expect(result.success, isTrue);
      expect(result.result, isNotNull);
    });

    test('determines recovery status correctly for positive change', () {
      final params = CalculationParams(
        soilLayers: [
          SoilLayer(layerId: '0-20', bd: 1.3, socValue: 20, thickness: 20),
          SoilLayer(layerId: '20-60', bd: 1.4, socValue: 15, thickness: 40),
        ],
        initialLayers: [
          SoilLayer(layerId: '0-20', bd: 1.3, socValue: 10, thickness: 20),
          SoilLayer(layerId: '20-60', bd: 1.4, socValue: 8, thickness: 40),
        ],
      );
      final result = assessResilience(params);
      expect(result.result!.status, contains('恢复'));
    });
  });
}
