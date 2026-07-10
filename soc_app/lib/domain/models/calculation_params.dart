import 'soil_layer.dart';

class CalculationParams {
  final String fert;
  final int erosion;
  final int depth;
  final double bd;
  final double ph;
  final double wc;
  final double clay;
  final double tn;
  final double cropBiomass;
  final double strawCarbonRatio;
  final double litterCarbonInput;
  final List<SoilLayer> soilLayers;

  /// 历史字段名。当前语义为同施肥、侵蚀0cm（CK）的参考剖面土层。
  final List<SoilLayer> initialLayers;

  const CalculationParams({
    this.fert = 'F',
    this.erosion = 0,
    this.depth = 10,
    this.bd = 1.15,
    this.ph = 5.60,
    this.wc = 18.00,
    this.clay = 96.29,
    this.tn = 1.59,
    this.cropBiomass = 8500.0,
    this.strawCarbonRatio = 0.45,
    this.litterCarbonInput = 0.15,
    this.soilLayers = const [],
    this.initialLayers = const [],
  });

  Map<String, dynamic> toJson() => {
    'fert': fert,
    'erosion': erosion,
    'depth': depth,
    'bd': bd,
    'ph': ph,
    'wc': wc,
    'clay': clay,
    'tn': tn,
    'cropBiomass': cropBiomass,
    'strawCarbonRatio': strawCarbonRatio,
    'litterCarbonInput': litterCarbonInput,
    'soilLayers': soilLayers.map((e) => e.toJson()).toList(),
    'initialLayers': initialLayers.map((e) => e.toJson()).toList(),
  };

  factory CalculationParams.fromJson(
    Map<String, dynamic> json,
  ) => CalculationParams(
    fert: json['fert'] as String? ?? 'F',
    erosion: (json['erosion'] as num?)?.toInt() ?? 0,
    depth: (json['depth'] as num?)?.toInt() ?? 10,
    bd: (json['bd'] as num?)?.toDouble() ?? 1.15,
    ph: (json['ph'] as num?)?.toDouble() ?? 5.60,
    wc: (json['wc'] as num?)?.toDouble() ?? 18.00,
    clay: (json['clay'] as num?)?.toDouble() ?? 96.29,
    tn: (json['tn'] as num?)?.toDouble() ?? 1.59,
    cropBiomass: (json['cropBiomass'] as num?)?.toDouble() ?? 8500.0,
    strawCarbonRatio: (json['strawCarbonRatio'] as num?)?.toDouble() ?? 0.45,
    litterCarbonInput: (json['litterCarbonInput'] as num?)?.toDouble() ?? 0.15,
    soilLayers:
        (json['soilLayers'] as List<dynamic>?)
            ?.map((e) => SoilLayer.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    initialLayers:
        (json['initialLayers'] as List<dynamic>?)
            ?.map((e) => SoilLayer.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
