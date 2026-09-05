import 'soc_calculator.dart';
import '../models/calculation_result.dart';
import '../models/resilience_result.dart';

/// 图表叙事文案生成器：所有结论均由当次计算的真实数据推导，
/// 不使用与数据无关的模板腔。每条结论包含可核验的关键数字。
class ChartNarrative {
  ChartNarrative._();

  /// 侵蚀图（0-20cm SOC 随侵蚀等级的变化）。
  static String erosionCurve({
    required String fert,
    required int currentErosion,
  }) {
    final soc0 = calculateSOCValue(fert, 0, 10);
    final socCurrent = calculateSOCValue(fert, currentErosion, 10);
    // 找出曲线中的非单调点，用于提示“侵蚀等级不是严格梯度”。
    final values = [
      for (final e in kErosionLevels) calculateSOCValue(fert, e, 10),
    ];
    final nonMonotonic = <int>[];
    for (var i = 1; i < values.length - 1; i++) {
      if ((values[i] - values[i - 1]) * (values[i + 1] - values[i]) < 0) {
        nonMonotonic.add(kErosionLevels.elementAt(i));
      }
    }
    final dropPct = soc0 <= 0
        ? 0.0
        : ((soc0 - socCurrent) / soc0 * 100).clamp(0, double.infinity);
    final buffer = StringBuffer(
      '当前 ${currentErosion}cm 处表层 SOC 为 ${socCurrent.toStringAsFixed(1)} g/kg，'
      '较 CK（${soc0.toStringAsFixed(1)}）降低 ${dropPct.toStringAsFixed(0)}%。',
    );
    if (nonMonotonic.isNotEmpty) {
      buffer.write(
        ' 注意：${nonMonotonic.join('、')}cm 处出现局部回升，'
        '说明该数据集的侵蚀等级不构成严格单调梯度。',
      );
    }
    return buffer.toString();
  }

  /// 深度图（当前剖面 vs CK 剖面的垂直分布）。
  static String depthProfile({
    required String fert,
    required int erosion,
    required double bd,
  }) {
    final layers = kSoilDepthDefinitions.toList();
    final diffs = <({String id, double pct})>[];
    for (final layer in layers) {
      final cur = calculateSOCValue(fert, erosion, layer.key);
      final ck = calculateSOCValue(fert, 0, layer.key);
      if (ck > 0) {
        diffs.add((
          id: layer.layerId,
          pct: (cur - ck) / ck * 100,
        ));
      }
    }
    diffs.sort((a, b) => a.pct.compareTo(b.pct));
    final worst = diffs.first;
    final best = diffs.last;
    return '亏缺最深的土层是 ${worst.id}cm（较同层 CK 低 '
        '${(-worst.pct).toStringAsFixed(0)}%），最接近 CK 的是 '
        '${best.id}cm（${best.pct >= 0 ? '+' : ''}${best.pct.toStringAsFixed(0)}%）。'
        '垂直分布差异说明侵蚀影响不随深度均匀衰减。';
  }

  /// 对比图（当前侵蚀与 CK 的五层对照）。
  static String comparisonFill({
    required String fert,
    required int erosion,
  }) {
    double pool060(int e) => kSoilDepthDefinitions
        .map((l) => calculateSOCValue(fert, e, l.key) * l.thicknessCm)
        .fold<double>(0, (a, b) => a + b);
    final cur = pool060(erosion);
    final ck = pool060(0);
    final pct = ck <= 0 ? 0.0 : (cur - ck) / ck * 100;
    return '按浓度直接累加（未乘容重），当前侵蚀处理剖面合计较 CK '
        '${pct >= 0 ? '高' : '低'} ${pct.abs().toStringAsFixed(1)}%；'
        '正式碳库结论以评估页的容重换算为准。';
  }

  /// 热力图（侵蚀 × 土层矩阵）。
  static String heatmap({required String fert}) {
    // 找矩阵中的极值单元格，给用户一个“看哪里”的锚点。
    var maxV = -1.0;
    var minV = double.infinity;
    int maxE = 0, maxD = 0, minE = 0, minD = 0;
    for (final e in kErosionLevels) {
      for (final d in kSoilDepthKeys) {
        final v = calculateSOCValue(fert, e, d);
        if (v > maxV) {
          maxV = v;
          maxE = e;
          maxD = d;
        }
        if (v < minV) {
          minV = v;
          minE = e;
          minD = d;
        }
      }
    }
    return '矩阵峰值 ${maxV.toStringAsFixed(1)} g/kg 出现在侵蚀 ${maxE}cm × '
        '土层键 $maxD，谷值 ${minV.toStringAsFixed(1)} g/kg 在侵蚀 ${minE}cm × '
        '土层键 $minD；颜色只反映相对高低，读数以单元格为准。';
  }

