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
  final List<SoilLayer> initialLayers;

  const CalculationParams({
    this.fert = 'F',
    this.erosion = 0,
    this.depth = 10,
    this.bd = 0.0,
    this.ph = 0.0,
    this.wc = 0.0,
    this.clay = 0.0,
    this.tn = 0.0,
    this.cropBiomass = 0.0,
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

  factory CalculationParams.fromJson(Map<String, dynamic> json) =>
      CalculationParams(
        fert: json['fert'] as String? ?? 'F',
        erosion: json['erosion'] as int? ?? 0,
        depth: json['depth'] as int? ?? 10,
        bd: (json['bd'] as num?)?.toDouble() ?? 0.0,
        ph: (json['ph'] as num?)?.toDouble() ?? 0.0,
        wc: (json['wc'] as num?)?.toDouble() ?? 0.0,
        clay: (json['clay'] as num?)?.toDouble() ?? 0.0,
        tn: (json['tn'] as num?)?.toDouble() ?? 0.0,
        cropBiomass: (json['cropBiomass'] as num?)?.toDouble() ?? 0.0,
        strawCarbonRatio: (json['strawCarbonRatio'] as num?)?.toDouble() ?? 0.45,
        litterCarbonInput: (json['litterCarbonInput'] as num?)?.toDouble() ?? 0.15,
        soilLayers: (json['soilLayers'] as List<dynamic>?)
                ?.map((e) => SoilLayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        initialLayers: (json['initialLayers'] as List<dynamic>?)
                ?.map((e) => SoilLayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
