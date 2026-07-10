import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/soil_layer.dart';

void main() {
  group('validateInput', () {
    test('returns empty list for valid params', () {
      final params = CalculationParams(
        bd: 1.3,
        ph: 6.5,
        wc: 25.0,
        clay: 30.0,
        tn: 1.5,
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
      );
      expect(validateInput(params), isEmpty);
    });

    test('catches out-of-range BD', () {
      final params = CalculationParams(bd: 3.0, ph: 7, wc: 50, clay: 30, tn: 1);
      final errors = validateInput(params);
      expect(errors, contains(contains('容重')));
    });

    test('catches out-of-range pH', () {
      final params = CalculationParams(
        bd: 1.3,
        ph: 12,
        wc: 50,
        clay: 30,
        tn: 1,
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('pH')));
    });

    test('catches negative cropBiomass', () {
      final params = CalculationParams(
        bd: 1.3,
        ph: 7,
        wc: 50,
        clay: 30,
        tn: 1,
        cropBiomass: -1,
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('不能为负')));
    });

    test('validates soil layers', () {
      final params = CalculationParams(
        bd: 1.3,
        ph: 7,
        wc: 50,
        clay: 30,
        tn: 1,
        soilLayers: [
          SoilLayer(layerId: '0-20', bd: 3.0, socValue: 15, thickness: 20),
        ],
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('容重')));
    });

    test('rejects unknown categorical values and invalid litter input', () {
      final params = CalculationParams(
        fert: 'UNKNOWN',
        erosion: 15,
        depth: 20,
        litterCarbonInput: -0.1,
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('未知施肥处理')));
      expect(errors, contains(contains('侵蚀程度')));
      expect(errors, contains(contains('土层必须')));
      expect(errors, contains(contains('基础凋落物')));
    });

    test('validates CK reference layers as well as current layers', () {
      final params = CalculationParams(
        initialLayers: const [
          SoilLayer(layerId: '0-20', bd: 1.3, socValue: 101, thickness: 20),
        ],
      );
      expect(validateInput(params), contains(contains('参考第1层SOC')));
    });

    test('rejects NaN and infinity instead of letting them reach storage', () {
      final params = CalculationParams(
        bd: double.nan,
        cropBiomass: double.infinity,
        soilLayers: const [
          SoilLayer(
            layerId: '0-20',
            bd: 1.3,
            socValue: double.nan,
            thickness: 20,
          ),
        ],
      );
      final errors = validateInput(params);
      expect(errors, contains(contains('土壤容重必须为有限数值')));
      expect(errors, contains(contains('秸秆生物量必须为有限数值')));
      expect(errors, contains(contains('包含非有限数值')));
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
      final params = CalculationParams(
        fert: 'F',
        erosion: 0,
        depth: 10,
        bd: 1.3,
      );
      expect(calculateSOC(params), closeTo(23.9, 0.1));
    });

    test('erosion reduces SOC', () {
      final p0 = CalculationParams(fert: 'F', erosion: 0, depth: 10, bd: 1.3);
      final p70 = CalculationParams(fert: 'F', erosion: 70, depth: 10, bd: 1.3);
      expect(calculateSOC(p70), lessThan(calculateSOC(p0)));
    });

    test(
      'does not apply a second fertilizer factor to split source tables',
      () {
        final pF = CalculationParams(fert: 'F', erosion: 0, depth: 10, bd: 1.3);
        final pUnf = CalculationParams(
          fert: 'UNF',
          erosion: 0,
          depth: 10,
          bd: 1.3,
        );
        expect(calculateSOC(pUnf), equals(calculateSOC(pF)));
      },
    );

    test('throws instead of silently fabricating an unknown lookup value', () {
      expect(
        () => calculateSOCValue('F', 15, 10),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('calculateCarbonStorage', () {
    test('computes correctly for the 0-20cm layer key', () {
      final result = calculateCarbonStorage(20, 1.3, 10);
      expect(result, closeTo(5.2, 0.01));
    });

    test('uses the selected soil-layer thickness', () {
      final surface = calculateCarbonStorage(20, 1.3, 10);
      final middle = calculateCarbonStorage(20, 1.3, 35);
      expect(surface, closeTo(5.2, 0.01));
      expect(middle, closeTo(2.6, 0.01));
    });

    test('returns 0 for zero SOC', () {
      expect(calculateCarbonStorage(0, 1.3, 10), equals(0.0));
    });

    test('rejects values that are not defined soil-layer keys', () {
      expect(
        () => calculateCarbonStorage(20, 1.3, 20),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('calculateCarbonDensity', () {
    test('computes correctly', () {
      final result = calculateCarbonDensity(5.2, 10);
      expect(result, closeTo(26.0, 0.01));
    });

    test('rejects an unknown soil-layer key', () {
      expect(
        () => calculateCarbonDensity(5.2, 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CK comparison metrics', () {
    test('net change is current pool minus same-layer CK pool', () {
      expect(calculateNetChange(1.5, 2.25), closeTo(-0.75, 1e-9));
    });

    test('loss rate uses the same-layer CK SOC as denominator', () {
      expect(calculateLossRate(10.54, 15.03), closeTo(29.8736, 0.0001));
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
        fert: 'F',
        erosion: 0,
        depth: 10,
        bd: 1.3,
        ph: 6.5,
        wc: 25,
        clay: 30,
        tn: 1.5,
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
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
        fert: 'F',
        erosion: 0,
        depth: 10,
        bd: 1.3,
        ph: 6.5,
        wc: 25,
        clay: 30,
        tn: 1.5,
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
      );
      final result = computeAll(params);
      expect(result.result!.soc, closeTo(23.9, 1e-6));
      expect(result.result!.carbonStorage, closeTo(6.21, 1e-6));
      expect(result.result!.carbonDensity, closeTo(31.07, 1e-6));
      expect(result.result!.netChange, closeTo(0.0, 1e-6));
      expect(result.result!.recoveryRate, closeTo(0.0, 1e-6));
      expect(result.result!.lossRate, closeTo(0.0, 1e-6));
    });

    test('stable golden dataset: UNF/30/35/bd1.5', () {
      final params = CalculationParams(
        fert: 'UNF',
        erosion: 30,
        depth: 35,
        bd: 1.5,
        ph: 6.5,
        wc: 25,
        clay: 30,
        tn: 1.5,
        cropBiomass: 8500,
        strawCarbonRatio: 0.45,
      );
      final result = computeAll(params);
      expect(result.result!.soc, closeTo(10.54, 1e-6));
      expect(result.result!.carbonStorage, closeTo(1.58, 1e-6));
      expect(result.result!.carbonDensity, closeTo(15.81, 1e-6));
      expect(result.result!.netChange, closeTo(-0.67, 1e-6));
      expect(result.result!.recoveryRate, closeTo(-0.034, 1e-6));
      expect(result.result!.lossRate, closeTo(29.9, 1e-6));
    });
  });

  group('splitToLayers', () {
    test('returns single layer when depth <= 20', () {
      final layers = splitToLayers(15.0, 1.3, 10);
      expect(layers.length, 1);
      expect(layers[0].layerId, '0-20');
      expect(layers[0].socValue, 15.0);
      expect(layers[0].thickness, 20.0);
    });

    test(
      'returns the selected layer when depth key is deeper than surface',
      () {
        final layers = splitToLayers(10.0, 1.5, 35);
        expect(layers.length, 1);
        expect(layers[0].layerId, '30-40');
        expect(layers[0].socValue, 10.0);
        expect(layers[0].thickness, 10.0);
      },
    );

    test('rejects an undefined depth key instead of guessing a layer', () {
      expect(() => splitToLayers(12.0, 1.4, 20), throwsA(isA<ArgumentError>()));
    });

    test('buildProfileLayers returns one complete 0-60cm profile', () {
      final layers = buildProfileLayers('F', 0, 1.3);
      expect(layers.map((l) => l.layerId), [
        '0-20',
        '20-30',
        '30-40',
        '40-50',
        '50-60',
      ]);
      expect(layers.fold<double>(0, (sum, layer) => sum + layer.thickness), 60);
    });
  });
}
