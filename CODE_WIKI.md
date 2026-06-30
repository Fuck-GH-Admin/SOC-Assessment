# 碳盾 SOC-Shield — Code Wiki

> 仓库：`soc-assessment/`　·　应用包：`soc_app/`　·　版本：1.1.3　·　技术栈：Flutter 3.12+ / Dart 3.12+
>
> 本文档为代码级 Wiki，覆盖整体架构、模块职责、关键类与函数、依赖关系与运行方式。功能层面的产品说明见 [DOCUMENTATION.md](./DOCUMENTATION.md)，编译打包见 [BUILD.md](./BUILD.md)。

---

## 1. 项目整体架构

### 1.1 定位

跨平台（Android / Windows / Web）土壤有机碳（SOC）评估工具。核心能力：参数化 SOC 计算 → 8 种可视化图表 → AI 流式报告 → PDF 导出，并以 SQLite 持久化历史记录与草稿。

### 1.2 分层架构

采用 **Clean Architecture** 风格的三层划分，依赖方向严格自上而下：

```
┌──────────────────────────────────────────────────────────┐
│  Presentation 层（Flutter UI + Riverpod 状态）            │
│  pages / widgets / providers                             │
├──────────────────────────────────────────────────────────┤
│  Data 层（I/O 与外部服务）                                │
│  Drift DB · Dio SSE · pdf · file_picker · secure_storage  │
├──────────────────────────────────────────────────────────┤
│  Domain 层（纯 Dart，零 Flutter 依赖，可独立测试）        │
│  engine（计算函数） · models（数据模型）                  │
└──────────────────────────────────────────────────────────┘
```

- **Domain 层** 是纯函数集合，无副作用、无框架依赖，可直接被测试或移植到其他 Dart 项目。
- **Data 层** 负责所有 I/O：数据库、网络、文件、密钥存储，向上暴露同步/异步 API。
- **Presentation 层** 通过 Riverpod Provider 桥接 Data 层与 UI，UI 仅消费状态、派发意图。

### 1.3 目录结构

```
soc_app/
├── lib/
│   ├── main.dart                      # 入口，ProviderScope + MaterialApp
│   ├── core/theme/                    # 主题（light/dark）+ 主题状态
│   ├── domain/
│   │   ├── engine/                    # 计算引擎（纯函数）
│   │   │   ├── soc_calculator.dart
│   │   │   └── resilience_assessment.dart
│   │   └── models/                    # 4 个手写模型（toJson/fromJson）
│   │       ├── calculation_params.dart
│   │       ├── calculation_result.dart
│   │       ├── resilience_result.dart
│   │       └── soil_layer.dart
│   ├── data/                          # 数据层
│   │   ├── app_database.dart          # Drift 建表 + 初始化
│   │   ├── app_database.g.dart        # Drift 生成代码
│   │   ├── record_dao.dart            # 历史记录 CRUD
│   │   ├── draft_dao.dart             # 草稿（固定 id=1）
│   │   ├── ai_report_service.dart     # Dio SSE 流式请求
│   │   ├── ai_report_prompt.dart      # 提示词模板
│   │   ├── ai_config_service.dart     # API 配置持久化
│   │   ├── pdf_exporter.dart          # PDF 生成 + 图表截图
│   │   └── json_io.dart               # JSON 导入/导出
│   └── presentation/
│       ├── pages/
│       │   ├── home/home_page.dart        # 主页（参数+结果+图表+AI）
│       │   ├── history/history_page.dart  # 历史列表 + 导入导出
│       │   ├── settings/settings_page.dart# AI 配置 + 主题 + 关于
│       │   └── compare/compare_page.dart  # 多记录对比
│       ├── providers/                 # 7 个 Riverpod Provider
│       └── widgets/
│           ├── ai_report_card.dart
│           └── charts/                # 8 个图表 + 对比雷达图
├── test/                              # 53 个单元测试
├── android/  windows/                 # 平台壳工程
├── assets/fonts/SimHei.ttf            # PDF 中文字体
└── pubspec.yaml                       # 依赖与版本
```

### 1.4 关键架构决策

