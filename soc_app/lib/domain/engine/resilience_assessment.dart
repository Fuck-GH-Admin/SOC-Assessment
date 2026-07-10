import '../models/calculation_params.dart';
import '../models/resilience_result.dart';
import '../models/soil_layer.dart';
import 'soc_calculator.dart';

double computeCarbonPoolByLayer(
  double socGkg,
  double bdGcm3,
  double thicknessCm,
) {
  return (socGkg * bdGcm3 * thicknessCm) / 100;
}

double computeTotalCarbonPool(List<SoilLayer> layers) {
  return layers.fold<double>(0, (sum, layer) {
    return sum +
        computeCarbonPoolByLayer(layer.socValue, layer.bd, layer.thickness);
  });
}

double computeNetChange(double finalPool, double initialPool) {
  return finalPool - initialPool;
}

double computeAnnualizedDifference(
  double poolCurrent,
  double poolReference, [
  int years = 1,
]) {
  if (years <= 0) return 0;
  return (poolCurrent - poolReference) / years;
}

double computeStrawCarbonInput(
  double biomassKgha,
  double carbonRatio,
  double returnRatio,
) {
  return (biomassKgha * carbonRatio * returnRatio) / 10000;
}

List<StrawScenario> computeStrawScenarios(
  double biomassKgha,
  double carbonRatio,
  double litterCarbonInput,
) {
  const ratios = [0.3, 0.5, 1.0];
  return ratios.map((ratio) {
    final strawInput = computeStrawCarbonInput(biomassKgha, carbonRatio, ratio);
    return StrawScenario(
      label: '${(ratio * 100).round()}%秸秆还田',
      returnRatio: ratio,
      strawInput: strawInput,
      totalInput: litterCarbonInput + strawInput,
    );
  }).toList();
}

({int startCm, int endCm})? _parseLayerRange(String layerId) {
  final match = RegExp(r'^(\d+)-(\d+)$').firstMatch(layerId.trim());
  if (match == null) return null;
  final start = int.tryParse(match.group(1)!);
  final end = int.tryParse(match.group(2)!);
  if (start == null || end == null || start >= end) return null;
  return (startCm: start, endCm: end);
}

List<String> _validateProfile(List<SoilLayer> layers, String name) {
  final errors = <String>[];
  final parsed = <({SoilLayer layer, int startCm, int endCm})>[];

  for (final layer in layers) {
    final range = _parseLayerRange(layer.layerId);
    if (range == null) {
      errors.add('$name存在无法识别的土层编号：${layer.layerId}');
      continue;
    }
    if (range.startCm < 0 || range.endCm > 60) {
      errors.add('$name土层${layer.layerId}超出0-60cm评估范围');
    }
    final expectedThickness = (range.endCm - range.startCm).toDouble();
    if ((layer.thickness - expectedThickness).abs() > 0.001) {
      errors.add(
        '$name土层${layer.layerId}厚度应为${expectedThickness.toStringAsFixed(0)}cm，'
        '实际为${layer.thickness.toStringAsFixed(3)}cm',
      );
    }
    parsed.add((layer: layer, startCm: range.startCm, endCm: range.endCm));
  }

  if (parsed.length != layers.length) return errors;

  parsed.sort((a, b) => a.startCm.compareTo(b.startCm));
  final ids = parsed.map((e) => e.layer.layerId).toList();
  if (ids.toSet().length != ids.length) {
    errors.add('$name存在重复土层编号');
  }

  var expectedStart = 0;
  var hasSurfaceBoundary = false;
  for (final item in parsed) {
    if (item.startCm != expectedStart) {
      errors.add('$name土层必须无重叠、无缺口地连续覆盖0-60cm');
      break;
    }
    if (item.endCm == 20) hasSurfaceBoundary = true;
    if (item.startCm < 20 && item.endCm > 20) {
      errors.add('$name土层必须在20cm处设置边界，以计算0-20cm碳库');
    }
    expectedStart = item.endCm;
  }
  if (expectedStart != 60) {
    errors.add('$name土层必须完整覆盖0-60cm');
  }
  if (!hasSurfaceBoundary) {
    errors.add('$name土层缺少0-20cm表层边界');
  }
  return errors.toSet().toList();
}

