import 'soil_layer.dart';

/// 单个土层相对同施肥、同土层、侵蚀 0cm（CK）的恢复力评估证据。
class LayerResilience {
  final String layerId;
  final double soc;
  final double ckSoc;
  final double carbonPool;
  final double ckCarbonPool;

  /// 当前层碳库 − 同层 CK 碳库，kg C/m²。负值表示亏缺。
  final double poolDifference;

  /// 当前层 SOC 相对同层 CK 的损失率（%），CK ≤ 0 时为 0。
  final double lossRate;

  const LayerResilience({
    required this.layerId,
    required this.soc,
    required this.ckSoc,
    required this.carbonPool,
    required this.ckCarbonPool,
    required this.poolDifference,
    required this.lossRate,
  });

  Map<String, dynamic> toJson() => {
    'layerId': layerId,
    'soc': soc,
    'ckSoc': ckSoc,
    'carbonPool': carbonPool,
    'ckCarbonPool': ckCarbonPool,
    'poolDifference': poolDifference,
    'lossRate': lossRate,
  };

  factory LayerResilience.fromJson(Map<String, dynamic> json) =>
      LayerResilience(
        layerId: json['layerId'] as String? ?? '',
        soc: (json['soc'] as num?)?.toDouble() ?? 0.0,
        ckSoc: (json['ckSoc'] as num?)?.toDouble() ?? 0.0,
        carbonPool: (json['carbonPool'] as num?)?.toDouble() ?? 0.0,
        ckCarbonPool: (json['ckCarbonPool'] as num?)?.toDouble() ?? 0.0,
        poolDifference: (json['poolDifference'] as num?)?.toDouble() ?? 0.0,
        lossRate: (json['lossRate'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 单个侵蚀等级相对 CK 的剖面亏缺与年化折算（折算代理，非逐年模型）。
class ErosionDeficit {
  final int erosionCm;
  final double pool060;
  final double ckPool060;

  /// 0-60cm 剖面相对 CK 的静态碳库差，kg C/m²。
  final double deficit;

  /// 静态差 ÷ 20 的折算代理，kg C/m²/yr。
  final double annualizedDeficit;

  const ErosionDeficit({
    required this.erosionCm,
    required this.pool060,
    required this.ckPool060,
    required this.deficit,
    required this.annualizedDeficit,
  });

  Map<String, dynamic> toJson() => {
    'erosionCm': erosionCm,
    'pool060': pool060,
    'ckPool060': ckPool060,
    'deficit': deficit,
    'annualizedDeficit': annualizedDeficit,
  };

  factory ErosionDeficit.fromJson(Map<String, dynamic> json) => ErosionDeficit(
    erosionCm: (json['erosionCm'] as num?)?.toInt() ?? 0,
    pool060: (json['pool060'] as num?)?.toDouble() ?? 0.0,
    ckPool060: (json['ckPool060'] as num?)?.toDouble() ?? 0.0,
    deficit: (json['deficit'] as num?)?.toDouble() ?? 0.0,
    annualizedDeficit:
        (json['annualizedDeficit'] as num?)?.toDouble() ?? 0.0,
  );
}

/// 秸秆情景碳输入相对年化亏缺的覆盖结论。
class ScenarioCoverage {
  final String label;
  final double returnRatio;
  final double strawInput;

  /// 秸秆碳输入 − 当前侵蚀等级的年化亏缺代理。正值表示输入覆盖亏缺。
  final double coverageMargin;

  /// 覆盖程度：输入 ≥ 亏缺时为 1，否则为 输入/亏缺。
  final double coverageRatio;

  const ScenarioCoverage({
    required this.label,
    required this.returnRatio,
    required this.strawInput,
    required this.coverageMargin,
    required this.coverageRatio,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'returnRatio': returnRatio,
    'strawInput': strawInput,
    'coverageMargin': coverageMargin,
    'coverageRatio': coverageRatio,
  };

  factory ScenarioCoverage.fromJson(Map<String, dynamic> json) =>
      ScenarioCoverage(
        label: json['label'] as String? ?? '',
        returnRatio: (json['returnRatio'] as num?)?.toDouble() ?? 0.0,
        strawInput: (json['strawInput'] as num?)?.toDouble() ?? 0.0,
        coverageMargin: (json['coverageMargin'] as num?)?.toDouble() ?? 0.0,
        coverageRatio: (json['coverageRatio'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 恢复力评估总体结论。
class ResilienceReport {
  final List<LayerResilience> layers;

  /// 碳库差最小（亏缺最大）的土层编号，即"薄弱层"。
  final String weakestLayerId;

  /// 当前侵蚀等级相对 CK 的剖面亏缺（0-60cm），kg C/m²。
  final double profileDeficit;

  /// 剖面亏缺 ÷ 20 的折算代理，kg C/m²/yr。
  final double annualizedDeficit;

  final List<ErosionDeficit> erosionDeficits;
  final List<ScenarioCoverage> scenarioCoverages;

  /// 结论等级：covering / partial / deficit。
  /// covering：至少一个情景的秸秆输入覆盖年化亏缺；
  /// partial：最高档覆盖了部分亏缺；
  /// deficit：所有情景均无法覆盖或亏缺不成立。
  final String conclusionLevel;

  final String conclusionText;

  const ResilienceReport({
    required this.layers,
    required this.weakestLayerId,
    required this.profileDeficit,
    required this.annualizedDeficit,
    required this.erosionDeficits,
    required this.scenarioCoverages,
    required this.conclusionLevel,
    required this.conclusionText,
  });

  Map<String, dynamic> toJson() => {
    'layers': layers.map((e) => e.toJson()).toList(),
    'weakestLayerId': weakestLayerId,
    'profileDeficit': profileDeficit,
    'annualizedDeficit': annualizedDeficit,
    'erosionDeficits': erosionDeficits.map((e) => e.toJson()).toList(),
    'scenarioCoverages': scenarioCoverages.map((e) => e.toJson()).toList(),
    'conclusionLevel': conclusionLevel,
    'conclusionText': conclusionText,
  };

  factory ResilienceReport.fromJson(Map<String, dynamic> json) =>
      ResilienceReport(
        layers: (json['layers'] as List<dynamic>?)
                ?.map((e) => LayerResilience.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        weakestLayerId: json['weakestLayerId'] as String? ?? '',
        profileDeficit: (json['profileDeficit'] as num?)?.toDouble() ?? 0.0,
        annualizedDeficit:
            (json['annualizedDeficit'] as num?)?.toDouble() ?? 0.0,
        erosionDeficits: (json['erosionDeficits'] as List<dynamic>?)
                ?.map((e) => ErosionDeficit.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        scenarioCoverages: (json['scenarioCoverages'] as List<dynamic>?)
                ?.map(
                  (e) => ScenarioCoverage.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        conclusionLevel: json['conclusionLevel'] as String? ?? 'deficit',
        conclusionText: json['conclusionText'] as String? ?? '',
      );

  /// 供候选卡片使用的三态标记。
  bool get isCovering => conclusionLevel == 'covering';
  bool get isPartial => conclusionLevel == 'partial';
}

/// 分层结论的独立函数，便于测试与复用。
List<LayerResilience> buildLayerResilience({
  required List<SoilLayer> currentLayers,
  required List<SoilLayer> ckLayers,
  required double Function(String layerId) carbonPoolOf,
}) {
  final byId = {for (final l in ckLayers) l.layerId: l};
  final result = <LayerResilience>[];
  for (final layer in currentLayers) {
    final ck = byId[layer.layerId];
    if (ck == null) continue;
    final pool = carbonPoolOf(layer.layerId);
    final ckPool = carbonPoolOf('ck:${layer.layerId}');
    final lossRate = ck.socValue <= 0
        ? 0.0
        : ((ck.socValue - layer.socValue) / ck.socValue * 100).clamp(
            0,
            double.infinity,
          );
    result.add(
      LayerResilience(
        layerId: layer.layerId,
        soc: layer.socValue,
        ckSoc: ck.socValue,
        carbonPool: pool,
        ckCarbonPool: ckPool,
        poolDifference: pool - ckPool,
        lossRate: lossRate.toDouble(),
      ),
    );
  }
  return result;
}
