import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/soil_layer.dart';

void main() {
  group('validateInput', () {
    test('returns empty list for valid params', () {
      final params = CalculationParams(
        bd: 1.3, ph: 6.5, wc: 25.0, clay: 30.0, tn: 1.5,
        cropBiomass: 8500, strawCarbonRatio: 0.45,
      );
      expect(validateInput(params), isEmpty);
    });

    test('catches out-of-range BD', () {
      final params = CalculationParams(bd: 3.0, ph: 7, wc: 50, clay: 30, tn: 1);
      final errors = validateInput(params);
      expect(errors, contains(contains('容重')));
    });

    test('catches out-of-range pH', () {
      final params = CalculationParams(bd: 1.3, ph: 12, wc: 50, clay: 30, tn: 1);
      final errors = validateInput(params);
      expect(errors, contains(contains('pH')));
    });

    test('catches negative cropBiomass', () {
      final params = CalculationParams(
        bd: 1.3, ph: 7, wc: 50, clay: 30, tn: 1, cropBiomass: -1,
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('不能为负')));
    });

    test('validates soil layers', () {
      final params = CalculationParams(
        bd: 1.3, ph: 7, wc: 50, clay: 30, tn: 1,
        soilLayers: [
          SoilLayer(layerId: '0-20', bd: 3.0, socValue: 15, thickness: 20),
        ],
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('容重')));
    });
  });

  group('lookupBaseSOC', () {
    test('returns correct value for F/0/10', () {
      expect(lookupBaseSOC('F', 0, 10), closeTo(23.90, 0.01));
    });

    test('returns correct value for UNF/30/35', () {
      expect(lookupBaseSOC('UNF', 30, 35), closeTo(10.54, 0.01));
    });

    test('returns null for unknown combination', () {
      expect(lookupBaseSOC('X', 0, 10), isNull);
    });
  });

  group('calculateSOC', () {
    test('returns positive value for F/0/10', () {
      final params = CalculationParams(fert: 'F', erosion: 0, depth: 10, bd: 1.3);
      expect(calculateSOC(params), closeTo(23.9, 0.1));
    });

    test('erosion reduces SOC', () {
      final p0 = CalculationParams(fert: 'F', erosion: 0, depth: 10, bd: 1.3);
      final p70 = CalculationParams(fert: 'F', erosion: 70, depth: 10, bd: 1.3);
      expect(calculateSOC(p70), lessThan(calculateSOC(p0)));
    });

    test('UNF produces lower SOC than F', () {
      final pF = CalculationParams(fert: 'F', erosion: 0, depth: 10, bd: 1.3);
      final pUnf = CalculationParams(fert: 'UNF', erosion: 0, depth: 10, bd: 1.3);
      expect(calculateSOC(pUnf), lessThan(calculateSOC(pF)));
    });
  });

  group('calculateCarbonStorage', () {
    test('computes correctly for 20cm depth', () {
      final result = calculateCarbonStorage(20, 1.3, 20);
      expect(result, closeTo(5.2, 0.01));
    });

    test('caps at 20cm for deeper profiles', () {
      final shallow = calculateCarbonStorage(20, 1.3, 20);
      final deeper = calculateCarbonStorage(20, 1.3, 40);
      expect(deeper, equals(shallow));
    });

    test('returns 0 for zero SOC', () {
      expect(calculateCarbonStorage(0, 1.3, 20), equals(0.0));
    });
  });

  group('calculateCarbonDensity', () {
    test('computes correctly', () {
      final result = calculateCarbonDensity(5.2, 20);
      expect(result, closeTo(26.0, 0.01));
    });

    test('returns 0 for zero depth', () {
      expect(calculateCarbonDensity(5.2, 0), equals(0.0));
    });
  });

  group('computeAll', () {
    test('returns error for invalid input', () {
      final params = CalculationParams(bd: 3.0, ph: 7, wc: 50, clay: 30, tn: 1);
      final result = computeAll(params);
      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('produces valid results for standard params', () {
      final params = CalculationParams(
        fert: 'F', erosion: 0, depth: 10, bd: 1.3,
        ph: 6.5, wc: 25, clay: 30, tn: 1.5,
        cropBiomass: 8500, strawCarbonRatio: 0.45,
      );
      final result = computeAll(params);
      expect(result.success, isTrue);
      expect(result.result, isNotNull);
      expect(result.result!.soc, greaterThan(0));
      expect(result.result!.carbonStorage, greaterThan(0));
      expect(result.result!.carbonDensity, greaterThan(0));
      expect(result.errors, isEmpty);
    });

    test('stable golden dataset: F/0/10/bd1.3', () {
      final params = CalculationParams(
        fert: 'F', erosion: 0, depth: 10, bd: 1.3,
        ph: 6.5, wc: 25, clay: 30, tn: 1.5,
        cropBiomass: 8500, strawCarbonRatio: 0.45,
      );
      final result = computeAll(params);
      expect(result.result!.soc, closeTo(23.9, 1e-6));
      expect(result.result!.carbonStorage, closeTo(3.11, 1e-6));
      expect(result.result!.carbonDensity, closeTo(31.07, 1e-6));
      expect(result.result!.netChange, closeTo(25.09, 1e-6));
      expect(result.result!.recoveryRate, closeTo(1.255, 1e-6));
      expect(result.result!.lossRate, closeTo(0.0, 1e-6));
    });

    test('stable golden dataset: UNF/30/35/bd1.5', () {
      final params = CalculationParams(
        fert: 'UNF', erosion: 30, depth: 35, bd: 1.5,
        ph: 6.5, wc: 25, clay: 30, tn: 1.5,
        cropBiomass: 8500, strawCarbonRatio: 0.45,
      );
      final result = computeAll(params);
      expect(result.result!.soc, closeTo(9.7, 1e-6));
      expect(result.result!.carbonStorage, closeTo(2.91, 1e-6));
      expect(result.result!.carbonDensity, closeTo(8.31, 1e-6));
      expect(result.result!.netChange, closeTo(8.26, 1e-6));
      expect(result.result!.recoveryRate, closeTo(0.413, 1e-6));
      expect(result.result!.lossRate, closeTo(59.4, 1e-6));
    });
  });
}
