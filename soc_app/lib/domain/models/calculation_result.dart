class CalculationResult {
  final double soc;
  final double carbonStorage;
  final double carbonDensity;

  /// 当前土层碳库相对同施肥、侵蚀0cm（CK）土层碳库的差值，kg C/m²。
  final double netChange;

  /// [netChange] 按20年平均折算的代理值，不是逐年模型输出。
  final double recoveryRate;

  /// 当前土层SOC相对同施肥、同土层CK的损失百分比。
  final double lossRate;

  const CalculationResult({
    this.soc = 0.0,
    this.carbonStorage = 0.0,
    this.carbonDensity = 0.0,
    this.netChange = 0.0,
    this.recoveryRate = 0.0,
    this.lossRate = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'soc': soc,
    'carbonStorage': carbonStorage,
    'carbonDensity': carbonDensity,
    'netChange': netChange,
    'recoveryRate': recoveryRate,
    'lossRate': lossRate,
  };

  factory CalculationResult.fromJson(Map<String, dynamic> json) =>
      CalculationResult(
        soc: (json['soc'] as num?)?.toDouble() ?? 0.0,
        carbonStorage: (json['carbonStorage'] as num?)?.toDouble() ?? 0.0,
        carbonDensity: (json['carbonDensity'] as num?)?.toDouble() ?? 0.0,
        netChange: (json['netChange'] as num?)?.toDouble() ?? 0.0,
        recoveryRate: (json['recoveryRate'] as num?)?.toDouble() ?? 0.0,
        lossRate: (json['lossRate'] as num?)?.toDouble() ?? 0.0,
      );
}
