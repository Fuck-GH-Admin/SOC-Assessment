# SOC Assessment — Flutter 原生重构设计文档

## 1. 概述

将现有的 Web (Vue 3 + Vite) + Capacitor(Android) + Electron(Windows) 混合架构，重构为 Flutter 原生应用，同时覆盖 Android 和 Windows 平台。

核心目标：解决 Web 打包方案带来的兼容性问题（UI 适配、平台功能缺失、包体积大），同时保留全部现有功能。

## 2. 技术选型

| 层 | 选型 | 替代原方案 |
|---|---|---|
| 框架 | Flutter 3.x | Vue 3 |
| 语言 | Dart 3.x | JavaScript |
| 状态管理 | Riverpod + freezed + json_serializable | Pinia |
| 本地数据库 | Drift (SQLite) | Dexie.js (IndexedDB) |
| 图表 | fl_chart | Chart.js |
| PDF 生成 | pdf (dart_pdf) | jsPDF |
| 文件操作 | file_picker + path_provider | 浏览器 Blob API |
| AI 流式请求 | dio + CancelToken | fetch + ReadableStream |
| Markdown 渲染 | flutter_markdown | marked.js |
| 网络状态 | connectivity_plus | navigator.onLine |
| 设置存储 | Drift + SharedPreferences + flutter_secure_storage | Dexie.js key-value |
| 路由 | go_router | vue-router |
| 窗口管理 | window_manager | Electron BrowserWindow |
| 后台计算 | Isolate.run() (Dart 3) | 浏览器主线程 |

### 关键依赖说明

- **freezed + json_serializable**: 自动生成不可变数据类、`copyWith` 方法和 JSON 序列化/反序列化代码。解决手写 `state = state.copyWith(paramA: 1)` 的痛苦，同时确保导入旧 JSON 时的类型安全。
- **Drift (SQLite)**: 替代 Isar v3（已基本停止维护）。Drift 是 Flutter 生态最成熟的 ORM，基于 SQLite，稳定性高、社区活跃、支持迁移脚本、支持 Windows/Android/Web。
- **window_manager**: Windows 桌面端必需的窗口控制插件，支持自定义标题栏、记忆窗口大小/位置、限制最小尺寸等，弥补 Flutter 桌面端窗口管理能力不足的问题。
- **flutter_secure_storage**: API Key 等敏感信息的加密存储方案。Android 使用 Keystore，Windows 使用 DPAPI，杜绝明文存储风险。
- **dio**: HTTP 请求库，内置 `CancelToken` 支持取消 AI 流式请求。

## 3. 架构设计

采用三层架构，Drift 生成的数据类直接作为领域模型使用，不额外维护 entity/mapper 层：

```
lib/
├── core/                    # 共享基础设施
│   ├── theme/               # 主题、颜色、字体
│   ├── utils/               # 工具函数（数据验证、格式化）
│   └── constants/           # 常量数据（baseData、erosionCoefficients 等）
├── data/                    # 数据层
│   ├── app_database.dart    # Drift 数据库定义（含迁移脚本 + TypeConverter）
│   ├── record_dao.dart      # 历史记录 CRUD（含级联删除 AiReport）
│   ├── report_dao.dart      # AI 报告 CRUD
│   ├── draft_dao.dart       # 草稿 CRUD（含 CalculationParams TypeConverter）
│   └── settings_repository.dart  # 设置存储（跨 flutter_secure_storage + SharedPreferences 双源拼接）
├── domain/                  # 业务逻辑层（纯 Dart，零 UI 依赖）
│   ├── engine/              # SOC 计算引擎（从 JS 移植，纯函数）
│   │   ├── soc_calculator.dart
│   │   └── resilience_assessment.dart
│   └── models/              # freezed 数据类，与 Drift 解耦
│       ├── calculation_params.dart
│       ├── calculation_result.dart
│       ├── resilience_result.dart
│       └── ai_config.dart
├── presentation/            # UI 层
│   ├── providers/           # Riverpod providers（状态管理）
│   │   ├── calculator_provider.dart
│   │   ├── history_provider.dart
│   │   ├── compare_provider.dart
│   │   └── settings_provider.dart
│   ├── pages/               # 页面
│   │   ├── home/            # 参数输入 + 结果 + 图表 + AI 报告
│   │   ├── history/         # 历史记录（分页加载）
│   │   ├── compare/         # 多记录对比（按 ID 按需加载）
│   │   └── settings/        # 设置
│   ├── widgets/             # 可复用组件
│   │   ├── charts/          # 8 种图表组件
│   │   ├── forms/           # 参数输入表单组件
│   │   └── common/          # 按钮、卡片、标题等通用组件
│   └── app.dart             # 应用入口 + 路由配置
└── main.dart                # 入口文件
```

