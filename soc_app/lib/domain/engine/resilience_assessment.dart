import '../models/calculation_params.dart';
import '../models/resilience_result.dart';

double computeCarbonPoolByLayer(double socGkg, double bdGcm3, double thicknessCm) {
  return (socGkg * bdGcm3 * thicknessCm) / 100;
}

double computeTotalCarbonPool(List<dynamic> layers) {
  return layers.fold<double>(0, (sum, layer) {
    return sum + computeCarbonPoolByLayer(layer.socValue, layer.bd, layer.thickness);
  });
}

double computeNetChange(double finalPool, double initialPool) {
  return finalPool - initialPool;
}

double computeAnnualRecoveryRate(double poolCurrent, double poolPrevious, [int years = 1]) {
  return (poolCurrent - poolPrevious) / years;
}

double computeStrawCarbonInput(double biomassKgha, double carbonRatio, double returnRatio) {
  return (biomassKgha * carbonRatio * returnRatio) / 10000;
}

List<StrawScenario> computeStrawScenarios(
    double biomassKgha, double carbonRatio, double litterCarbonInput) {
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

({bool success, ResilienceResult? result, List<String> errors}) assessResilience(
    CalculationParams params) {
  if (params.soilLayers.isEmpty) {
    return (success: false, result: null, errors: ['缺少土层数据']);
  }
  if (params.initialLayers.isEmpty) {
    return (success: false, result: null, errors: ['缺少初始年份土层数据']);
  }

  int _layerStart(String layerId) {
    final parts = layerId.split('-');
    return int.tryParse(parts.first) ?? 0;
  }

  final finalPool020 = computeTotalCarbonPool(
    params.soilLayers.where((l) => _layerStart(l.layerId) < 20).toList(),
  );
  final finalPool060 = computeTotalCarbonPool(params.soilLayers);

  final initialPool020 = computeTotalCarbonPool(
    params.initialLayers.where((l) => _layerStart(l.layerId) < 20).toList(),
  );
  final initialPool060 = computeTotalCarbonPool(params.initialLayers);

  final netChange20yr = computeNetChange(finalPool060, initialPool060);
  final netChange100yr = computeNetChange(finalPool020, initialPool020);
  final recoveryRate = computeAnnualRecoveryRate(finalPool060, initialPool060, 20);

  final strawScenarios = computeStrawScenarios(
    params.cropBiomass, params.strawCarbonRatio, params.litterCarbonInput,
  );

  final layerPools = params.soilLayers.map((l) => LayerPool(
    layerId: l.layerId,
    carbonPool: double.parse(
        computeCarbonPoolByLayer(l.socValue, l.bd, l.thickness).toStringAsFixed(3)),
    soc: l.socValue,
    bd: l.bd,
    thickness: l.thickness,
  )).toList();

  final status = netChange20yr > 0
      ? '碳库呈恢复趋势，土壤固碳能力正向'
      : netChange20yr == 0
          ? '碳库基本稳定'
          : '碳库持续亏损，需加强管理干预';

  return (
    success: true,
    result: ResilienceResult(
      carbonPool020: double.parse(finalPool020.toStringAsFixed(2)),
      carbonPool060: double.parse(finalPool060.toStringAsFixed(2)),
      netChange20yr: double.parse(netChange20yr.toStringAsFixed(2)),
      netChange100yr: double.parse(netChange100yr.toStringAsFixed(2)),
      recoveryRateAnnual: double.parse(recoveryRate.toStringAsFixed(3)),
      layerPools: layerPools,
      strawScenarios: strawScenarios,
      status: status,
    ),
    errors: [],
  );
}
