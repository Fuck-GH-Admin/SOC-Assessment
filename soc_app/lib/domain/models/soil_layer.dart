class SoilLayer {
  final String layerId;
  final double bd;
  final double socValue;
  final double thickness;

  const SoilLayer({
    this.layerId = '',
    this.bd = 0.0,
    this.socValue = 0.0,
    this.thickness = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'layerId': layerId,
    'bd': bd,
    'socValue': socValue,
    'thickness': thickness,
  };

  factory SoilLayer.fromJson(Map<String, dynamic> json) => SoilLayer(
    layerId: json['layerId'] as String? ?? '',
    bd: (json['bd'] as num?)?.toDouble() ?? 0.0,
    socValue: (json['socValue'] as num?)?.toDouble() ?? 0.0,
    thickness: (json['thickness'] as num?)?.toDouble() ?? 0.0,
  );
}