**关键分层原则**：
- 历史记录、AI 报告、草稿：Drift 的 `@DataClassName` 生成类直接作为领域对象，不额外维护 entity 和 mapper
- 计算相关数据类（`CalculationParams`、`CalculationResult`、`ResilienceResult`）：位于 `domain/models/`，纯 freezed 生成，不含 Drift 注解
- 计算引擎：纯函数，零外部依赖
- 设置仓库需显式处理，涉及 flutter_secure_storage + SharedPreferences 两个后端的拼接

### 数据流

```
用户输入 → Provider(状态) → Engine(计算) → Provider(更新) → UI(展示)
                                    ↓
                           ┌──────────────────────────┐
                           │  Drift/SQLite (数据)      │
                           │  SharedPreferences (配置)  │
                           │  flutter_secure_storage    │
                           │    (API Key)              │
                           └──────────────────────────┘
```

**存储职责分离**：
- **Drift (SQLite)**: 历史记录、AI 报告、草稿等结构化数据
- **SharedPreferences**: 主题偏好、窗口尺寸、上次访问页面等轻量配置
- **flutter_secure_storage**: API Key 等敏感凭据

### 密集计算隔离

`domain/engine/` 层的批量计算（热力图矩阵、批量数据推演）使用 Dart 3 的 `Isolate.run()` 放到后台隔离区执行。根据输入数据量预判计算成本：

```dart
Future<T> computeAsync<T>({
  required T Function() task,
  required int dataSize,
}) async {
  if (dataSize < 1000) return task();       // 轻量，主线程
  return Isolate.run(task);                 // 批量，后台隔离
}
```

常规单点计算始终走主线程。

### Riverpod AutoDispose 处理

计算表单的 Provider 必须明确保活，防止页面切回时状态丢失：

```dart
@Riverpod(keepAlive: true)
class Calculator extends _$Calculator { ... }
```

#### 草稿系统与 keepAlive 的关系

- `keepAlive: true` 覆盖页面切换场景（Home → History → Home）
- 草稿自动保存覆盖进程崩溃场景（App 被系统杀死）
- 草稿仅在以下时机被删除：用户点击"保存记录"成功后；用户在启动恢复提示中点击"忽略"
- 不在 `didChangeAppLifecycleState.paused` 中删除草稿（Android 上此状态后可能被 Kill；Windows 桌面不会触发 paused）
- 启动时检测草稿时间戳，超过 5 分钟未清理才弹恢复提示

### 仓库接口定义

```dart
abstract class RecordDAO {
  Future<List<HistoryRecord>> getPage(int offset, int limit);
  Future<int> getTotalCount();
  Future<List<HistoryRecord>> getByIds(List<int> ids);
  Future<HistoryRecord> save(HistoryRecord record);
  Future<void> delete(int id);  // 级联删除关联的 AiReport
  // 未来可添加：
  // Future<void> syncWithCloud();
}
```

`exportToJson` 和 `importFromJson` 不在 DAO 中定义，直接放在 `settings_provider.dart` 或 `ExportImportHelper` 中组合 RecordDAO + ReportDAO 的数据。

## 4. 功能模块映射

### 4.1 计算引擎移植

现有 `socCalculator.js` 和 `resilienceAssessment.js` 是纯函数，直接逐函数翻译为 Dart：

