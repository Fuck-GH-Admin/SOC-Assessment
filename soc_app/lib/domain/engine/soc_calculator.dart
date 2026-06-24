import '../models/calculation_params.dart';
import '../models/calculation_result.dart';

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

const Map<int, double> _erosionCoefficients = {
  0: 1.00, 10: 0.74, 20: 0.49, 30: 0.39,
  40: 0.52, 50: 0.83, 60: 0.37, 70: 0.31,
};

const Map<String, double> _fertilizerEffect = {'F': 1.0, 'UNF': 0.92};

List<String> validateInput(CalculationParams params) {
  final errors = <String>[];
  if (params.bd < 0.5 || params.bd > 2.5) {
    errors.add('土壤容重应在0.5-2.5 g/cm³范围内');
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
  for (var i = 0; i < params.soilLayers.length; i++) {
    final layer = params.soilLayers[i];
    if (layer.bd < 0.8 || layer.bd > 1.8) {
      errors.add('第${i + 1}层土壤容重应在0.8-1.8 g/cm³范围内');
    }
    if (layer.socValue < 0 || layer.socValue > 100) {
      errors.add('第${i + 1}层SOC含量应在0-100 g/kg范围内');
    }
    if (layer.thickness <= 0) {
      errors.add('第${i + 1}层厚度必须大于0');
    }
  }
  return errors;
}

double? lookupBaseSOC(String fert, int erosion, int depth) {
  return _baseData[fert]?[erosion]?[depth];
}

double calculateSOC(CalculationParams params) {
  final fert = params.fert;
  final erosion = params.erosion;
  final depth = params.depth;
  final erosionCoeff = _erosionCoefficients[erosion] ?? 1.0;
  final fertFactor = _fertilizerEffect[fert] ?? 1.0;
  final baseSOC = _baseData[fert]?[erosion]?[depth] ?? 10.0;
  return (baseSOC * erosionCoeff * fertFactor).clamp(0, double.infinity);
}

double calculateCarbonStorage(double soc, double bd, int depthCm) {
  return ((soc * bd * (depthCm < 20 ? depthCm : 20)) / 100)
      .clamp(0, double.infinity);
}

double calculateCarbonDensity(double carbonStorage, int depthCm) {
  if (depthCm <= 0) return 0;
  return (carbonStorage / (depthCm / 100)).clamp(0, double.infinity);
}

double calculateNetChange(double soc, String fert, int erosion) {
  final erosionImpact = (erosion / 70) * 0.3;
  final fertImpact = fert == 'F' ? 0.05 : -0.02;
  return soc * (1 + fertImpact - erosionImpact);
}

double calculateRecoveryRate(double netChange, [int years = 20]) {
  return (netChange / years).clamp(0, double.infinity);
}

double calculateLossRate(double soc, String fert) {
  final baseSoc = _baseData[fert]?[0]?[10];
  if (baseSoc == null) return 0;
  return ((baseSoc - soc) / baseSoc * 100).clamp(0, double.infinity);
}

({bool success, CalculationResult? result, List<String> errors})
    computeAll(CalculationParams params) {
  final errors = validateInput(params);
  if (errors.isNotEmpty) {
    return (success: false, result: null, errors: errors);
  }

  final soc = calculateSOC(params);
  final depthVal = params.depth;
  final carbonStorage = calculateCarbonStorage(soc, params.bd, depthVal);
  final carbonDensity = calculateCarbonDensity(carbonStorage, depthVal);
  final netChange = calculateNetChange(soc, params.fert, params.erosion);
  final recoveryRate = calculateRecoveryRate(netChange);
  final lossRate = calculateLossRate(soc, params.fert);

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
