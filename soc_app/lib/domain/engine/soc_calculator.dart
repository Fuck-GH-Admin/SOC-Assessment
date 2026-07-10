import '../models/calculation_params.dart';
import '../models/calculation_result.dart';
import '../models/soil_layer.dart';

const int kSocAlgorithmVersion = 2;

class SoilDepthDefinition {
  final int key;
  final int startCm;
  final int endCm;
  final String label;

  const SoilDepthDefinition({
    required this.key,
    required this.startCm,
    required this.endCm,
    required this.label,
  });

  String get layerId => '$startCm-$endCm';
  double get thicknessCm => (endCm - startCm).toDouble();
}

const List<SoilDepthDefinition> kSoilDepthDefinitions = [
  SoilDepthDefinition(key: 10, startCm: 0, endCm: 20, label: '0-20 cm（表层）'),
  SoilDepthDefinition(key: 25, startCm: 20, endCm: 30, label: '20-30 cm（亚表层）'),
  SoilDepthDefinition(key: 35, startCm: 30, endCm: 40, label: '30-40 cm（中层）'),
  SoilDepthDefinition(key: 45, startCm: 40, endCm: 50, label: '40-50 cm（深层）'),
  SoilDepthDefinition(key: 55, startCm: 50, endCm: 60, label: '50-60 cm（底层）'),
];

const Set<String> kFertilizerTreatments = {'F', 'UNF'};
const Set<int> kErosionLevels = {0, 10, 20, 30, 40, 50, 60, 70};
const Set<int> kSoilDepthKeys = {10, 25, 35, 45, 55};

const Map<String, Map<int, Map<int, double>>> _baseData = {
  'F': {
    0: {10: 23.90, 25: 16.64, 35: 13.09, 45: 10.30, 55: 8.10},
    10: {10: 17.64, 25: 10.16, 35: 7.09, 45: 4.91, 55: 5.89},
    20: {10: 11.77, 25: 8.48, 35: 6.84, 45: 5.77, 55: 4.94},
    30: {10: 9.30, 25: 12.62, 35: 8.93, 45: 7.47, 55: 7.06},
    40: {10: 12.51, 25: 11.50, 35: 8.80, 45: 8.28, 55: 6.50},
    50: {10: 19.92, 25: 13.39, 35: 11.54, 45: 9.94, 55: 7.17},
    60: {10: 8.82, 25: 9.81, 35: 8.36, 45: 8.20, 55: 6.79},
    70: {10: 7.40, 25: 9.81, 35: 7.95, 45: 7.46, 55: 7.70},
  },
  'UNF': {
    0: {10: 23.90, 25: 17.71, 35: 15.03, 45: 8.34, 55: 10.58},
    10: {10: 17.64, 25: 18.31, 35: 12.43, 45: 9.04, 55: 7.89},
    20: {10: 21.03, 25: 17.02, 35: 15.03, 45: 11.93, 55: 9.47},
    30: {10: 13.76, 25: 13.45, 35: 10.54, 45: 8.52, 55: 7.81},
    40: {10: 13.16, 25: 14.08, 35: 10.91, 45: 9.04, 55: 7.71},
    50: {10: 12.41, 25: 14.52, 35: 12.15, 45: 10.19, 55: 8.26},
    60: {10: 10.53, 25: 10.80, 35: 8.80, 45: 8.30, 55: 7.21},
    70: {10: 12.81, 25: 13.24, 35: 11.36, 45: 9.38, 55: 8.56},
  },
};

SoilDepthDefinition depthDefinitionFor(int depthKey) {
  return kSoilDepthDefinitions.firstWhere(
    (d) => d.key == depthKey,
    orElse: () => throw ArgumentError.value(depthKey, 'depthKey', '未知土层键'),
  );
}