| JS 函数 | Dart 函数 | 状态 |
|---|---|---|
| `validateInput()` | `validateInput()` | 直接翻译 |
| `lookupBaseSOC()` | `lookupBaseSOC()` | 直接翻译 |
| `calculateSOC()` | `calculateSOC()` | 直接翻译 |
| `calculateCarbonStorage()` | `calculateCarbonStorage()` | 直接翻译 |
| `calculateCarbonDensity()` | `calculateCarbonDensity()` | 直接翻译 |
| `calculateNetChange()` | `calculateNetChange()` | 直接翻译 |
| `calculateRecoveryRate()` | `calculateRecoveryRate()` | 直接翻译 |
| `calculateLossRate()` | `calculateLossRate()` | 直接翻译 |
| `computeAll()` | `computeAll()` | 直接翻译 |
| `assessResilience()` | `assessResilience()` | 直接翻译 |

常量数据（`baseData`、`erosionCoefficients`、`depthFactor`、`fertilizerEffect`）保持完全相同。

### 4.2 图表（8种）

| # | 图表名称 | JS (Chart.js) | Flutter (fl_chart) |
|---|---|---|---|
| 1 | 侵蚀强度影响 | 柱状图 | BarChart |
| 2 | 深度分布 | 折线图（填充） | LineChart (fill) |
| 3 | 时间变化 | 双线图 | LineChart (multi-line) |
| 4 | 综合评估 | 雷达图 | RadarChart |
| 5 | 碳库组成 | 环形图 | PieChart (doughnut) |
| 6 | 参数关联 | 散点图 | ScatterChart |
| 7 | 碳库对比 | 填充线图 | LineChart (fill+baseline) |
| 8 | 热力图 | Matrix 插件 | 自定义 Grid + Gradient |
|    | 对比雷达图 | 雷达图（多数据集） | RadarChart (multi-dataset) |

热力图是唯一需要自定义的图表，用 `CustomPainter` 实现，颜色映射逻辑与现有 `heatmapColor()` 函数一致。

> fl_chart RadarChart 多数据集场景下图例区分和 tooltip 体验有限。对比页面 2-4 条记录基本可用，若效果不满足则备选 `CustomPainter` 自绘。

### 4.3 PDF 导出

现有方案（jsPDF + SimHei.ttf 字体 + canvas 截图）替换为：
- `pdf` 包：纯 Dart PDF 生成，支持中文嵌入
- 中文字体：使用 Noto Sans SC（Phase 4 实施字体子集化，将 ~8-10MB 压缩至 ~1-2MB）
- 图表嵌入：使用 `RepaintBoundary.toImage()` 截图，等待 `endOfFrame` 确保渲染完成
- 表格、标题、章节结构与现有 PDF 输出保持完全一致

#### 图表截图方案

`pdf` 包只提供底层绘图原语（drawLine、drawRect），没有预置的图表方法——给 8 种图表手写 PDF 绘制工作量不成比例。采用 Flutter 生态行业惯例的截图方案：

```dart
Future<ui.Image> captureChart(GlobalKey key) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary = key.currentContext!
      .findRenderObject() as RenderRepaintBoundary;
  return boundary.toImage(pixelRatio: 2.0);
}
```

导出流程：依次切换到每个图表的 Tab → `endOfFrame` → `toImage()` → 收集 PNG → 写入 PDF。

### 4.4 AI 报告

流式调用使用 `dio`（替代 `dart:http`），天然支持 `CancelToken` 和 SSE 流式响应。
- 解析 `choices[0].delta.content` 和 `reasoning_content`
- 支持 Markdown 渲染

#### 流式重绘节流

流式阶段使用 `SelectableText`（纯文本），接收完毕后再切为 `flutter_markdown`，避免逐字触发 Markdown 重新解析导致的低端机掉帧。

#### AI 报告独立存储

`AiReport` 不嵌入 `HistoryRecord`，以独立 Drift table 按 `historyId` 关联，列表不加载报告内容：

```dart
class HistoryRecord {
  final int id;
  final CalculationParams params;
  final CalculationResult result;
  final DateTime createdAt;
  // 无 aiReport 字段
}

class AiReport {
  final int id;
  final int historyId;
  final String markdown;
  final String? reasoning;
  final DateTime createdAt;
}
```

#### 取消 AI 请求

```dart
class AiReportNotifier extends Notifier<AiReportState> {
  CancelToken? _cancelToken;

  Future<void> generateReport(AiConfig config) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }
}
```

### 4.5 历史记录与数据管理

