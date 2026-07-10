# 碳盾 SOC-Shield — 问题与 Bug 报告（v1.1.3）

> 基于对 `soc_app/` 源码的静态审查。每条均给出**位置**、**现象/原因**、**影响**、**建议修复**。
>
- 严重度：🔴 高（功能性错误/数据失真）　🟠 中（体验/语义误导）　🟡 低（健壮性/小瑕疵）
- 分类：A＝逻辑 Bug，B＝语义/单位误导，C＝体验问题，D＝健壮性/性能

---

## 一、隐藏 Bug（源码级，未被测试覆盖）

### A1 🔴 思考模式 `reasoning_content` 被完全丢弃，"思考过程"永不显示

- **位置**：[ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart) `_streamResponse()`（L113-126）；[ai_report_provider.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/providers/ai_report_provider.dart) `AiReportState.reasoningContent`；[ai_report_card.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/widgets/ai_report_card.dart) L50-64
- **现象**：DeepSeek 思考模式开启后，响应流里 `delta.reasoning_content` 字段从未被解析；`AiReportService` 只 `yield` `delta.content`。`AiReportState.reasoningContent` 永远为 `null`，`AiReportCard` 的"思考过程" `ExpansionTile` 永不渲染。`AiReportResponse.reasoningContent` 字段是死代码。
- **原因**：解析逻辑只读了 `content`：
  ```dart
  final content = chunk['choices']?[0]?['delta']?['content'] as String?;
  if (content != null && content.isNotEmpty) { yield content; }
  ```
  缺少对 `delta['reasoning_content']` 的提取，且 `Stream<String>` 单返回类型无法承载两路数据。
- **影响**：设置页宣称"模型在回答前进行深度推理""响应中包含 reasoning_content 字段在 UI 中折叠显示"——实际功能不存在；用户开了思考模式只见正文，推理过程完全不可见，却要为推理消耗的 token 付费。
- **测试盲区**：[ai_report_service_test.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/test/ai_report_service_test.dart) 的"思考模式新增 extraThinkingBody"只断言请求体，未覆盖 `reasoning_content` 响应解析。
- **建议修复**：把 `generateStream` 返回类型改为 `Stream<AiReportChunk>`（含 `content` 与 `reasoningContent`），在循环里分别提取两个字段并 yield；`AiReportNotifier` 用两个 `StringBuffer` 分别累积并 `copyWith` 更新 `reasoningContent`。

### A2 🔴 `netChange20yr` 与 `netChange100yr` 深度池交叉错配

- **位置**：[resilience_assessment.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/resilience_assessment.dart) L65-67
- **现象**：
  ```dart
  final netChange20yr  = computeNetChange(finalPool060, initialPool060); // 用 0-60cm 池
  final netChange100yr = computeNetChange(finalPool020, initialPool020); // 用 0-20cm 池
  ```
  20 年净变化用了**更深**的 0-60cm 池，100 年净变化反而用了**更浅**的 0-20cm 池。且与同函数 `recoveryRate = computeAnnualRecoveryRate(finalPool060, initialPool060, 20)` 不一致——`recoveryRate` 用 060 池算 20 年，而 `netChange20yr` 也用 060 池算 20 年，但 `netChange100yr` 却换成了 020 池，三者口径不统一。
- **影响**：PDF 恢复力表与对比页把这两个值标为"20年净变化量""100年净变化量"，数值与标签不匹配，专家用户会得到违背直觉的结论（100 年变化反而比 20 年小）。本质上是标签/池的错配 Bug。
- **建议修复**：统一口径。若"20yr/100yr"指时间尺度，则两者应使用同一深度池（或明确文档说明各对应哪个池）；当前最可能的本意是 `netChange20yr` 用 020、`netChange100yr` 用 060，即两行赋值应互换。

### A3 🟠 `calculateNetChange` 语义与单位不符——"净变化量"实为调整后 SOC 绝对值

