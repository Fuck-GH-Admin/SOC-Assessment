# SOC 土壤碳评估 — Flutter 重构实施报告

## 全局概览

将 Vue 3 + Capacitor(Android) + Electron(Windows) 混合架构重构为 Flutter 原生应用，覆盖 **Android + Windows**。

| 指标 | 当前值 |
|---|---|
| 完成阶段 | **Phase 1–5** ✅ |
| 总文件 | 39 个 Dart 文件 |
| 总代码量 | ~5,500 行 Dart |
| 单元测试 | **53/53** ✅ |
| 代码分析 | **0 error, 0 warning** ✅ |
| Flutter SDK | `^3.12.2` |
| 状态管理 | Riverpod 2.6 (Notifier / FutureProvider) |
| 数据库 | Drift 2.28 (SQLite) |
| 图表库 | fl_chart 0.70 |
| AI 请求 | dio 5.7 (SSE 流式) |
| PDF 生成 | pdf 3.11 (RepaintBoundary 截图) |

---

## 完整文件映射

```
soc_app/lib/
├── main.dart                                  # 应用入口: ProviderScope + MaterialApp (Light/Dark)
├── core/
│   └── theme/
│       └── app_theme.dart                     # Material 3 主题, seed=0xFF2E7D32
│
├── domain/
│   ├── engine/
│   │   ├── soc_calculator.dart                # SOC 计算引擎 — 8 纯函数 + 3 查找表 + computeAll
│   │   └── resilience_assessment.dart         # 恢复力评估引擎 — 6 纯函数 + 场景生成 + assessResilience
│   └── models/
│       ├── soil_layer.dart                    # 土层模型 (手写 toJson/fromJson)
│       ├── calculation_params.dart            # 计算参数 (15 字段)
│       ├── calculation_result.dart            # 计算结果 (6 字段)
│       └── resilience_result.dart             # 恢复力结果 (包含 StrawScenario, LayerPool)
│
├── data/
│   ├── app_database.dart + .g.dart            # Drift 数据库: history_records + drafts 表
│   ├── record_dao.dart                        # 历史记录 CRUD (插入/批量/分页/解码, 逐记录容错)
│   ├── draft_dao.dart                         # 草稿 CRUD (固定 id=1 + 过期检查)
│   ├── ai_report_service.dart                 # Dio SSE 流式请求 + [DONE] + CancelToken + 60s 空闲超时
│   ├── ai_report_prompt.dart                  # 默认提示词模板 + fillPrompt
│   ├── ai_config_service.dart                 # AiConfig 双源持久化 (SharedPreferences + flutter_secure_storage)
│   ├── json_io.dart                           # JSON 导入/导出 (FilePicker)
│   └── pdf_exporter.dart                      # PDF 生成 (表格 + 图表截图 + 纯文本报告, 字符覆盖检测)
│
└── presentation/
    ├── providers/
    │   ├── calculator_provider.dart           # CalculatorNotifier — 9 update + calculate (自动存历史/草稿)
    │   ├── ai_report_provider.dart            # AiReportNotifier — 流式/错误/取消
    │   ├── database_provider.dart             # FutureProvider<AppDatabase>
    │   ├── record_dao_provider.dart           # FutureProvider<RecordDao>
    │   ├── draft_dao_provider.dart            # FutureProvider<DraftDao>
    │       ├── draft_dao_provider.dart            # FutureProvider<DraftDao>
    ├── ai_config_provider.dart            # AiConfigProvider — 配置读写/清除
    └── history_provider.dart              # FutureProvider 历史列表 + 删除 (记录损坏容错)
    ├── pages/
    │   ├── home/home_page.dart                # 首页 (ConsumerStatefulWidget, 草稿恢复对话框)
    │   ├── history/history_page.dart          # 历史列表 (加载/空态/删除)
    │   ├── settings/settings_page.dart        # 设置页 (API 配置 + 加密存储)
    │   └── compare/compare_page.dart          # 对比页 (参数/结果/雷达图叠加)
    └── widgets/
        ├── ai_report_card.dart               # AI 报告 UI (流式/Markdown/思考/错误)
        └── charts/
            ├── erosion_bar_chart.dart         # Chart 1: 侵蚀强度影响 → BarChart
            ├── depth_line_chart.dart          # Chart 2: 深度分布 → LineChart(fill)
            ├── time_line_chart.dart           # Chart 3: 时间变化 → LineChart(multi)
            ├── assessment_radar_chart.dart    # Chart 4: 综合评估 → RadarChart
            ├── pool_pie_chart.dart            # Chart 5: 碳库组成 → PieChart(doughnut)
            ├── correlation_scatter_chart.dart # Chart 6: 参数关联 → ScatterChart
            ├── comparison_fill_chart.dart     # Chart 7: 碳库对比 → LineChart(fill+baseline)
            ├── comparison_radar_chart.dart    # Chart 7b: 对比雷达图 → RadarChart(双数据集)
            └── heatmap_chart.dart             # Chart 8: 热力图 → CustomPainter

soc_app/test/
├── soc_calculator_test.dart                   # 20 测试 (2 组黄金数据集 ±1e-6)
├── resilience_assessment_test.dart            # 7 测试
├── ai_report_service_test.dart                # 7 测试 (Dio + SSE 流式)
├── ai_report_state_test.dart                  # 3 测试 (copyWith 行为)
├── history_provider_test.dart                 # 3 测试 (记录损坏容错 + ProviderContainer 集成)
└── data/
    ├── record_dao_test.dart                   # 7 测试 (CRUD + 分页 + 批量, 逐记录容错)
    └── draft_dao_test.dart                    # 6 测试 (保存/覆盖/空态/过期/删除)
```