List<String> validateInput(CalculationParams params) {
  final errors = <String>[];
  final numericInputs = <(String, double)>[
    ('土壤容重', params.bd),
    ('pH值', params.ph),
    ('含水量', params.wc),
    ('黏粉粒含量', params.clay),
    ('全氮含量', params.tn),
    ('秸秆生物量', params.cropBiomass),
    ('秸秆碳含量', params.strawCarbonRatio),
    ('基础凋落物碳输入', params.litterCarbonInput),
  ];
  for (final (label, value) in numericInputs) {
    if (!value.isFinite) {
      errors.add('$label必须为有限数值');
    }
  }

  if (!kFertilizerTreatments.contains(params.fert)) {
    errors.add('未知施肥处理：${params.fert}');
  }
  if (!kErosionLevels.contains(params.erosion)) {
    errors.add('侵蚀程度必须为0、10、20、30、40、50、60或70 cm');
  }
  if (!kSoilDepthKeys.contains(params.depth)) {
    errors.add('土层必须为0-20、20-30、30-40、40-50或50-60 cm');
  }
  if (params.bd < 0.5 || params.bd > 2.5) {
    errors.add('土壤容重应在0.5-2.5 g/cm^3范围内');
  }
  if (params.ph < 3 || params.ph > 11) {
    errors.add('pH值应在3-11范围内');
  }
  if (params.wc < 0 || params.wc > 100) {
    errors.add('含水量应在0-100%范围内');
  }
  if (params.clay < 0 || params.clay > 100) {
    errors.add('黏粉粒含量应在0-100%范围内');
  }
  if (params.tn < 0 || params.tn > 10) {
    errors.add('全氮含量应在0-10 g/kg范围内');
  }
  if (params.cropBiomass < 0) {
    errors.add('秸秆生物量不能为负');
  }
  if (params.strawCarbonRatio < 0 || params.strawCarbonRatio > 1) {
    errors.add('秸秆碳含量应在0-1范围内');
  }
  if (params.litterCarbonInput < 0) {
    errors.add('基础凋落物碳输入不能为负');
  }

  void validateLayers(List<SoilLayer> layers, String groupName) {
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (!layer.bd.isFinite ||
          !layer.socValue.isFinite ||
          !layer.thickness.isFinite) {
        errors.add('$groupName第${i + 1}层包含非有限数值');
        continue;
      }
      if (layer.bd < 0.5 || layer.bd > 2.5) {
        errors.add('$groupName第${i + 1}层土壤容重应在0.5-2.5 g/cm^3范围内');
      }
      if (layer.socValue < 0 || layer.socValue > 100) {
        errors.add('$groupName第${i + 1}层SOC含量应在0-100 g/kg范围内');
      }
      if (layer.thickness <= 0) {
        errors.add('$groupName第${i + 1}层厚度必须大于0');
      }
    }
  }

  validateLayers(params.soilLayers, '当前');
  validateLayers(params.initialLayers, '参考');
  return errors;
}

double? lookupBaseSOC(String fert, int erosion, int depth) {
  return _baseData[fert]?[erosion]?[depth];
}

double calculateSOCValue(String fert, int erosion, int depth) {
  final baseSOC = lookupBaseSOC(fert, erosion, depth);
  if (baseSOC == null) {
    throw ArgumentError('没有找到施肥=$fert、侵蚀=$erosion、土层键=$depth 的SOC基础数据');
  }
  return baseSOC.clamp(0, double.infinity);
}

double calculateSOC(CalculationParams params) {
  return calculateSOCValue(params.fert, params.erosion, params.depth);
}

double calculateCarbonStorage(double soc, double bd, int depthKey) {
  final layer = depthDefinitionFor(depthKey);
  return ((soc * bd * layer.thicknessCm) / 100).clamp(0, double.infinity);
}

double calculateCarbonDensity(double carbonStorage, int depthKey) {
  final thicknessCm = depthDefinitionFor(depthKey).thicknessCm;
  return (carbonStorage / (thicknessCm / 100)).clamp(0, double.infinity);
}

double calculateNetChange(double currentPool, double referencePool) {
  return currentPool - referencePool;
}

double calculateRecoveryRate(double netChange, [int years = 20]) {
  if (years <= 0) return 0;
  return netChange / years;
}

List<SoilLayer> splitToLayers(double socValue, double bd, int depthCm) {
  final layer = depthDefinitionFor(depthCm);
  return [
    SoilLayer(
      layerId: layer.layerId,
      socValue: socValue,
      bd: bd,
      thickness: layer.thicknessCm,
    ),
  ];
}

List<SoilLayer> buildProfileLayers(String fert, int erosion, double bd) {
  return kSoilDepthDefinitions.map((layer) {
    return SoilLayer(
      layerId: layer.layerId,
      socValue: calculateSOCValue(fert, erosion, layer.key),
      bd: bd,
      thickness: layer.thicknessCm,
    );
  }).toList();
}

double calculateLossRate(double currentSoc, double referenceSoc) {
  if (referenceSoc <= 0) return 0;
  return ((referenceSoc - currentSoc) / referenceSoc * 100).clamp(
    0,
    double.infinity,
  );
}

({bool success, CalculationResult? result, List<String> errors}) computeAll(
  CalculationParams params,
) {
  final errors = validateInput(params);
  if (errors.isNotEmpty) {
    return (success: false, result: null, errors: errors);
  }

  final soc = calculateSOC(params);
  final depthVal = params.depth;
  final carbonStorage = calculateCarbonStorage(soc, params.bd, depthVal);
  final carbonDensity = calculateCarbonDensity(carbonStorage, depthVal);
  final referenceSoc = calculateSOCValue(params.fert, 0, params.depth);
  final referenceStorage = calculateCarbonStorage(
    referenceSoc,
    params.bd,
    params.depth,
  );
  final netChange = calculateNetChange(carbonStorage, referenceStorage);
  final recoveryRate = calculateRecoveryRate(netChange);
  final lossRate = calculateLossRate(soc, referenceSoc);

  return (
    success: true,
    result: CalculationResult(
      soc: double.parse(soc.toStringAsFixed(2)),
      carbonStorage: double.parse(carbonStorage.toStringAsFixed(2)),
      carbonDensity: double.parse(carbonDensity.toStringAsFixed(2)),
      netChange: double.parse(netChange.toStringAsFixed(2)),
      recoveryRate: double.parse(recoveryRate.toStringAsFixed(3)),
      lossRate: double.parse(lossRate.toStringAsFixed(1)),
    ),
    errors: [],
  );
}