({bool success, ResilienceResult? result, List<String> errors})
assessResilience(CalculationParams params) {
  if (params.soilLayers.isEmpty) {
    return (success: false, result: null, errors: ['缺少土层数据']);
  }
  if (params.initialLayers.isEmpty) {
    return (success: false, result: null, errors: ['缺少CK参考土层数据']);
  }

  final validationErrors = validateInput(params);
  validationErrors.addAll(_validateProfile(params.soilLayers, '当前剖面'));
  validationErrors.addAll(_validateProfile(params.initialLayers, 'CK参考剖面'));

  final currentLayerIds = params.soilLayers.map((l) => l.layerId).toSet();
  final referenceLayerIds = params.initialLayers.map((l) => l.layerId).toSet();
  if (currentLayerIds.length == params.soilLayers.length &&
      referenceLayerIds.length == params.initialLayers.length &&
      (currentLayerIds.length != referenceLayerIds.length ||
          !currentLayerIds.containsAll(referenceLayerIds))) {
    validationErrors.add('当前剖面与CK参考剖面必须使用相同的土层划分');
  }

  if (validationErrors.isNotEmpty) {
    return (
      success: false,
      result: null,
      errors: validationErrors.toSet().toList(),
    );
  }

  bool isSurfaceLayer(SoilLayer layer) {
    final range = _parseLayerRange(layer.layerId)!;
    return range.startCm >= 0 && range.endCm <= 20;
  }

  final finalPool020 = computeTotalCarbonPool(
    params.soilLayers.where(isSurfaceLayer).toList(),
  );
  final finalPool060 = computeTotalCarbonPool(params.soilLayers);

  final referencePool020 = computeTotalCarbonPool(
    params.initialLayers.where(isSurfaceLayer).toList(),
  );
  final referencePool060 = computeTotalCarbonPool(params.initialLayers);

  // 第五章要求分别分析20年0-60cm与100年0-20cm净变化。
  // 当前数据没有逐年模拟末期值，因此这里计算的是“当前侵蚀处理相对
  // 同施肥CK（侵蚀0cm）的碳库差”，供对应时间口径作代理参考。
  final netChange20yr = computeNetChange(finalPool060, referencePool060);
  final netChange100yr = computeNetChange(finalPool020, referencePool020);
  final annualizedDifference = computeAnnualizedDifference(
    finalPool060,
    referencePool060,
    20,
  );

  final strawScenarios = computeStrawScenarios(
    params.cropBiomass,
    params.strawCarbonRatio,
    params.litterCarbonInput,
  );

  final layerPools = params.soilLayers
      .map(
        (l) => LayerPool(
          layerId: l.layerId,
          carbonPool: double.parse(
            computeCarbonPoolByLayer(
              l.socValue,
              l.bd,
              l.thickness,
            ).toStringAsFixed(3),
          ),
          soc: l.socValue,
          bd: l.bd,
          thickness: l.thickness,
        ),
      )
      .toList();

  const epsilon = 0.005;
  final status = netChange20yr > epsilon
      ? '当前0-60cm剖面碳库高于同施肥CK参考'
      : netChange20yr < -epsilon
      ? '当前0-60cm剖面碳库低于同施肥CK参考'
      : '当前0-60cm剖面碳库与同施肥CK参考接近';

  return (
    success: true,
    result: ResilienceResult(
      carbonPool020: double.parse(finalPool020.toStringAsFixed(2)),
      carbonPool060: double.parse(finalPool060.toStringAsFixed(2)),
      netChange20yr: double.parse(netChange20yr.toStringAsFixed(2)),
      netChange100yr: double.parse(netChange100yr.toStringAsFixed(2)),
      recoveryRateAnnual: double.parse(annualizedDifference.toStringAsFixed(3)),
      layerPools: layerPools,
      strawScenarios: strawScenarios,
      status: status,
    ),
    errors: [],
  );
}