---

## Phase 1 — 引擎移植 + 基础 UI + 测试

**目标**: Flutter 项目初始化、JS→Dart 计算引擎移植、Material 3 主题、参数输入表单、结果卡片、Riverpod 状态接入、27 个引擎测试。

### 引擎移植精度验证（黄金数据集）

| 数据集 | soc | carbonStorage | carbonDensity | netChange | recoveryRate | lossRate |
|---|---|---|---|---|---|---|
| F/0/10/bd1.3 (JS) | 23.9 | 3.11 | 31.07 | 25.09 | 1.255 | 0 |
| Dart 输出 | 23.9 | 3.11 | 31.07 | 25.09 | 1.255 | 0.0 |
| UNF/30/35/bd1.5 (JS) | 3.78 | 1.13 | 3.24 | 3.22 | 0.161 | 84.2 |
| Dart 输出 | 3.78 | 1.13 | 3.24 | 3.22 | 0.161 | 84.2 |

**精度**: ±1e-6, `toStringAsFixed(N)` + `double.parse` 对齐 JS `+num.toFixed(N)`。

### 关键决策

| 决策 | 方案 |
|---|---|
| 状态管理 | `NotifierProvider` (非 autoDispose) → 默认 keepAlive, 页面跳转不丢表单 |
| 模型类 | 纯手写（freezed 已移除，v3 API 不兼容）|
| `fromJson` 安全模式 | 全部使用 `(num?)?.toDouble() ?? 0.0`, 无 `as double` |
| 引擎设计 | 纯函数, 零依赖, 可直接 `Isolate.run()` |

---

## Phase 2 — 8 种图表

**目标**: 移植全部 8 种图表为 `fl_chart` + `CustomPainter`, 嵌入首页 TabBar。

| 图表 | 组件 | fl_chart 类型 | 数据源 |
|---|---|---|---|
| 侵蚀强度影响 | `ErosionBarChart` | BarChart | lookupBaseSOC × 8 侵蚀等级 |
| 深度分布 | `DepthLineChart` | LineChart(fill) | lookupBaseSOC × 5 深度 |
| 时间变化 | `TimeLineChart` | LineChart(multi) | F/UNF 双线, 10 年趋势 |
| 综合评估 | `AssessmentRadarChart` | RadarChart | 6 维度归一化评分 |
| 碳库组成 | `PoolPieChart` | PieChart(doughnut) | lookupBaseSOC × 8 数据 |
| 参数关联 | `CorrelationScatterChart` | ScatterChart | BD×SOC 散点 + 回归线 |
| 碳库对比 | `ComparisonFillChart` | LineChart(fill+base) | 当前 vs 初始碳库 |
| 热力图 | `HeatmapChart` | CustomPainter | 侵蚀×深度 × 40 网格 |