  /// 秸秆情景图（三档碳输入）。
  static String strawScenario(ResilienceResult? resilience) {
    if (resilience == null || resilience.strawScenarios.isEmpty) {
      return '未生成情景数据；请在评估条件中填写秸秆参数后重新计算。';
    }
    final full = resilience.strawScenarios.last;
    final base = resilience.strawScenarios.first;
    final ratio = base.strawInput <= 0
        ? 0.0
        : full.strawInput / base.strawInput;
    return '从 30% 提高到 100% 还田，秸秆碳输入由 '
        '${base.strawInput.toStringAsFixed(3)} 增至 '
        '${full.strawInput.toStringAsFixed(3)} kg C/m²（约 ${ratio.toStringAsFixed(1)} 倍）；'
        '凋落物底段不变，增量全部来自秸秆段。';
  }

  /// 评估雷达（归一化展示的免责化结论）。
  static String assessmentRadar(CalculationResult result) {
    return 'SOC ${result.soc.toStringAsFixed(1)} g/kg、损失率 '
        '${result.lossRate.toStringAsFixed(1)}%；五边形形状由不同量纲归一化而来，'
        '只用于同屏观察相对位置，不代表综合评分。';
  }

  /// 组成图（各层碳库占比）。
  static String poolComposition({
    required String fert,
    required int erosion,
    required double bd,
  }) {
    final pools = [
      for (final l in kSoilDepthDefinitions)
        calculateSOCValue(fert, erosion, l.key) * l.thicknessCm,
    ];
    final total = pools.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return '剖面碳库合计为零，无法计算占比。';
    var maxIdx = 0;
    for (var i = 1; i < pools.length; i++) {
      if (pools[i] > pools[maxIdx]) maxIdx = i;
    }
    final top = kSoilDepthDefinitions[maxIdx];
    final share = pools[maxIdx] / total * 100;
    // 表层(0-20)厚度是其他层的两倍，占比高是几何必然，要明说。
    return '${top.layerId}cm 贡献剖面碳库的 ${share.toStringAsFixed(0)}%；'
        '表层厚度（20cm）是其余各层（10cm）的两倍，'
        '占比差异同时来自厚度与 SOC 浓度，不能只读作浓度差异。';
  }

  /// 关联图（侵蚀 × SOC 散点分布）。
  static String correlation({required String fert}) {
    final pairs = [
      for (final e in kErosionLevels) (e: e, v: calculateSOCValue(fert, e, 10)),
    ];
    // Spearman-style 符号判断：正序对 vs 逆序对。
    var concordant = 0;
    var discordant = 0;
    for (var i = 0; i < pairs.length; i++) {
      for (var j = i + 1; j < pairs.length; j++) {
        final dE = pairs[j].e.compareTo(pairs[i].e);
        final dV = pairs[j].v.compareTo(pairs[i].v);
        if (dE * dV > 0) {
          concordant++;
        } else if (dE * dV < 0) {
          discordant++;
        }
      }
    }
    final total = concordant + discordant;
    final tau = total == 0 ? 0.0 : (concordant - discordant) / total;
    final dir = tau < -0.3
        ? '整体呈负向（侵蚀越深表层 SOC 越低）'
        : tau > 0.3
        ? '整体呈正向'
        : '方向不一致';
    return '28 组等级对中，$dir（秩相关 τ≈${tau.toStringAsFixed(2)}）。'
        '这是分布描述，不构成因果结论。';
  }

  /// 结果摘要卡：把四个关键指标合成一句话（AI 页与结果区共用）。
  static String oneLineSummary({
    required String fertLabel,
    required int erosion,
    required String layerLabel,
    required CalculationResult result,
    required ResilienceResult? resilience,
  }) {
    final direction = result.netChange >= 0 ? '高于' : '低于';
    final profileText = resilience == null
        ? ''
        : '；剖面（0-60cm）相对 CK '
            '${resilience.netChange20yr >= 0 ? '高于' : '低于'} '
            'CK ${resilience.netChange20yr.abs().toStringAsFixed(2)} kg C/m²';
    return '$fertLabel、侵蚀 ${erosion}cm、$layerLabel：'
        'SOC ${result.soc.toStringAsFixed(2)} g/kg，碳库 '
        '${result.carbonStorage.toStringAsFixed(2)} kg C/m²，'
        '较同层 CK $direction ${result.netChange.abs().toStringAsFixed(2)} kg C/m²'
        '$profileText。';
  }
}
