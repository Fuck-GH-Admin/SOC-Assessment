const String systemPrompt =
    '''你是一位土壤学专家。请根据用户提供的土壤有机碳（SOC）评估数据，生成一份专业的中文土壤碳库评估报告。

请包含以下内容：
1. 数据解读 — 当前碳库状况
2. 侵蚀影响评估
3. 秸秆还田情景建议
4. 相对CK静态差异综合评价

要求：
- 严格使用用户给出的单位和指标口径；
- 明确区分实测数据表、辅助观测参数和管理情景参数；
- 当前没有逐年模拟末期数据，所有“20年/100年”字段只是沿用源文档分析范围的静态CK差异口径，不得表述为真实时间序列预测或已观测恢复趋势。''';

const String defaultPrompt =
    '''计算参数：
- 算法口径：v${r'${algorithmVersion}'}
- 施肥处理：${r'${fert}'}
- 侵蚀强度：${r'${erosion}'} cm
- 当前土层：${r'${depthLabel}'}
- 统一土壤容重：${r'${bd}'} g/cm^3

辅助观测参数（未进入当前SOC查表与碳库换算公式，仅供解释）：
- pH值：${r'${ph}'}
- 含水量：${r'${wc}'}%
- 黏+粉粒含量：${r'${clay}'}%
- 全氮含量：${r'${tn}'} g/kg

秸秆情景参数：
- 秸秆生物量：${r'${cropBiomass}'} kg/ha
- 秸秆碳含量比例：${r'${strawCarbonRatio}'}
- 基础凋落物碳输入：${r'${litterCarbonInput}'} kg C/m^2

当前土层计算结果：
- SOC含量：${r'${soc}'} g/kg
- 当前土层碳库储量：${r'${carbonStorage}'} kg C/m^2
- 当前土层碳密度：${r'${carbonDensity}'} kg C/m^3
- 当前土层相对同施肥CK碳库差：${r'${layerPoolDifference}'} kg C/m^2
- 当前土层差值/20年（折算代理）：${r'${layerAnnualizedDifference}'} kg C/m^2/yr
- 当前土层相对同施肥CK损失率：${r'${lossRate}'}%

CK参考静态差异结果（当前没有逐年模拟末期数据，不得表述为真实时间趋势）：
- 表层碳库（0-20cm）：${r'${carbonPool020}'} kg C/m^2
- 剖面碳库（0-60cm）：${r'${carbonPool060}'} kg C/m^2
- 0-60cm相对CK碳库差（源文档20年分析范围）：${r'${netChange20yr}'} kg C/m^2
- 0-20cm相对CK碳库差（源文档100年分析范围）：${r'${netChange100yr}'} kg C/m^2
- 0-60cm差值/20年（折算代理）：${r'${recoveryRateAnnual}'} kg C/m^2/yr
- 相对CK状态：${r'${resilienceStatus}'}

秸秆还田情景：
${r'${strawScenarios}'}''';

const Map<String, String> fertLabels = {'F': '施肥', 'UNF': '不施肥'};

String fillPrompt(String template, Map<String, dynamic> data) {
  var result = template;
  final replacements = {
    r'${algorithmVersion}': data['algorithmVersion']?.toString() ?? '',
    r'${fert}': fertLabels[data['fert']] ?? (data['fert']?.toString() ?? ''),
    r'${erosion}': data['erosion']?.toString() ?? '',
    r'${depthLabel}': data['depthLabel']?.toString() ?? '',
    r'${bd}': data['bd']?.toString() ?? '',
    r'${ph}': data['ph']?.toString() ?? '',
    r'${wc}': data['wc']?.toString() ?? '',
    r'${clay}': data['clay']?.toString() ?? '',
    r'${tn}': data['tn']?.toString() ?? '',
    r'${cropBiomass}': data['cropBiomass']?.toString() ?? '',
    r'${strawCarbonRatio}': data['strawCarbonRatio']?.toString() ?? '',
    r'${litterCarbonInput}': data['litterCarbonInput']?.toString() ?? '',
    r'${soc}': data['soc']?.toString() ?? '',
    r'${carbonStorage}': data['carbonStorage']?.toString() ?? '',
    r'${carbonDensity}': data['carbonDensity']?.toString() ?? '',
    r'${layerPoolDifference}': data['layerPoolDifference']?.toString() ?? '',
    r'${layerAnnualizedDifference}':
        data['layerAnnualizedDifference']?.toString() ?? '',
    r'${lossRate}': data['lossRate']?.toString() ?? '',
    r'${carbonPool020}': data['carbonPool020']?.toString() ?? '',
    r'${carbonPool060}': data['carbonPool060']?.toString() ?? '',
    r'${netChange20yr}': data['netChange20yr']?.toString() ?? '',
    r'${netChange100yr}': data['netChange100yr']?.toString() ?? '',
    r'${recoveryRateAnnual}': data['recoveryRateAnnual']?.toString() ?? '',
    r'${resilienceStatus}': data['resilienceStatus']?.toString() ?? '',
    r'${strawScenarios}': data['strawScenarios']?.toString() ?? '',
  };
  for (final entry in replacements.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}