- **位置**：[soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart) L88-92；显示于 [home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L423-430 与 [pdf_exporter.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/pdf_exporter.dart) L134
- **现象**：`calculateNetChange` 返回 `soc * (1 + fertImpact - erosionImpact)`，是 SOC 量级（g/kg）的绝对值，并非"变化量"（delta）。黄金数据集 F/0/10：`soc=23.9`、`netChange=25.09`、`carbonStorage=3.11`。但 UI/PDF 把它标成 `kg C/m²` 单位的"净变化量"，于是出现"净变化量(25.09 kg C/m²) ≫ 碳库储量(3.11 kg C/m²)"的荒谬对比。
- **影响**：单位与量纲错误，误导用户与 AI（提示词里也把该值当作 `kg C/m²` 喂给模型，可能让 AI 产生错误解读）。属于数据正确性问题。
- **建议修复**：要么改实现为真正的差量（如 `碳库储量 - 基准碳库储量`，单位 kg C/m²），要么改标签/单位为"g/kg 修正 SOC"并同步提示词模板。

### A4 🟠 `calculateRecoveryRate` 与 `calculateLossRate` 用 `clamp(0, ∞)` 吞掉负值

- **位置**：[soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart) L96、L124
- **现象**：
  - `calculateRecoveryRate`：`(netChange/years).clamp(0, ∞)`——当净变化为负（碳库亏损）时恢复速率显示为 0；
  - `calculateLossRate`：`((base-soc)/base*100).clamp(0, ∞)`——当 SOC 高于基准（碳积累）时损失率显示为 0%。
- **影响**：退化场景被粉饰为"零恢复"，增长场景被粉饰为"零损失"，用户看不到真实的负向/正向幅度。`computeAnnualRecoveryRate`（resilience 层）反而未 clamp，两个"恢复速率"行为不一致。
- **建议修复**：移除 clamp 或改为带符号展示，UI 用颜色/箭头区分增减；至少保证两处恢复速率口径一致。

### A5 🟠 `splitToLayers` 给所有分层填同一 SOC/容重，分层碳库退化为等比缩放

- **位置**：[soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart) L99-119；调用点 [calculator_provider.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/providers/calculator_provider.dart) L123、L136
- **现象**：`splitToLayers(soc, bd, depth)` 把表层 `0-20` 与下层 `20-depth` 都设成相同 `socValue` 与 `bd`。真实 SOC 随深度递减（基础数据表本身也是深度递减的），但分层计算却假设全剖面 SOC 恒定。
- **影响**：`assessResilience` 的分层碳库、0-20/0-60 池差异主要来自"厚度不同"而非"SOC 不同"，弱化了深度维度的科学性；与图表（深度折线图）展示的"SOC 随深度变化"自相矛盾。
- **建议修复**：按深度查表分配各层 SOC（参考 `_baseData[fert][erosion][depth]` 的分层取值），或至少用衰减系数。

### A6 🟡 版本号不一致：设置页显示 1.1.2，实际为 1.1.3

- **位置**：[settings_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/settings/settings_page.dart) L8 `final _kVersion = '1.1.2';`；[pubspec.yaml](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/pubspec.yaml) `version: 1.1.3`
- **影响**：关于页显示陈旧版本号，用户报障时对不上实际版本。
- **建议修复**：从 `package_info_plus` 读取运行时版本，或常量同步为 `1.1.3`。

### A7 🟡 `getAll` 内存切片分页，数据量大时性能/内存恶化

- **位置**：[record_dao.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/record_dao.dart) L64-82
- **现象**：`query.get()` 一次性把全部行拉进内存，再用 `rows.sublist(start, end)` 切片。`limit`/`offset` 没有下推到 SQL。
- **影响**：历史记录累积到上千条后，每次进历史页都要全表解码，卡顿且占内存。
- **建议修复**：用 Drift 的 `..limit(limit, offset: offset)` 下推到 SQL。

---

## 二、影响使用体验的问题

### C1 🟠 草稿"忽略"不删除，每次启动反复弹窗

- **位置**：[home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) `_checkDraft()` L542-573
- **现象**：草稿超过 5 分钟会被静默删除；但若未过期且用户点"忽略"，草稿保留，下次启动还会再弹。没有"不再提醒"或"丢弃草稿"选项。
- **影响**：用户每次冷启动都被打扰，直到草稿自然过期。
- **建议修复**："忽略"同时删除草稿，或记录"已忽略"标记避免重复弹窗。

### C2 🟠 对比页雷达图硬编码只画前 2 条记录

- **位置**：[compare_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/compare/compare_page.dart) L146-151
- **现象**：允许勾选最多 5 条记录，参数/结果/恢复力表格也支持多列，但 `ComparisonRadarChart(result1: records[0], result2: records[1])` 只叠加前两条。
- **影响**：勾选 3+ 条时雷达图与表格信息不一致，用户以为雷达图含全部记录，实则遗漏。
- **建议修复**：要么雷达图支持 N 数据集，要么明确提示"雷达图仅对比前两条"。

### C3 🟠 AI 报告空闲超时静默中断，无任何反馈

- **位置**：[ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart) L84-90、L127-129
- **现象**：60s 空闲计时器触发 `cancelToken.cancel()`，被 `DioExceptionType.cancel` 捕获后 `return`（静默）。`AiReportNotifier` 不会收到错误，状态停在 `isGenerating=false` + 已累积的半截 `streamContent`，没有"已超时"提示。
- **影响**：网络卡顿时用户看到生成"自然停止"，以为报告写完了，实际是被掐断的半截内容。
- **建议修复**：超时分支显式抛出超时异常，由 Notifier 映射为"请求超时，已生成内容可能不完整"。

### C4 🟠 历史导入逐条 insert，无批量/无去重/无进度

- **位置**：[history_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/history/history_page.dart) `_importRecords()` L70-78
- **现象**：`for (final r in records) await dao.insert(...)` 串行写入，无事务、无批量、无去重、无进度条。导入大文件时界面无响应且可能重复入库。
- **建议修复**：用 `db.batch` 批量插入；按 `(params, createdAt)` 或用户选择去重；导入中显示进度。

### C5 🟡 `_syncCtrlsFromParams` 字段填充条件不一致

- **位置**：[home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L76-84
- **现象**：`hasData = params.bd > 0`；`bd`/`ph` 各自按自身 `>0` 判断，而 `wc`/`clay`/`tn`/`cropBiomass` 统一按 `hasData`（即 bd）判断。
- **影响**：若草稿里 `bd=0` 但 `wc=30`，含水量框显示空，用户以为该字段没填过；条件不一致易引发"明明填过却没回填"的困惑。
- **建议修复**：每个字段按自身是否 `>0`（或非默认值）判断回填。

### C6 🟡 `calculateCarbonStorage` 截断到 20cm，与"取样深度"语义脱节

- **位置**：[soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart) L78-81
- **现象**：无论用户取样 25/35/45/55 cm，碳库储量都只按 20cm 计算（`(depth<20?depth:20)`）。
- **影响**：用户选了 55cm 取样深度，"碳储量"却只反映表层 20cm，且 UI 不提示该截断，易误解为全剖面储量。
- **建议修复**：要么按实际深度算，要么在结果区明确标注"碳库储量(0-20cm 表层)"。

### C7 🟡 AI 报告未配置 Key 时，配置后仍可能以空 Key 请求

- **位置**：[home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) `_generateReport()` L577-600
- **现象**：检测到无 Key 时跳设置页；返回后未重新校验 `configured`，紧接着 `apiKey: await service.readApiKey() ?? ''`。若 secure_storage 读取失败或用户未填就返回，会用空 Key 发请求，得到 401 而非友好提示。
- **建议修复**：保存后再次校验 `apiKey` 非空，否则提示"未检测到 API Key"。

### C8 🟡 字段输入框非空才更新，清空时旧值残留

- **位置**：[home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) `_buildTextField` onChanged L677-680
- **现象**：`double.tryParse(v)` 为 null 时不调用 `onChanged`，即用户清空输入框时模型仍保留上一个有效值。
- **影响**：用户删掉内容以为"清零了"，实际计算仍用旧值，且不会触发校验错误。
- **建议修复**：空串时显式置 0 或标记为"未输入"并触发校验。

### C9 🟡 提示词模板缺失恢复力/秸秆数据，AI 报告信息不全

- **位置**：[ai_report_prompt.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_prompt.dart) `defaultPrompt`
- **现象**：`defaultPrompt` 只含 9 个参数 + 6 个结果指标，未包含 `ResilienceResult`（碳库 0-20/0-60、20/100 年净变化、秸秆情景、恢复状态）。`systemPrompt` 却要求 AI 做"土壤恢复力综合评价"。
- **影响**：AI 在缺数据的情况下"凭空"评价恢复力，结论可信度低。
- **建议修复**：在 `fillPrompt` 与模板里补齐恢复力字段（`${carbonPool020}`、`${status}` 等）。

### C10 🟡 删除历史记录无二次确认

- **位置**：[history_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/history/history_page.dart) L154-162
- **现象**：列表项垃圾桶图标点击即删，无确认对话框，误触即丢数据。
- **建议修复**：加 `AlertDialog` 二次确认，或提供撤销 SnackBar。

### C11 🟡 草稿恢复无 diff 预览，直接覆盖当前表单

- **位置**：[home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L569-572
- **现象**：点"恢复"后直接 `loadDraft(draft)` + 同步控制器，若当前已有输入会被静默覆盖。
- **建议修复**：恢复前展示草稿摘要或确认提示。

---

## 三、健壮性与小瑕疵

### D1 🟡 `JsonIo.importFromFile` 未校验 `version` 与结构

- **位置**：[json_io.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/json_io.dart) L69-84
- **现象**：直接 `json['records'] as List`，若文件结构异常（非本系统导出）会抛异常，仅靠上层 `try/catch` 兜底显示"导入失败"。
- **建议修复**：校验 `version`/`records` 字段存在性，给出"文件格式不符"的明确提示。

### D2 🟡 `assessResilience` 用 `layerId` 字符串前缀判深度，脆弱

- **位置**：[resilience_assessment.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/resilience_assessment.dart) L50-57
- **现象**：`layerStart(layerId)` 取 `'0-20'` 的首段 `int.parse`，但 `splitToLayers` 产生的 id 是 `'0-20'`/`'20-60'`；若未来 id 改为 `'20-40'` 仍可工作，但任何非数字前缀（如 `'A层'`）会静默回退 0，导致该层被错误归入"0-20 池"。
- **建议修复**：在 `SoilLayer` 增加 `depthStart` 数值字段，避免字符串解析。

### D3 🟡 PDF 字体用完整 `SimHei.ttf` 而非子集

- **位置**：[pubspec.yaml](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/pubspec.yaml) assets `assets/fonts/SimHei.ttf`；[pdf_exporter.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/pdf_exporter.dart) L21
- **现象**：DOCUMENTATION.md 与 AGENTS.md 称使用子集化字体(~0.9MB)，但实际打包的是完整 `SimHei.ttf`（约 9.7MB），增大 APK/Windows 包体积。
- **建议修复**：替换为子集化字体文件并更新 assets 路径。

### D4 🟡 `computeAnnualRecoveryRate` 未除零保护

- **位置**：[resilience_assessment.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/resilience_assessment.dart) L19-21
- **现象**：`(poolCurrent - poolPrevious) / years`，若调用方传 `years=0` 会抛 `IntegerDivisionByZeroException`（当前内部固定传 20，暂未触发，但函数是 public 的扩展点）。
- **建议修复**：`years <= 0` 时返回 0 或抛明确异常。

### D5 🟡 AI 请求无 `max_tokens` 限制

- **位置**：[ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart) L63-78
- **现象**：AGENTS.md 标注 v1.1.3 移除了 `max_tokens`。长报告会拉高单次请求成本与时长，且无截断保护。
- **建议修复**：提供可选的 `max_tokens` 配置项，默认给一个合理上限。

### D6 🟡 `AiConfigService` 读取失败降级为 null/默认值，但用户无感知

- **位置**：[ai_config_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_config_service.dart) `readApiKey` 等 L78-94
- **现象**：secure_storage 抛异常被 `catch (_) {}` 吞掉返回 null。若 Keystore/DPAPI 损坏，用户每次"生成报告"都被引导去配置页，但配置页里 Key 框可能是空（读不回来），用户陷入死循环且无错误提示。
- **建议修复**：捕获异常时上报到 UI（如 SnackBar "密钥读取失败，请重新输入"）。

### D7 🟡 测试覆盖盲区

- **位置**：[test/](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/test/)
- **现象**：无 Widget 测试（HomePage 草稿恢复、PDF 导出、ComparePage 多选），无 `AiConfigService` 加密存储测试，AI Service 未覆盖 `reasoning_content` 解析（见 A1）、未覆盖空闲超时分支（见 C3）。`resilience_assessment_test.dart` 只断言 `success`/`status` 文案，未断言 `netChange20yr/100yr` 数值，故 A2 未被发现。
- **建议修复**：补足上述断言；为恢复力数值加黄金数据集测试。

---

## 四、优先级建议

| 优先级 | 条目 | 理由 |
|---|---|---|
| P0 立即修 | A1、A2、A3 | 数据正确性与功能缺失，直接影响专业可信度 |
| P1 近期修 | A4、A5、C3、C9 | 影响结果解读与 AI 报告质量 |
| P2 排期修 | A6、C1、C2、C4、C7、C10 | 体验与健壮性 |
| P3 改进项 | A7、C5、C6、C8、C11、D1-D7 | 性能与代码质量 |