| 决策 | 原因 |
|---|---|
| `IndexedStack` 替代 `TabBarView` | PDF 需截图全部 8 图表；TabBarView 懒加载，未访问的 Tab 不在渲染树中无法截图。代价：8 图常驻内存。 |
| 离屏 `Positioned(left: 5000)` + `Stack(clipBehavior: Clip.none)` | Flutter 3.44.x 中 `Opacity(0)` 会跳过 `paintChild()`，导致 `RepaintBoundary.layer == null`，`toImage()` 抛空错误。离屏副本确保被绘制。 |
| 截图方案替代 PDF 手绘 | 1 套 RepaintBoundary 截图覆盖 8 种图表（约 100 行），手绘需 800+ 行。 |
| Drift 替代 Isar v3 | Isar v3 停止维护；Drift 社区活跃、SQL 稳定。 |
| `keepAlive` 的 `NotifierProvider` | `calculatorProvider` 不 autoDispose，保证跳转历史页再返回时表单数据不丢失。 |
| 纯函数 Domain 层 | 计算逻辑零副作用，配合黄金数据集（±1e-6）防回归。 |

---

## 2. 模块职责

### 2.1 Domain 层

| 文件 | 职责 |
|---|---|
| [soc_calculator.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/soc_calculator.dart) | SOC 含量、碳库储量、碳密度、净变化、恢复速率、损失率计算；输入校验；分层拆分 |
| [resilience_assessment.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/domain/engine/resilience_assessment.dart) | 分层碳库汇总、20/100 年净变化、年恢复速率、秸秆还田情景、恢复状态判定 |
| `models/*` | 4 个不可变数据模型，手写 `toJson()/fromJson()`，无代码生成依赖 |

### 2.2 Data 层

| 文件 | 技术 | 职责 |
|---|---|---|
| [app_database.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/app_database.dart) | Drift (SQLite) | 定义 `HistoryRecords` / `Drafts` 两表；`create()` 建库于应用文档目录 |
| [record_dao.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/record_dao.dart) | Drift 查询 | 历史记录 CRUD、按 ID 批量查询、分页 `getAll`、`getLatest`、损坏行容错跳过 |
| [draft_dao.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/draft_dao.dart) | Drift 查询 | 草稿固定 `id=1`，`insertOnConflictUpdate` 覆盖保存；`getAgeMillis` 用于过期判定 |
| [ai_report_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_service.dart) | Dio SSE | OpenAI 兼容 `/chat/completions` 流式请求；`[DONE]` 终止；`CancelToken` 中断；空闲超时计时器 |
| [ai_report_prompt.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_report_prompt.dart) | — | `systemPrompt`（专家身份）+ `defaultPrompt`（数据模板）+ `fillPrompt()` 占位符替换 |
| [ai_config_service.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/ai_config_service.dart) | secure_storage + SharedPreferences | 5 个服务商预设；API Key 加密存储；其余配置明文存储；`clearAll()` 一键清空 |
| [pdf_exporter.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/pdf_exporter.dart) | pdf 包 | MultiPage 文档（参数表/结果表/恢复力表/8 图/AI 报告）；`captureCharts` 截图 |
| [json_io.dart](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/data/json_io.dart) | file_picker | `ExportRecord` 序列化；`exportToFile` / `importFromFile` |

### 2.3 Presentation 层

**Provider 层（Riverpod 2.6）**：

| Provider | 类型 | 职责 |
|---|---|---|
| `calculatorProvider` | `NotifierProvider`（keepAlive） | 9 个参数更新、计算编排、自动存草稿（2s 防抖）、写历史 |
| `aiReportProvider` | `NotifierProvider` | 流式报告状态机：生成/取消/重置；错误分类 |
| `aiConfigProvider` | `Provider<AiConfigService>` | 配置服务单例 |
| `databaseProvider` | `FutureProvider<AppDatabase>` | 数据库惰性初始化 + dispose 关闭 |
| `recordDaoProvider` / `draftDaoProvider` | `FutureProvider` | DAO 注入（依赖 databaseProvider） |
| `historyListProvider` | `FutureProvider` | 历史列表，`invalidate` 触发刷新 |
| `themeModeProvider` / `seedColorProvider` | `NotifierProvider` | 主题模式与种子色，持久化到 SharedPreferences |