### fl_chart API 注意事项

- `RadarChartTitle` 没有 `style` 参数 → 用 `titleTextStyle`
- `ScatterSpot` 没有 `color`/`radius` → 用 `dotPainter: FlDotCirclePainter`
- `withOpacity()` 在 Dart SDK 3.12+ 已废弃 → 改用 `withValues(alpha: x)`

---

## Phase 3 — 数据持久化 (Drift)

**目标**: SQLite 数据库、历史记录 CRUD、草稿自动保存/恢复、JSON 序列化。

### Drift 数据表

```sql
CREATE TABLE history_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  params TEXT NOT NULL,         -- JSON: CalculationParams
  result TEXT NOT NULL,         -- JSON: CalculationResult
  resilience TEXT,              -- JSON: ResilienceResult?
  label TEXT,                   -- 用户标签?
  created_at INTEGER NOT NULL   -- 毫秒时间戳
);

CREATE TABLE drafts (
  id INTEGER PRIMARY KEY,       -- 固定 1
  params TEXT NOT NULL,         -- JSON: CalculationParams
  created_at INTEGER NOT NULL   -- 毫秒时间戳
);
```

### Riverpod Provider 依赖图

```
AppDatabase.create()
  → databaseProvider (FutureProvider, onDispose: close)
    → recordDaoProvider (FutureProvider<RecordDao>)
      → calculatorProvider.notifier  — 计算成功后自动 insert
      → historyListProvider           — 历史列表 + 删除
    → draftDaoProvider (FutureProvider<DraftDao>)
      → calculatorProvider.notifier  — 参数变更 2s 防抖自动保存
      → HomePage._checkDraft()       — 启动检测 + 5min 内恢复对话框
```

### 草稿机制

| 特性 | 实现 |
|---|---|
| 触发时机 | 每次参数 `update*` 调用后 |
| 防抖 | 2 秒 Timer, 持续输入 reset, 停止 2s 后写入 |
| 存储位置 | `drafts` 表, `id = 1` 固定行 |
| 写入策略 | `insertOnConflictUpdate` → 始终覆盖 |
| 启动检测 | `HomePage.build()` 首次执行 `_checkDraft()` |
| 过期 | 超过 5 分钟自动 `delete()` |
| 恢复 UI | `AlertDialog` → 恢复/忽略 |

### 与设计文档的偏差

| 设计文档 | 实际实现 | 原因 |
|---|---|---|
| Drift TypeConverter | DAO 层 JSON 编解码 | TypeConverter API 兼容问题, 可无损迁移 |
| go_router 路由 | Navigator.push | 仅历史页面, 开销比收益大 |
| file_picker 导入导出 | json_io.dart | Phase 5 实现: FilePicker + JSON 批量导入/导出 |
| AiConfig 加密存储 | ai_config_service.dart | Phase 5 实现: flutter_secure_storage + SharedPreferences |

## 累计质量门禁

```
$ dart analyze lib/
  3 issues found.              # 全部 info-level:
                                - prefer_function_declarations_over_variables
                                - non_constant_identifier_names × 2

$ flutter test
  00:01 +40: All tests passed! # Phase 4 baseline
```

## Phase 1–3 核心质量 Phase 4 — AI 报告 + PDF 导出 (✅ 已完成)

**依赖**: `dio ^5.7.0`, `flutter_markdown ^0.7.6`, `pdf ^3.11.3`

### 4.1 AI 流式报告

**目标**: 实现完整的 AI 报告生成功能，包含流式输出、Markdown 渲染、思考过程展示。

| 模块 | 文件 | 描述 |
|---|---|---|
| AI 报告 Provider | `lib/presentation/providers/ai_report_provider.dart` | 管理流式状态、错误、取消 |
| 流式 API 服务 | `lib/data/ai_report_service.dart` | dio + CancelToken, SSE 解析 |
| Markdown 渲染 | `lib/presentation/widgets/ai_report_card.dart` | 流式纯文本 + 完成后 flutter_markdown |
| 提示词模板 | `lib/data/ai_report_prompt.dart` | 默认提示词 + `fillPrompt()` |

