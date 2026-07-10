# 碳盾 SOC-Shield — 验证报告与修改建议（v1.1.3）

> 本文是对 [ISSUES_AND_BUGS.md](./ISSUES_AND_BUGS.md) 的验证结果 + 用户新增三个问题的调查结论 + 可落地的代码修改建议。
>
> 每条标注 **✅ 已验证属实** 或修正说明，并给出 **可直接粘贴的代码补丁**。

---

## 第一部分：原报告 A1–A7 验证结果

### A1 ✅ 已验证 — `reasoning_content` 未解析

**验证**：[ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart) L121：

```dart
final content = chunk['choices']?[0]?['delta']?['content'] as String?;
if (content != null && content.isNotEmpty) {
  yield content;
}
```

只读 `delta.content`，从未读 `delta.reasoning_content`。`Stream<String>` 单类型无法承载两路数据。`AiReportState.reasoningContent` 永远为 `null`，`AiReportCard` L50 的 `if (state.reasoningContent != null)` 永远不成立。

**修正说明**：原报告说"思考过程永不显示"不够准确。实际现象是——DeepSeek 思考模式下 `reasoning_content` 被丢弃，但模型的思考内容**有时会混入 `content` 字段**，于是以纯文本形式出现在 `streamContent` 里（报告正文区），**无法折叠**。这正是用户反馈的"思考过程收不起来"的根因。

---

### A2 ✅ 已验证 — `netChange20yr` / `netChange100yr` 深度池交叉

**验证**：[resilience_assessment.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/resilience_assessment.dart) L65-67：

```dart
final netChange20yr  = computeNetChange(finalPool060, initialPool060); // 用 0-60cm
final netChange100yr = computeNetChange(finalPool020, initialPool020); // 用 0-20cm
final recoveryRate   = computeAnnualRecoveryRate(finalPool060, initialPool060, 20); // 用 0-60cm
```

20yr 用深池、100yr 用浅池，且 `recoveryRate`（也是 20yr 口径）用 060 池——三者口径不统一。**属实**。

---

### A3 ✅ 已验证 — `calculateNetChange` 语义不符

**验证**：[soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart) L88-91：

```dart
double calculateNetChange(double soc, String fert, int erosion) {
  final erosionImpact = (erosion / 70) * 0.3;
  final fertImpact = fert == 'F' ? 0.05 : -0.02;
  return soc * (1 + fertImpact - erosionImpact); // 返回调整后绝对值，非差量
}
```