**页面层**：

| 页面 | 职责 |
|---|---|
| [HomePage](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/home/home_page.dart) | 单体页面：双 Tab（计算 / 图表）。计算 Tab=参数输入+结果卡片；图表 Tab=8 图 Carousel + AI 报告卡片。管理 8 个可见 `_chartKeys` 与 8 个离屏 `_pdfChartKeys`。 |
| [HistoryPage](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/history/history_page.dart) | 历史倒序列表、单条删除、JSON 导入/导出、跳转对比 |
| [SettingsPage](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/settings/settings_page.dart) | 服务商下拉、URL/Key/模型输入、思考模式开关与推理强度、主题色板、外观模式、关于 |
| [ComparePage](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/soc_app/lib/presentation/pages/compare/compare_page.dart) | 多记录勾选（≤5）、参数/结果/恢复力横向 DataTable、双记录雷达图叠加 |

**Widget 层**：8 个图表均为独立 `StatelessWidget`，各自封装数据预处理与 `fl_chart` 渲染；`AiReportCard` 处理流式/Markdown/思考过程/错误四种态。

---

## 3. 关键类与函数说明

### 3.1 Domain 层

#### `CalculationParams`（模型）
不可变参数集合，含施肥方式 `fert`、侵蚀强度 `erosion`、取样深度 `depth`、容重 `bd`、`ph`/`wc`/`clay`/`tn`、秸秆相关 `cropBiomass`/`strawCarbonRatio`/`litterCarbonInput`，以及分层列表 `soilLayers`（当前）/`initialLayers`（基准）。`toJson()/fromJson()` 全字段容错。

#### `soc_calculator.dart`

```dart
List<String> validateInput(CalculationParams params)
```
逐字段范围校验（容重 0.5–2.5、pH 3–11、含水/黏粉粒 0–100、全氮 0–10、土层容重 0.8–1.8、SOC 0–100、厚度 >0），返回中文错误信息列表。

```dart
double calculateSOC(CalculationParams params)
```
查表 `_baseData[fert][erosion][depth]` 得基础 SOC，乘以施肥系数 `_fertilizerEffect`（F=1.0，UNF=0.92），缺省回退 10.0，结果 clamp ≥0。

```dart
double calculateCarbonStorage(double soc, double bd, int depthCm)
```
`soc * bd * min(depth, 20) / 100`——碳库储量**仅按表层 20cm 计算**（深层样本也被截断到 20cm）。

```dart
double calculateCarbonDensity(double carbonStorage, int depthCm)
```
`carbonStorage / (depth/100)`，单位体积碳密度。

```dart
double calculateNetChange(double soc, String fert, int erosion)
```
`soc * (1 + fertImpact - erosionImpact)`，其中 `fertImpact` 为 F=+0.05 / UNF=-0.02，`erosionImpact = (erosion/70)*0.3`。**注意：返回的是经调整的绝对 SOC 量级值，并非差分量**（详见 Issues 文档）。

```dart
double calculateRecoveryRate(double netChange, [int years = 20])
```
`netChange / years`，clamp ≥0（负值归零）。

```dart
double calculateLossRate(double soc, String fert)
```
以 `_baseData[fert][0][10]` 为基准，`(base - soc)/base*100`，clamp ≥0。

```dart
List<SoilLayer> splitToLayers(double socValue, double bd, int depthCm)
```
深度 ≤20 单层；>20 拆为 `0-20` 与 `20-depth` 两层，**两层使用相同 socValue 与 bd**。

```dart
({bool success, CalculationResult? result, List<String> errors}) computeAll(CalculationParams params)
```
编排入口：校验 → 计算 6 指标 → 保留 2–3 位小数 → 返回记录。

#### `resilience_assessment.dart`

```dart
double computeCarbonPoolByLayer(double socGkg, double bdGcm3, double thicknessCm)
```
分层碳库 = `soc * bd * thickness / 100`。

```dart
double computeTotalCarbonPool(List<SoilLayer> layers)
```
`fold` 累加各层碳库。

