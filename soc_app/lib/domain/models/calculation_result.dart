class CalculationResult {
  final double soc;
  final double carbonStorage;
  final double carbonDensity;
  final double netChange;
  final double recoveryRate;
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