| 功能 | 当前实现 | Flutter 实现 |
|---|---|---|
| 存储 | Dexie.js (IndexedDB) | Drift (SQLite) |
| 增删查 | Dexie API | Drift CRUD |
| 搜索 | JavaScript filter | Drift filter / SQL WHERE |
| 排序 | JavaScript sort | Drift orderBy |
| 导出 JSON | Blob + download | file_picker save |
| 导入 JSON | File input | file_picker open |
| 数据模型 | 无 schema | Drift @DataClassName（不含 mapper/entity 层） |
| 分页 | 无（全量加载） | DAO 接口预留 `getPage(offset, limit)` |

#### 对比页按需加载

对比页面仅保存 `selectedIds`，渲染时按 ID 批量加载：

```dart
final selectedIds = <int>[];
final records = await recordDAO.getByIds(selectedIds);
```

### 4.6 设置页面

| 功能 | 当前实现 | Flutter 实现 |
|---|---|---|
| API 配置 | Dexie key-value (散字段) | AiConfig 结构体 + flutter_secure_storage + SharedPreferences |
| 密码输入 | input type=password | TextField obscureText |
| 测试连接 | fetch POST | http.post |
| 提示词编辑 | textarea | TextField multiline |
| 主题/窗口偏好 | 无 | SharedPreferences |
| 关于信息 | 静态文本 | 静态 Widget |

#### AiConfig 结构体

```dart
@freezed
class AiConfig with _$AiConfig {
  const factory AiConfig({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default('')
    String apiKey,           // 强制只能从 flutter_secure_storage 读取
    required String endpoint,
    required String model,
    @Default(0.7) double temperature,
    @Default(0.9) double topP,
    @Default(30) int timeoutSeconds,
    @Default(true) bool enableThinking,
    String? systemPrompt,
  }) = _AiConfig;

  factory AiConfig.fromJson(Map<String, dynamic> json) =>
      _$AiConfigFromJson(json);
}
```

> `@JsonKey(includeFromJson: false)` 阻止通过 JSON 反序列化拿到 apiKey，确保只能从 `flutter_secure_storage` 读取。`@Default('')` 确保代码生成器能提供默认值。

#### AiConfig 双源拼接（settings_repository 职责）

```dart
class SettingsRepository {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  Future<AiConfig> loadAiConfig() async {
    return AiConfig(
      apiKey: await _secureStorage.read(key: 'api_key') ?? '',
      endpoint: _prefs.getString('endpoint') ?? '',
      model: _prefs.getString('model') ?? 'deepseek-chat',
    );
  }

  Future<void> saveAiConfig(AiConfig config) async {
    await _secureStorage.write(key: 'api_key', value: config.apiKey);
    await _prefs.setString('endpoint', config.endpoint);
    await _prefs.setString('model', config.model);
  }
}
```

#### 存储职责分离

| 数据类型 | 存储方案 | 原因 |
|---|---|---|
| API Key | flutter_secure_storage | 加密存储 |
| endpoint / model / prompt | SharedPreferences | 轻量配置 |
| 主题 / 窗口尺寸 | SharedPreferences | 启动时立即读取 |
| 历史记录 | Drift (SQLite) | 结构化查询、分页 |
| AI 报告 | Drift（独立 table） | 按需加载 |

> **DPAPI 降级**：某些企业环境或沙箱中 DPAPI 不可用。`SettingsRepository` 需捕获 `flutter_secure_storage` 异常，降级为 SharedPreferences 明文存储并输出日志警告。

### 4.7 草稿崩溃恢复

用户在表单中填写大量参数时，程序崩溃会导致数据全部丢失。

**方案**：
- Provider 在每次参数变更后（节流 2s）自动将当前表单状态写入 Drift DraftTable
- 草稿使用固定主键 `id: 1`，Drift 的 `insertOnConflictUpdate` 确保只有一条记录

```dart
@freezed
class DraftRecord with _$DraftRecord {
  const factory DraftRecord({
    @Default(1) int id,            // 全局唯一一条草稿
    required CalculationParams params,
    required DateTime updatedAt,
  }) = _DraftRecord;
}
```