返回值量级是 g/kg（与 soc 同量级），但 [home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L427-428 和 [pdf_exporter.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/pdf_exporter.dart) L134-135 都标成 `kg C/m²`。**属实**。

---

### A4 ✅ 已验证 — `clamp(0, ∞)` 吞掉负值

**验证**：L96 `(netChange / years).clamp(0, double.infinity)`；L124 `((baseSoc - soc) / baseSoc * 100).clamp(0, double.infinity)`。退化被显示为 0。**属实**。

---

### A5 ✅ 已验证 — `splitToLayers` 全剖面填同一 SOC

**验证**：L110-118，`0-20` 层和 `20-depth` 层都用相同的 `socValue` 和 `bd`。**属实**。

---

### A6 ✅ 已验证 — 版本号不一致

**验证**：[settings_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/settings/settings_page.dart) L8 `final _kVersion = '1.1.2';`；[pubspec.yaml](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/pubspec.yaml) `version: 1.1.3`。**属实**。

---

### A7 ✅ 已验证 — `getAll` 内存切片分页

**验证**：[record_dao.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/record_dao.dart) `getAll()` 先 `query.get()` 拉全表，再 `rows.sublist(start, end)` 内存切片。`limit`/`offset` 未下推 SQL。**属实**。

---

## 第二部分：用户新增三个问题 — 调查与验证

### 问题一 ✅ 已验证 — PDF 单位乱码（² ³ 字符缺失）

**根因**：用 Python `fontTools` 解析 `SimHei.ttf` 的 cmap 表，确认以下字符**不在字体中**：

| 字符 | Unicode | 用途 | 状态 |
|------|---------|------|------|
| ² | U+00B2 | `kg C/m²`、`g/cm³`(无)、`m²/yr` | **MISSING** |
| ³ | U+00B3 | `g/cm³`、`kg C/m³` | **MISSING** |
| µ | U+00B5 | 微米等 | **MISSING** |
| • | U+2022 | AI 报告项目符号 | **MISSING** |
|   | U+00A0 | 非断行空格 | **MISSING** |

`g/cm³`、`kg C/m²`、`kg C/m³`、`kg C/m²/yr` 在 PDF 中大量使用（共 14 处），Dart `pdf` 包遇到 cmap 中不存在的字符会渲染为空白方块——这就是用户看到的"单位乱码"。

**额外发现**：字体文件 9.3MB 是完整 SimHei（非 AGENTS.md 声称的子集），增大包体积。

---

### 问题二 ✅ 已验证 — AI 报告排版差

**验证**，发现 4 个具体问题：

1. **Card 套 Card + 标题重复**：[home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L495 外层 `Card`（标题"AI 评估报告" L501），内层 [ai_report_card.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/widgets/ai_report_card.dart) L20 又是 `Card`（标题"AI 评估报告" L32）。双层 Card 边框 + 双标题，视觉沉重。

2. **流式生成时显示原始 Markdown 符号**：L68-70 `isGenerating` 时用 `Text(state.streamContent)` 纯文本渲染，用户会看到 `**加粗**`、`## 标题`、`---` 等原始标记，非常难看。生成结束后才切换为 `MarkdownBody`。

3. **Markdown 样式过于简陋**：L73-77 `MarkdownStyleSheet` 只配了 `p`/`h1`/`h2`，缺少 `h3`/列表/代码块/引用块/表格/分割线样式。

4. **长报告无滚动容器**：报告内容直接放在 `Column` 里，超长时溢出而非滚动。

---

### 问题三 ✅ 已验证 — 思考过程无法折叠

**验证**：这是 A1 的直接后果。`reasoningContent` 永远为 `null`（因为 service 不解析 `delta.reasoning_content`），所以 L50 的 `ExpansionTile`（可折叠的"思考过程"区块）**永不渲染**。用户看到的思考内容混在 `streamContent` 正文里，作为 `Text`/`MarkdownBody` 展示，没有折叠控件——"收不起来"。

---

## 第三部分：修改建议（含代码补丁）

### 修复 1：PDF 单位乱码 — 替换 Unicode 上标为普通 ASCII

**方案**：把 ² ³ 替换为 `^2` `^3`（科学界通用写法），零字体依赖，改动最小。

**改动文件**：[pdf_exporter.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/pdf_exporter.dart)

```dart
// _paramTable L102：
['土壤容重', params.bd.toStringAsFixed(2), 'g/cm³'],
// 改为：
['土壤容重', params.bd.toStringAsFixed(2), 'g/cm^3'],

// _resultTable L131/133/135/137：
'kg C/m²'  -> 'kg C/m^2'
'kg C/m³'  -> 'kg C/m^3'
'kg C/m²/yr' -> 'kg C/m^2/yr'

// _resilienceTable L159/161/163/165/167 同理替换
```

**或更优方案**（保留上标视觉效果）：在 `pdf_exporter.dart` 顶部注册第二个字体（如 DejaVuSans，覆盖 Latin-1），给单位单元格单独指定该字体：

```dart
// 加载第二个字体覆盖上标
final unitFont = pw.Font.ttf(
  await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
// 单位列用 cellStyle: pw.TextStyle(fontSize: 9, font: unitFont)
```

> 如果选择替换为 `^2`/`^3` 方案，建议**同步修改** [home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L414/420/427/435 和 [compare_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/compare/compare_page.dart) L66-68/241-245 中的 UI 显示单位，保持全局一致。

---

### 修复 2：AI 报告排版优化

**改动文件**：[ai_report_card.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/widgets/ai_report_card.dart)

核心改动：(a) 去掉内层 Card 避免双重边框；(b) 流式期间也用 MarkdownBody；(c) 丰富样式；(d) 加滚动容器。

```dart
class AiReportCard extends ConsumerWidget {
  const AiReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiReportProvider);
    final theme = Theme.of(context);

    if (!state.isGenerating &&
        state.streamContent.isEmpty &&
        state.error == null) {
      return const SizedBox.shrink();
    }

    // 不再用 Card 包裹——外层 home_page 已经有 Card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行 + 生成指示器
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            if (state.isGenerating)
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        // 思考过程（折叠区）——见修复 3
        if (state.reasoningContent != null && state.reasoningContent!.isNotEmpty)
          _buildReasoningTile(state.reasoningContent!, theme),

        if (state.isGenerating && state.streamContent.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('正在生成报告...', style: TextStyle(color: Colors.grey)),
          ),

        // 流式期间也用 MarkdownBody 渲染（关键改动）
        if (state.streamContent.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: state.streamContent,
                selectable: true,                    // 允许复制
                styleSheet: _buildMarkdownStyle(theme),
              ),
            ),
          ),

        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    return MarkdownStyleSheet(
      p: TextStyle(fontSize: 14, height: 1.6, color: theme.textTheme.bodyMedium?.color),
      h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      h3: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),        // 补 h3
      listBullet: TextStyle(fontSize: 14),                              // 列表
      code: TextStyle(backgroundColor: theme.colorScheme.surfaceContainerHighest,
          fontSize: 13, fontFamily: 'monospace'),                       // 代码
      codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6)),                      // 代码块
      blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),  // 引用
      tableHead: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),  // 表头
      tableBody: TextStyle(fontSize: 13),                               // 表格
      tableBorder: TableBorder.all(color: theme.dividerColor, width: 0.5),
      horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor, width: 1))),  // 分割线
    );
  }
}
```

**同时修改** [home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L501：去掉内层重复标题（标题由外层 Card 统一显示，`AiReportCard` 不再自带标题）。

---

### 修复 3：思考过程可折叠 — 解析 `reasoning_content`

**改动文件**：[ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart)

步骤 1：定义 chunk 类型，把 `Stream<String>` 改为 `Stream<AiStreamChunk>`：

```dart
class AiStreamChunk {
  final String? content;
  final String? reasoningContent;
  AiStreamChunk({this.content, this.reasoningContent});
}
```

步骤 2：修改 `_streamResponse` 解析两个字段：

```dart
// L121 原代码：
// final content = chunk['choices']?[0]?['delta']?['content'] as String?;
// if (content != null && content.isNotEmpty) { yield content; }

// 改为：
final delta = chunk['choices']?[0]?['delta'] as Map<String, dynamic>?;
if (delta != null) {
  final content = delta['content'] as String?;
  final reasoning = delta['reasoning_content'] as String?;
  if ((content != null && content.isNotEmpty) ||
      (reasoning != null && reasoning.isNotEmpty)) {
    yield AiStreamChunk(content: content, reasoningContent: reasoning);
  }
}
```

步骤 3：同步修改 `generateStream` 的返回类型签名和文档。

**改动文件**：[ai_report_provider.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/providers/ai_report_provider.dart)

步骤 4：`generateReport` 中分别累积两路内容：

```dart
// 原代码（约 L100-110）：
// final buffer = StringBuffer();
// await for (final chunk in stream) { buffer.write(chunk); ... }

// 改为：
final contentBuffer = StringBuffer();
final reasoningBuffer = StringBuffer();
await for (final chunk in stream) {
  if (chunk.content != null) contentBuffer.write(chunk.content);
  if (chunk.reasoningContent != null) reasoningBuffer.write(chunk.reasoningContent);
  state = state.copyWith(
    streamContent: contentBuffer.toString(),
    reasoningContent: reasoningBuffer.toString().isEmpty ? null : reasoningBuffer.toString(),
    isGenerating: true,
  );
}
```

这样思考过程会进入 `reasoningContent` 字段，`AiReportCard` 的 `ExpansionTile`（L50-64）就能正常渲染并折叠。

---

### 修复 4：`netChange20yr` / `netChange100yr` 深度池错配（A2）

**改动文件**：[resilience_assessment.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/resilience_assessment.dart) L65-66

```dart
// 原代码：
// final netChange20yr  = computeNetChange(finalPool060, initialPool060);
// final netChange100yr = computeNetChange(finalPool020, initialPool020);

// 修正（时间尺度统一用同一深度池，这里用全剖面 060）：
final netChange20yr  = computeNetChange(finalPool060, initialPool060);
final netChange100yr = computeNetChange(finalPool060, initialPool060);
```

> 如果产品意图是"20yr 看 0-20cm、100yr 看 0-60cm"（时间越长碳周转涉及更深），则应**互换**并同步修改 PDF/对比页标签：
> ```dart
> final netChange20yr  = computeNetChange(finalPool020, initialPool020);
> final netChange100yr = computeNetChange(finalPool060, initialPool060);
> ```
> 需与领域专家确认哪种语义正确，但无论如何当前"20yr 用深池、100yr 用浅池"是错的。

---

### 修复 5：`calculateNetChange` 语义修正（A3）

**改动文件**：[soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart)

两个选项，择一：

**选项 A（改实现为真差量）**：需要传入基准 SOC：

```dart
double calculateNetChange(double soc, double baseSoc, String fert, int erosion) {
  final erosionImpact = (erosion / 70) * 0.3;
  final fertImpact = fert == 'F' ? 0.05 : -0.02;
  final adjustedSoc = soc * (1 + fertImpact - erosionImpact);
  return adjustedSoc - baseSoc;  // 真实差量
}
```

**选项 B（改标签/单位，保留当前实现）**：把 UI/PDF/提示词中的"净变化量 kg C/m²"改为"修正SOC g/kg"。

建议选项 B（改动面更小），同步修改 [home_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) L425-428、[pdf_exporter.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/pdf_exporter.dart) L134-135、[ai_report_prompt.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_prompt.dart) L24。

---

### 修复 6：版本号同步（A6）

**改动文件**：[settings_page.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/settings/settings_page.dart) L8

```dart
final _kVersion = '1.1.3';  // 原为 '1.1.2'
```

---

### 修复 7：`getAll` 分页下推 SQL（A7）

**改动文件**：[record_dao.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/record_dao.dart)

```dart
// 原代码（约 L64-72）：query.get() 拉全表再 sublist
// 改为：
Future<List<CalculationParams>> getAll({
  String? search,
  int offset = 0,
  int limit = 50,
}) async {
  final query = select(historyRecords)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
  if (search != null && search.isNotEmpty) {
    query.where((t) => t.label.like('%$search%'));
  }
  query
    ..limit(limit, offset: offset);                    // 下推到 SQL
  final rows = await query.get();
  return _decodeAll(rows);
}
```

---

### 修复 8：AI 空闲超时给出反馈（C3）

**改动文件**：[ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart) L84-90

```dart
// 原代码：超时后 cancelToken.cancel()，被 DioException.cancel 静默 return
// 改为：抛出明确的超时异常
Timer? idleTimer;
void resetIdleTimer() {
  idleTimer?.cancel();
  idleTimer = Timer(Duration(seconds: idleTimeout), () {
    cancelToken?.cancel(TimeoutException('AI 响应空闲超时'));  // 带原因
  });
}
// ...
} on DioException catch (e) {
  if (e.type == DioExceptionType.cancel) {
    // 区分用户主动取消 vs 超时取消
    if (e.error is TimeoutException) {
      throw TimeoutException('AI 响应空闲超时，已生成内容可能不完整');
    }
    return;  // 用户主动取消，静默
  }
  rethrow;
}
```

---

## 修改优先级

| 优先级 | 修复项 | 对应用户痛点 |
|--------|--------|-------------|
| **P0** | 修复 1（PDF 乱码） | 用户直接反馈 |
| **P0** | 修复 3（思考过程折叠） | 用户直接反馈 |
| **P0** | 修复 2（AI 报告排版） | 用户直接反馈 |
| **P1** | 修复 4（深度池错配） | 数据正确性 |
| **P1** | 修复 6（版本号） | 一行改动 |
| **P2** | 修复 5（净变化语义） | 需领域确认后改 |
| **P2** | 修复 7（分页下推） | 性能 |
| **P2** | 修复 8（超时反馈） | 体验 |