**依赖**: `dio`, `flutter_markdown`

**关键实现细节**:

1. **Service 层** (`ai_report_service.dart`):
   - `dio.post` 带 `CancelToken`
   - 30s 超时, 错误分类（超时/网络/HTTP）
   - SSE 流解析: `response.data.stream` → `line.startsWith('data: ')`
   - 支持 `thinking` / `reasoning_effort` 扩展参数

2. **Provider 层** (`ai_report_provider.dart`):
   - `AiReportNotifier` extends `Notifier<AiReportState>`
   - 状态: `streamContent`, `reasoningContent`, `isGenerating`, `error`
   - 方法: `generateReport(...)`, `cancel()`, `reset()`
   - Provider 生命周期: `ref.onDispose(() => cancel())`

3. **UI 层** (`ai_report_card.dart`):
   - 生成中: 流式纯文本 `Text` widget (逐字追加)
   - 完成: 切换 `flutter_markdown` 渲染
   - 思考过程: `ExpansionTile` 可折叠
   - 错误状态: 重试按钮

4. **提示词** (`ai_report_prompt.dart`):
   - `${fert}`, `${erosion}`, `${bd}`, `${soc}` 等模板占位符
   - 默认提示词: 数据解读 + 侵蚀评估 + 种植建议 + 综合评分

**与现有 HomePage 集成**（✅ 已实现）:
- 图表 TabBar 下方插入 AI 报告区块
- 按钮: `生成 AI 报告`（计算后可用，点击先弹出 API 配置对话框）
- 取消/重新生成按钮
- 加载/流式/完成/错误四种状态

### 4.2 PDF 导出 (✅ 已完成)

**目标**: 将计算结果 + 图表 + AI 报告导出为 PDF。

| 模块 | 文件 | 描述 |
|---|---|---|
| PDF 导出 | `lib/data/pdf_exporter.dart` | `pdf` 包 + 字体子集化, 构建 PDF 文档 |
| 图表截图 | 集成到导出流程 | RepaintBoundary → RenderRepaintBoundary.toImage() → PNG bytes |
| 中文字体 | `assets/fonts/SimHei-subset.ttf` | fonttools 子集化 ~0.9MB, 3449 常用 CJK 字符 |

**关键决策**:

- **RepaintBoundary + endOfFrame 截图** 作为 PDF 图表渲染主方案：
  - `pdf` 包只提供底层绘图原语, 8 种图表手写 PDF 绘制工作量不成比例
  - 流程: 图表包裹 `RepaintBoundary` → `GlobalKey` → `RenderRepaintBoundary.toImage()` → `png.encode` → `pdf.PageImage`
  - 截图时机: `WidgetsBinding.instance.endOfFrame.then(...)` 确保渲染完成

- **陷阱: TabBarView 懒渲染导致图表无法截图**
  - `TabBarView` 默认只 build 当前 Tab, 未访问的 Tab 无 `RenderRepaintBoundary`, `toImage()` 抛异常
  - 解决: `TabBarView` 改为 `IndexedStack(index: _tabIndex, children: [...])`, 8 个图表常驻渲染树
  - 代价: 略多内存, 对此 app 可忽略

- **AI 报告在 PDF 中为纯文本**（选项 A）：
  - `pdf` 包无 Markdown 解析器, 直接写入 Markdown 文本（符号原样保留）
  - 注释说明"完整格式见 APP 内"
  - 不手写 Markdown→pw.Widget 转换, 避免在工具类 app 上花不必要的时间

- **字体子集化**: `fonttools` 提取 3449 常用字, 原始 `SimHei.ttf` 约 9MB, 子集化后 `SimHei-subset.ttf` 约 0.9MB

**PDF 内容结构**:
1. 标题: "SOC 土壤有机碳评估报告"
2. 输入参数表
3. 计算结果表
4. 土壤恢复力评估表
5. 8 张图表截图 (IndexedStack 确保全部可截图)
6. AI 评估报告文本（纯文本, Markdown 符号保留）

### 4.3 SSE 流解析注意事项