```dart
double computeStrawCarbonInput(double biomassKgha, double carbonRatio, double returnRatio)
```
`biomass * carbonRatio * returnRatio / 10000`（kg/ha → kg C/m² 换算）。

```dart
List<StrawScenario> computeStrawScenarios(biomass, carbonRatio, litterCarbonInput)
```
固定三档还田率 `[0.3, 0.5, 1.0]`，生成 30%/50%/100% 秸秆还田情景。

```dart
({bool success, ResilienceResult? result, List<String> errors}) assessResilience(CalculationParams params)
```
恢复力评估入口：校验土层非空 → 按 `layerId` 前缀过滤 0-20 与全剖面层 → 计算 `finalPool020/060` 与 `initialPool020/060` → 推导 20yr/100yr 净变化与年恢复速率 → 生成秸秆情景 → 判定恢复状态文案。

> ⚠️ 该函数中 `netChange20yr` 与 `netChange100yr` 的深度池对应关系存在不一致，详见 [ISSUES_AND_BUGS.md](./ISSUES_AND_BUGS.md)。

### 3.2 Data 层

#### `AppDatabase`（Drift）
`@DriftDatabase(tables: [HistoryRecords, Drafts])`，`schemaVersion=1`，`create()` 在 `getApplicationDocumentsDirectory()` 下建 `soc_app.db`。两表结构：

- `HistoryRecords`：`id`(自增) · `params`(JSON) · `result`(JSON) · `resilience`(JSON,可空) · `label`(可空) · `createdAt`(毫秒)
- `Drafts`：`id` · `params`(JSON) · `createdAt`，主键固定 id=1

#### `RecordDao`
- `insert(params, result, resilience?, label?)`：JSON 编码后插入，`createdAt=now`
- `getAll({search, offset, limit})`：按 `createdAt desc` 排序，`label.contains` 搜索，**内存切片分页**
- `getByIds(ids)`：按 id 批量 + 倒序
- `getLatest()`：取最新一条
- `_decode` / `_decodeAll`：JSON → 模型，单行损坏 `try/catch` 跳过

#### `DraftDao`
`save()` 用 `insertOnConflictUpdate` 覆盖 id=1 行；`load()` 反序列化；`getAgeMillis()` 返回草稿存活时长用于 5 分钟过期判定；`delete()` 清除。

#### `AiReportService`
```dart
Stream<String> generateStream({baseUrl, apiKey, model, prompt, systemPrompt?,
  enableThinking, reasoningEffort?, extraThinkingBody?, cancelToken?, idleTimeout})
```
构造 `messages`（system 可选 + user），`stream:true`；思考模式注入 `extraThinkingBody` 与 `reasoning_effort`，否则设 `temperature:0.7`；POST 到 `{baseUrl}/chat/completions`，`responseType.stream`；逐行解析 `data:` 前缀，遇到 `[DONE]` 终止；每收到 chunk 重置 60s 空闲计时器，超时则 `cancelToken.cancel()`；`DioException.cancel` 静默返回，其他异常上抛。

> ⚠️ 该流仅 `yield` `delta.content`，未解析 `delta.reasoning_content`，详见 Issues 文档。

#### `AiConfigService`
5 个预设见 `kAiProviderPresets`（DeepSeek/OpenAI/Groq/OpenRouter/自定义）。API Key 走 `FlutterSecureStorage`（Windows DPAPI 关闭向后兼容；Android Keystore），其余配置走 `SharedPreferences`；读取时若用户未保存则回落到预设默认值；`clearAll()` 清全部键。

#### `PdfExporter`
- `generate(params, result, resilience?, aiReport?, chartImages)`：加载 `SimHei.ttf`，构造 `MultiPage`：标题+时间 → 参数表 → 结果表 → 恢复力表 → 8 张图 → AI 报告（正则剥离 Markdown 标记）
- `captureCharts(List<GlobalKey>)`：逐个 `findRenderObject() as RenderRepaintBoundary` → `toImage(pixelRatio:2)` → PNG `Uint8List`，异常逐 key 跳过

#### `JsonIo`
`exportToFile` 调 `FilePicker.saveFile` 选路径并写 JSON（含 `version`/`exportedAt`）；`importFromFile` 调 `FilePicker.pickFiles` 读文件并解析为 `List<ExportRecord>`。

