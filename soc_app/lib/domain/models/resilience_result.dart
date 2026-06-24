class StrawScenario {
  final String label;
  final double returnRatio;
  final double strawInput;
  final double totalInput;

  const StrawScenario({
    this.label = '',
    this.returnRatio = 0.0,
    this.strawInput = 0.0,
    this.totalInput = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'returnRatio': returnRatio,
    'strawInput': strawInput,
    'totalInput': totalInput,
  };

  factory StrawScenario.fromJson(Map<String, dynamic> json) => StrawScenario(
    label: json['label'] as String? ?? '',
    returnRatio: (json['returnRatio'] as num?)?.toDouble() ?? 0.0,
    strawInput: (json['strawInput'] as num?)?.toDouble() ?? 0.0,
    totalInput: (json['totalInput'] as num?)?.toDouble() ?? 0.0,
  );
}

class LayerPool {
  final String layerId;
  final double carbonPool;
  final double soc;
  final double bd;
  final double thickness;

  const LayerPool({
    this.layerId = '',
    this.carbonPool = 0.0,
    this.soc = 0.0,
    this.bd = 0.0,
    this.thickness = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'layerId': layerId,
    'carbonPool': carbonPool,
    'soc': soc,
    'bd': bd,
    'thickness': thickness,
  };

  factory LayerPool.fromJson(Map<String, dynamic> json) => LayerPool(
    layerId: json['layerId'] as String? ?? '',
    carbonPool: (json['carbonPool'] as num?)?.toDouble() ?? 0.0,
    soc: (json['soc'] as num?)?.toDouble() ?? 0.0,
    bd: (json['bd'] as num?)?.toDouble() ?? 0.0,
    thickness: (json['thickness'] as num?)?.toDouble() ?? 0.0,
  );
}

class ResilienceResult {
  final double carbonPool020;
  final double carbonPool060;
  final double netChange20yr;
  final double netChange100yr;
  final double recoveryRateAnnual;
  final List<StrawScenario> strawScenarios;
  final List<LayerPool> layerPools;
  final String status;

  const ResilienceResult({
    this.carbonPool020 = 0.0,
    this.carbonPool060 = 0.0,
    this.netChange20yr = 0.0,
    this.netChange100yr = 0.0,
    this.recoveryRateAnnual = 0.0,
    this.strawScenarios = const [],
    this.layerPools = const [],
    this.status = '',
  });

  Map<String, dynamic> toJson() => {
    'carbonPool_0_20': carbonPool020,
    'carbonPool_0_60': carbonPool060,
    'netChange_20yr': netChange20yr,
    'netChange_100yr': netChange100yr,
    'recoveryRate_annual': recoveryRateAnnual,
    'strawScenarios': strawScenarios.map((e) => e.toJson()).toList(),
    'layerPools': layerPools.map((e) => e.toJson()).toList(),
    'status': status,
  };

  factory ResilienceResult.fromJson(Map<String, dynamic> json) =>
      ResilienceResult(
        carbonPool020: (json['carbonPool_0_20'] as num?)?.toDouble() ?? 0.0,
        carbonPool060: (json['carbonPool_0_60'] as num?)?.toDouble() ?? 0.0,
        netChange20yr: (json['netChange_20yr'] as num?)?.toDouble() ?? 0.0,
        netChange100yr: (json['netChange_100yr'] as num?)?.toDouble() ?? 0.0,
        recoveryRateAnnual:
            (json['recoveryRate_annual'] as num?)?.toDouble() ?? 0.0,
        strawScenarios: (json['strawScenarios'] as List<dynamic>?)
                ?.map(
                    (e) => StrawScenario.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        layerPools: (json['layerPools'] as List<dynamic>?)
                ?.map((e) => LayerPool.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        status: json['status'] as String? ?? '',
      );
}