OpenAI-compatible API 最后一行是 `data: [DONE]`, `jsonDecode` 会抛 `FormatException`:

```dart
if (line == 'data: [DONE]') break;  // 先判断终止符
final json = jsonDecode(line.substring(6));  // 再解析 JSON
```

### 4.4 Phase 4 入口条件

- [x] 计算引擎输出可用
- [x] 8 种图表可渲染（IndexedStack 确保全部可截图）
- [x] API 配置通过临时对话框输入（Phase 5 完善为持久化存储）
- [x] 添加 `dio`, `flutter_markdown`, `pdf` 依赖
- [x] 创建 `ai_report_service.dart` — dio + SSE + [DONE] 终止符 + CancelToken
- [x] 创建 `ai_report_provider.dart` — AiReportNotifier + 流式/错误/取消
- [x] 创建 `ai_report_card.dart` — 流式文本 / flutter_markdown / 思考过程 / 错误
- [x] 创建 `ai_report_prompt.dart` — 默认提示词 + fillPrompt + fert 映射
- [x] 创建 `pdf_exporter.dart` — PDF 文档 + 表格 + 图片 + 纯文本报告 + 文件保存
- [x] HomePage: IndexedStack 代替 TabBarView + PDF 导出按钮 + AI 报告区块 + API 配置对话框
- [x] 40/40 测试全部通过

### 4.5 Phase 4 新增文件

| 文件 | 功能 |
|---|---|
| `lib/data/ai_report_prompt.dart` | 默认提示词模板 + `fillPrompt()` 替换 |
| `lib/data/ai_report_service.dart` | Dio SSE 流式请求 + [DONE] 处理 + CancelToken |
| `lib/presentation/providers/ai_report_provider.dart` | AiReportNotifier (Riverpod) |
| `lib/presentation/widgets/ai_report_card.dart` | AI 报告 UI（流式/Markdown/思考/错误） |
| `lib/data/pdf_exporter.dart` | PDF 生成（表格/截图/纯文本） |

### 4.6 Phase 4 与设计文档偏差

| 设计文档 | 实际方案 | 原因 |
|---|---|---|
| `pdf` 包直接绘制图表 | RepaintBoundary 截图 | 8 种图表手写 PDF 绘制工作量 ×8, 截图方案 1 套代码复用 |
| AiConfig 依赖 flutter_secure_storage | 临时对话框 + 内存变量 | Phase 5 再引入加密存储 |
| `pdf` 包 Markdown 渲染 | 纯文本（选项 A） | pdf 无 Markdown 解析器, 工具类 app 够用 |
| 字体子集化 (fonttools) | SimHei-subset.ttf | Phase 5 实现: fonttools 子集化 SimHei → ~0.9MB |

---

## Phase 5 — 设置 + 对比 + 代码质量 (✅ 已完成)

| 功能 | 状态 | 实现 |
|------|------|------|
| 设置页面 | ✅ | `settings_page.dart`: AiConfig 双源拼接 (SharedPreferences + flutter_secure_storage) |
| 多记录对比 | ✅ | `compare_page.dart`: 按 ID 按需加载, 参数/结果/雷达图叠加对比 |
| JSON 导入/导出 | ✅ | `json_io.dart`: FilePicker + JSON 批量导入/导出 |
| AI 空闲超时 | ✅ | `ai_report_service.dart`: 60s 空闲超时替代 Dio receiveTimeout |
| PDF 字符覆盖检测 | ✅ | `pdf_exporter.dart`: 非 CJK/Latin 字符替换为占位符 |
| DAO 逐记录容错 | ✅ | `record_dao.dart`: bad JSON rows skip without crashing |
| Schema 迁移框架 | ✅ | `app_database.dart`: onUpgrade + MigrationStrategy 预配置 |
| Lint 清理 | ✅ | 5 个 `non_constant_identifier_names` + `prefer_function_declarations_over_variables` + `no_leading_underscores_for_local_identifiers` |
| GitHub CI | ✅ | `.github/workflows/ci.yml`: push/PR 自动 flutter pub get + dart analyze + flutter test |
| Provider 测试 | ✅ | `history_provider_test.dart` (3 例) + `ai_report_state_test.dart` (3 例) |