### 3.3 Presentation 层

#### `CalculatorNotifier`（核心状态机）
- 9 个 `update*` 方法：更新单字段 → `copyWith` 新状态 → `_saveDraft()`（2s 防抖写入 DraftDao）
- `calculate()`：调 `computeAll` → 成功则取消草稿计时器 → 用 `splitToLayers` 造当前层 → 以 `erosion:0` 重算 `initSoc` 造基准层 → 组装 `resilienceParams` 调 `assessResilience` → 写状态 → 异步 `RecordDao.insert` 落库；失败则写 errors
- `loadDraft(params)`：草稿恢复入口
- 私有 `_ParamsCopy` 扩展为 `CalculationParams` 提供 `copyWith`（手写，因模型未生成）

#### `AiReportNotifier`
- `generateReport(...)`：读 `calculatorProvider` 的 params/result，`fillPrompt` 组装提示词，新建 `CancelToken`，状态置 `isGenerating`，`StringBuffer` 累积 chunk 实时刷新 `streamContent`；`DioException` 分类映射为中文错误（超时/连接/响应码）
- `cancel()` / `reset()`：中断并清空
- `_buildPromptData`：把 params/result/resilience 拍平为占位符字典

#### `HomePage`（`ConsumerStatefulWidget`）
维护 6 个 `TextEditingController`、`_tabIndex`、`_chartTabIndex`、`_pdfExporting`；`initState` postFrame 同步控制器并 `_checkDraft`；`build` 用 `Stack(clipBehavior:Clip.none)` 叠加正常 `IndexedStack` 与离屏 `Positioned(left:5000)` 的 8 图 PDF 副本（强制 lightTheme）；`_exportPdf` 区分 Android（写文件 + `Share.shareXFiles`）与桌面（`FilePicker.saveFile`）。

#### `_ChartCarousel`
8 Tab `TabController` + `IndexedStack`，每个图表包 `RepaintBoundary` + `SingleChildScrollView`，与父状态双向同步 `tabIndex`。

---

## 4. 依赖关系

### 4.1 模块依赖图

```
UI (pages/widgets)
   │  watch / read
   ▼
Providers ──► Domain (engine + models)   [纯 Dart]
   │
   ├──► Data: AiReportService (Dio)
   ├──► Data: RecordDao / DraftDao ──► AppDatabase (Drift/SQLite)
   ├──► Data: AiConfigService (secure_storage / prefs)
   ├──► Data: PdfExporter (pdf + rendering)
   └──► Data: JsonIo (file_picker)
```

Domain 层不依赖任何上层与 Flutter；Data 层依赖 Domain 模型；Presentation 通过 Provider 间接持有 Data 服务。

### 4.2 第三方依赖（pubspec.yaml）

| 包 | 版本 | 用途 |
|---|---|---|
| `flutter_riverpod` / `riverpod_annotation` | ^2.6.1 | 状态管理 |
| `fl_chart` | ^0.70.2 | 8 种图表 |
| `drift` / `sqlite3_flutter_libs` / `path_provider` / `path` | ^2.25 / ^0.5 / ^2.1 / ^1.9 | SQLite ORM 与文件路径 |
| `dio` | ^5.7.0 | HTTP / SSE 流式 |
| `flutter_markdown` | ^0.7.6 | AI 报告 Markdown 渲染 |
| `pdf` | ^3.11.3 | PDF 生成 |
| `flutter_secure_storage` | ^9.2.4 | API Key 加密存储 |
| `share_plus` | ^10.1.4 | Android PDF 分享 |
| `file_picker` | ^8.3.7 | JSON/PDF 文件选择 |
| `url_launcher` | ^6.3.2 | 打开 GitHub issues |
| `shared_preferences` | ^2.5.3 | 非敏感配置持久化 |
| `json_annotation` | ^4.9.0 | 模型注解（实际手写未生成） |

dev：`flutter_lints`、`build_runner`、`json_serializable`、`riverpod_generator`、`drift_dev`、`mocktail`（测试 mock）。