> **Drift TypeConverter**：`CalculationParams` 是嵌套 freezed 对象，不能直接映射为 Drift 列。在 `app_database.dart` 中定义 `CalculationParamsConverter extends TypeConverter<CalculationParams, String>`，将 params 序列化为 JSON 字符串后存为 `TextColumn`。同理，`HistoryRecord` 中的 params 和 result 字段也需要同样的 TypeConverter。

应用启动时检测草稿时间戳，超过 5 分钟未清理则弹出恢复提示：

```
检测到未完成的计算草稿，是否恢复？
[恢复] [忽略]
```

## 5. 路由结构

```
/            → HomePage       (计算 + 结果 + 图表 + AI 报告)
/history     → HistoryPage    (历史记录列表)
/compare     → ComparePage    (多记录对比)
/settings    → SettingsPage   (API 配置 + 数据管理 + 关于)
```

与原 Vue Router 结构完全一致。

## 6. 平台特定处理

### Android
- 最低 SDK 版本: 21 (Android 5.0)
- 权限: 网络（AI 报告）、文件读写（导出/导入）
- 打包: APK / AAB
- 离线存储: Drift (SQLite) 本地文件
- **返回键保护**：多步参数填写页面使用 `PopScope` 拦截返回事件，防止误操作丢失已填参数

### Windows
- 最小支持: Windows 10+
- 打包: MSIX / 便携版 EXE
- 文件路径: path_provider 获取文档目录
- **窗口管理**：使用 `window_manager` 插件实现沉浸标题栏、记忆窗口尺寸、限制最小尺寸（1200×800）
- **响应式布局**：大屏幕下左右分栏（左侧参数表单，右侧结果实时预览）
- **消除启动白屏**：修改 `windows/runner/main.cpp`，初始窗口 `SW_HIDE`，Flutter 就绪后 `Show()`

## 7. 数据迁移

用户现有 Web 版的 IndexedDB 数据无法直接迁移到 Flutter Drift，提供过渡方案：用户在 Web 版先导出 JSON，在 Flutter 版导入。导入文件格式加入版本标识：

```json
{
  "schemaVersion": 1,
  "appVersion": "2.0.0",
  "exportedAt": "2026-06-23T12:00:00Z",
  "records": [...]
}
```

后续版本变更时，在 `ExportImportHelper` 中按 `schemaVersion` 分支处理迁移逻辑。

### JS Number vs Dart 强类型

JavaScript 只有双精度浮点数，JSON 中 `1` 和 `1.0` 没有区别。Dart 严格区分 `int` 和 `double`。反序列化统一使用 `(json['field'] as num).toDouble()`，由 `freezed` + `json_serializable` 配合自定义 `JsonConverter` 自动生成。

## 8. 阶段计划

### Phase 1 — 核心框架 + 计算引擎（预估 4-7 天）
- Flutter 项目初始化，Android + Windows 双端配置
- 移植计算引擎（socCalculator + resilienceAssessment）
- 基础 UI 框架（主题、路由、页面骨架）
- 参数输入表单 + 计算结果展示
- 单元测试覆盖所有计算函数 + 黄金数据集比对（JS vs Dart 浮点校验）

### Phase 2 — 图表（预估 3-5 天）
- 8 种图表移植（fl_chart）
- 热力图自定义实现（CustomPainter）
- 图表交互（tooltip、切换）

### Phase 3 — 数据持久化（预估 2-3 天）
- Drift 数据库定义 + Table 模型 + TypeConverter + 迁移脚本
- 保存/加载历史记录
- JSON 导入/导出
- 搜索/排序/筛选

### Phase 4 — AI 报告 + PDF（预估 2-3 天）
- AI 流式接口对接（dio + CancelToken）
- Markdown 渲染（流式纯文本，完成后切 Markdown）
- PDF 导出（RepaintBoundary 截图 + 中文字体子集化）
- 字体子集化（fonttools 提取 3500 常用字，~8-10MB 压缩至 ~1-2MB）

### Phase 5 — 设置 + 对比 + 打磨（预估 2-3 天）
- 设置页面（AiConfig 双源拼接、加密存储）
- 多记录对比页面（按 ID 按需加载）
- 草稿崩溃恢复
- 离线状态检测
- UI 打磨（主题、暗黑模式、响应式布局）
- 端到端测试

