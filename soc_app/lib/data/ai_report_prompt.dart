const String defaultPrompt = '''你是一位土壤学专家。请根据以下土壤有机碳(SOC)评估数据，生成一份专业的中文土壤碳库恢复力评估报告：

计算参数：
- 施肥处理：${r'${fert}'}
- 侵蚀强度：${r'${erosion}'} cm
- 土壤容重：${r'${bd}'} g/cm³
- pH值：${r'${ph}'}
- 含水量：${r'${wc}'}%
- 黏+粉粒含量：${r'${clay}'}%
- 全氮含量：${r'${tn}'}%
- 秸秆生物量：${r'${cropBiomass}'} kg/ha
- 秸秆碳含量比例：${r'${strawCarbonRatio}'}

计算结果：
- SOC含量：${r'${soc}'} g/kg
- 碳库储量：${r'${carbonStorage}'} kg C/m²
- 碳密度：${r'${carbonDensity}'} kg C/m³
- 碳库净变化量：${r'${netChange}'} kg C/m²
- 年恢复速率：${r'${recoveryRate}'} kg C/m²/年
- SOC损失率：${r'${lossRate}'}%

请包含以下内容：
1. 数据解读 — 当前碳库状况
2. 侵蚀影响评估
3. 未来种植建议
4. 土壤恢复力综合评价''';

const Map<String, String> fertLabels = {
  'F': '施肥',
  'UNF': '不施肥',
};

String fillPrompt(String template, Map<String, dynamic> data) {
  var result = template;
  final replacements = {
    r'${fert}': fertLabels[data['fert']] ?? (data['fert']?.toString() ?? ''),
    r'${erosion}': data['erosion']?.toString() ?? '',
    r'${bd}': data['bd']?.toString() ?? '',
    r'${ph}': data['ph']?.toString() ?? '',
    r'${wc}': data['wc']?.toString() ?? '',
    r'${clay}': data['clay']?.toString() ?? '',
    r'${tn}': data['tn']?.toString() ?? '',
    r'${cropBiomass}': data['cropBiomass']?.toString() ?? '',
    r'${strawCarbonRatio}': data['strawCarbonRatio']?.toString() ?? '',
    r'${soc}': data['soc']?.toString() ?? '',
    r'${carbonStorage}': data['carbonStorage']?.toString() ?? '',
    r'${carbonDensity}': data['carbonDensity']?.toString() ?? '',
    r'${netChange}': data['netChange']?.toString() ?? '',
    r'${recoveryRate}': data['recoveryRate']?.toString() ?? '',
    r'${lossRate}': data['lossRate']?.toString() ?? '',
  };
  for (final e in replacements.entries) {
    result = result.replaceAll(e.key, e.value);
  }
  return result;
}