> 注：`json_serializable`/`riverpod_generator` 声明但模型与 Provider 均手写，仅 `app_database.g.dart` 由 `drift_dev` 生成。

### 4.3 平台差异

| 行为 | Android | Windows |
|---|---|---|
| PDF 保存 | `share_plus` 分享菜单 | `FilePicker.saveFile` 原生对话框 |
| 安全存储 | Android Keystore | DPAPI（关闭向后兼容） |
| 网络权限 | Release APK 需手动声明 `INTERNET` | 默认可用 |

---

## 5. 项目运行方式

### 5.1 环境要求

- Flutter SDK ≥ 3.44（Dart ≥ 3.12）
- Windows 构建：Visual Studio 2022 Build Tools 含 **ATL** 组件
- Android 构建：Android SDK 36+、`cmdline-tools`、接受 licenses
- 国内网络：`flutter pub get` 与 Gradle 通常需代理或镜像

### 5.2 开发运行

```bash
cd soc-assessment/soc_app
flutter pub get
flutter run -d windows      # Windows 桌面
flutter run -d android      # Android 设备
flutter run -d chrome       # Web 调试
```

### 5.3 测试与静态检查

```bash
cd soc-assessment/soc_app
flutter test                # 53 个单测，覆盖引擎/DAO/AI Service/Provider
dart analyze lib/           # 0 error / 0 warning
```

测试分布：引擎计算 27（含 2 组黄金数据集 ±1e-6）、RecordDao 7、DraftDao 6、AiReportService 7、AiReportState 3、HistoryProvider 3。

CI（[.github/workflows/ci.yml](file:///c:/Users/Bot/Downloads/魏总的小项目/soc-assessment/.github/workflows/ci.yml)）：Ubuntu 上 `flutter pub get` → `dart analyze lib/` → `flutter test`，触发于 main 的 push/PR。

### 5.4 构建打包

```bash
# Windows（需 VS 开发者命令行环境）
flutter build windows --release
# 产物：build/windows/x64/runner/Release/

# Android（注意：项目路径含中文会导致 AOT 失败，需复制到纯英文路径）
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk

# Web
flutter build web --release
```

**关键注意**：
1. **Release APK 必须在 `android/app/src/main/AndroidManifest.xml` 手动添加 `<uses-permission android:name="android.permission.INTERNET"/>`**（Debug 自动添加，Release 不会，缺失会 `DioExceptionType.connectionError`）。
2. **项目路径含中文（`魏总的小项目`）会触发 `dart snapshot generator failed with exit code 255`**，需复制到 `C:\dev\soc-app` 等纯英文路径再 AOT 构建。
3. Windows 构建若报 `atlstr.h` 缺失，需安装 `Microsoft.VisualStudio.Component.VC.ATL`。

### 5.5 首次使用配置

AI 报告功能需在设置页配置：AppBar 齿轮 → 选择服务商（默认 DeepSeek）→ 填 API Key 与模型 → 可选开启思考模式与推理强度。

### 5.6 数据流总览

**计算流**：用户输入 → `CalculatorNotifier.update*` → 2s 防抖存草稿 → 点“计算” → `computeAll` + `assessResilience` → 写状态 + `RecordDao.insert` 落库 → UI 渲染。

**AI 流**：点“生成报告” → 读 `AiConfigService` → `AiReportNotifier.generateReport` → `AiReportService.generateStream` SSE → chunk 累积实时刷新 → `[DONE]` 终止。

**PDF 流**：点 PDF → `PdfExporter.captureCharts(_pdfChartKeys)` 截 8 图 → `PdfExporter.generate` 组装 → 平台分支保存/分享。

---

## 6. 扩展点

- **新 AI 模型/服务商**：在 `kAiProviderPresets` 增加条目即可
- **新图表**：在 `_ChartCarousel.charts` 与 `_buildPdfChartWidgets` 同步追加（注意保持两处 key 列表长度一致）
- **云同步**：`RecordDao` 层预留，可新增远程 API 调用
- **路由**：页面增多后可引入 `go_router` 替代当前 `Navigator.push`
- **数据库迁移**：`AppDatabase.migration.onUpgrade` 已留空钩子，bump `schemaVersion` 时填充