**总计预计：13-21 天**

## 9. 测试策略

| 层级 | 工具 | 覆盖内容 |
|---|---|---|
| 单元测试 | flutter_test | 计算引擎所有函数 |
| Widget 测试 | flutter_test | 表单组件、图表组件 |
| 集成测试 | integration_test | 完整计算流程、保存/加载 |
| 平台测试 | 真机/模拟器 | Android + Windows 端到端 |

### 黄金数据集

准备一组固定输入/输出文件，JS 原版与 Dart 重构版同时跑，逐字段比对结果（允许 ±1e-6 浮点误差）：

```
tests/golden/
├── input_a.json       →  expected_a.json
├── input_b.json       →  expected_b.json
└── input_c.json       →  expected_c.json
```

```dart
test('Golden test: input_a', () {
  final input = loadJson('golden/input_a.json');
  final expected = loadJson('golden/expected_a.json');
  final result = computeAll(CalculationParams.fromJson(input));
  expect(result.soc, closeTo(expected.soc, 1e-6));
  // ...
});
```

## 10. 风险与缓解

| 风险 | 缓解措施 |
|---|---|
| 热力图 fl_chart 不支持 | 使用 CustomPainter 自行实现 |
| fl_chart 雷达图多数据集体验有限 | 2-4 条基本可用，不满足则切换 CustomPainter |
| 中文字体在 PDF 中嵌入（~8-10MB） | Phase 4 子集化压缩至 ~1-2MB |
| 现有数据无法自动迁移 | 提供 JSON 导出/导入 + schemaVersion |
| AI 流式请求跨平台差异 | dio 的 StreamedResponse + CancelToken |
| **RepaintBoundary 截图空白** | endOfFrame 等待帧完成，不依赖固定 delay |
| **JS Number vs Dart 类型不匹配** | `(json['field'] as num).toDouble()` + freezed JsonConverter |
| **Dart 单线程阻塞 UI** | 按数据量预判：<1000 条主线程，≥1000 条 Isolate.run() |
| **AI 流式频繁重绘** | 流式 SelectableText，完成后再切 flutter_markdown |
| **Windows 窗口体验差** | window_manager 沉浸标题栏、记忆窗口尺寸、响应式分栏 |
| **Android 返回键丢失参数** | PopScope 拦截，填写中参数时提示确认 |
| **Drift/SQLite 兼容性** | SQLite 各平台原生支持，无额外运行库依赖 |
| **Riverpod autoDispose 表单重置** | 计算表单 Provider 标记 `@Riverpod(keepAlive: true)` |
| **API Key 明文存储风险** | flutter_secure_storage（Keystore/DPAPI），fromJson 排除 apiKey |
| **Windows 启动白屏闪烁** | C++ 层初始 SW_HIDE，Flutter 就绪后 Show() |
| **AI 报告嵌入 History 导致数据库膨胀** | 独立 AiReport table，按需加载 |
| **Isolate 滥用（微任务隔离成本 > 收益）** | 按数据量预判，<1000 条直接主线程 |
| **JSON 导入无版本兼容** | schemaVersion + ExportImportHelper 分支处理 |
| **长列表无分页** | DAO 接口设计 getPage(offset, limit) |
| **API 配置散字段难扩展** | AiConfig 结构体统一管理 |
| **轻量配置混入数据库** | SharedPreferences 存主题/窗口/上次页面 |
| **无取消 AI 请求机制** | Provider 维护 CancelToken |
| **程序崩溃参数丢失** | Drift DraftTable 节流自动保存 + 启动恢复提示 |
| **引擎迁移引入隐蔽计算偏差** | 黄金数据集（JS vs Dart 双端跑）+ 逐字段浮点比对 |
| **DPAPI 企业环境失效** | SettingsRepository 捕获异常降级 SharedPreferences + 日志警告 |
| **Drift 无自动级联删除** | RecordDAO.delete() 手动清理关联 AiReport |
| **freezed 嵌套对象无法直接存 Drift** | TypeConverter 序列化为 JSON 字符串 |
| **AiConfig.fromJson 泄露 apiKey** | @JsonKey(includeFromJson: false) + @Default('') |
