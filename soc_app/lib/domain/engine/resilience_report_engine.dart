import '../models/resilience_report.dart';
import '../models/soil_layer.dart';
import 'resilience_assessment.dart';
import 'soc_calculator.dart';

/// 第五章 5.1 口径的恢复力评估引擎。
///
/// 所有数值均来自现有三维查表数据与统一容重换算：
/// - 分层证据：式 5-1 单层碳库 + 同层 CK 静态差；
/// - 剖面亏缺：式 5-2 累加后的 0-60cm 静态差，÷20 为折算代理（非逐年模型）；
/// - 情景覆盖：式 5-5 秸秆碳输入与年化亏缺代理的算术比较，
///   仅表示管理输入量级关系，不构成 SOC 增量预测。
/// 返回 null 表示剖面校验失败，无法给出恢复力结论。
ResilienceReport? assessResilienceReport(
  String fert,
  int erosion,
  double bd, {
  double cropBiomass = 0,
  double strawCarbonRatio = 0,
  double litterCarbonInput = 0,
}) {
  final currentLayers = buildProfileLayers(fert, erosion, bd);
  final ckLayers = buildProfileLayers(fert, 0, bd);

  double poolOf(List<SoilLayer> layers, String layerId) {
    final match = layers.firstWhere(
      (l) => l.layerId == layerId,
      orElse: () => throw ArgumentError('未知土层：$layerId'),
    );
    return computeCarbonPoolByLayer(
      match.socValue,
      match.bd,
      match.thickness,
    );
  }

  final layerEvidence = <LayerResilience>[];
  for (final layer in currentLayers) {
    final ck = ckLayers.firstWhere((l) => l.layerId == layer.layerId);
    final pool = poolOf(currentLayers, layer.layerId);
    final ckPool = poolOf(ckLayers, layer.layerId);
    final lossRate = ck.socValue <= 0
        ? 0.0
        : ((ck.socValue - layer.socValue) / ck.socValue * 100).clamp(
            0,
            double.infinity,
          );
    layerEvidence.add(
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

  // 薄弱层 = 相对同层 CK 碳库差最小的土层。
  var weakest = layerEvidence.first;
  for (final e in layerEvidence) {
    if (e.poolDifference < weakest.poolDifference) weakest = e;
  }

  double pool060(List<SoilLayer> layers) => layers
      .map((l) => computeCarbonPoolByLayer(l.socValue, l.bd, l.thickness))
      .fold<double>(0, (a, b) => a + b);

  final currentProfile = pool060(currentLayers);
  final ckProfile = pool060(ckLayers);
  final deficit = currentProfile - ckProfile;
  final annualized = deficit / 20;

  final deficits = <ErosionDeficit>[];
  for (final level in kErosionLevels) {
    final levelLayers = buildProfileLayers(fert, level, bd);
    final levelPool = pool060(levelLayers);
    final levelDeficit = levelPool - ckProfile;
    deficits.add(
      ErosionDeficit(
        erosionCm: level,
        pool060: levelPool,
        ckPool060: ckProfile,
        deficit: levelDeficit,
        annualizedDeficit: levelDeficit / 20,
      ),
    );
  }
  deficits.sort((a, b) => a.erosionCm.compareTo(b.erosionCm));

  final scenarios = computeStrawScenarios(
    cropBiomass,
    strawCarbonRatio,
    litterCarbonInput,
  );
  // 覆盖比较只针对秸秆输入与亏缺量级：凋落物是本底输入，不计入覆盖能力。
  final absAnnualized = annualized.abs();
  final coverages = scenarios.map((s) {
    final margin = s.strawInput - absAnnualized;
    final ratio = absAnnualized <= 0
        ? 1.0
        : (s.strawInput / absAnnualized).clamp(0.0, 1.0).toDouble();
    return ScenarioCoverage(
      label: s.label,
      returnRatio: s.returnRatio,
      strawInput: s.strawInput,
      coverageMargin: margin,
      coverageRatio: ratio,
    );
  }).toList();

  final best = coverages.fold<ScenarioCoverage>(coverages.first, (a, b) {
    return b.coverageMargin > a.coverageMargin ? b : a;
  });

  String level;
  String text;
  if (annualized >= 0) {
    level = 'covering';
    text = '当前 0-60cm 剖面碳库不低于同施肥 CK，未出现剖面亏缺；'
        '秸秆还田情景用于维持或增加碳输入。';
  } else if (best.coverageMargin >= 0) {
    level = 'covering';
    text = '剖面年化亏缺代理 ${absAnnualized.toStringAsFixed(3)} kg C/m²/yr；'
        '${best.label}的秸秆碳输入（${best.strawInput.toStringAsFixed(3)} kg C/m²/yr）'
        '在量级上可覆盖该亏缺代理。';
  } else if (best.coverageRatio > 0) {
    level = 'partial';
    text = '剖面年化亏缺代理 ${absAnnualized.toStringAsFixed(3)} kg C/m²/yr；'
        '最高档 ${best.label}仅覆盖约 ${(best.coverageRatio * 100).toStringAsFixed(0)}%，'
        '建议评估额外有机物料投入。';
  } else {
    level = 'deficit';
    text = '当前情景参数下秸秆碳输入为零，无法评估覆盖能力；'
        '请填写秸秆生物量与碳含量后重新评估。';
  }

  return ResilienceReport(
    layers: layerEvidence,
    weakestLayerId: weakest.layerId,
    profileDeficit: deficit,
    annualizedDeficit: annualized,
    erosionDeficits: deficits,
    scenarioCoverages: coverages,
    conclusionLevel: level,
    conclusionText: text,
  );
}
