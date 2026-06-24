# 架构文档

## 1. 系统架构概览

```
┌─────────────────────────────────────────────┐
│                Presentation                  │
│  ┌──────────┐ ┌──────┐ ┌──────┐ ┌────────┐  │
│  │ HomePage │ │History│ │Setting│ │Compare │  │
│  │  (输入/  │ │ 页面  │ │ 页面  │ │ 页面   │  │
│  │  结果/   │ │      │ │      │ │        │  │
│  │  图表/   │ │      │ │      │ │        │  │
│  │  AI报告) │ │      │ │      │ │        │  │
│  └────┬─────┘ └──┬───┘ └──┬───┘ └───┬────┘  │
│       │          │        │         │        │
│  ┌────▼──────────▼────────▼─────────▼────┐   │
│  │          Riverpod Providers           │   │
│  │  Calculator / AiReport / AiConfig    │   │
│  │  RecordDao / DraftDao / History      │   │
│  └────────────────┬─────────────────────┘   │
├───────────────────┼─────────────────────────┤
│        Data Layer │                         │
│  ┌────────────────▼─────────────────────┐   │
│  │  AiConfigService  │  AiReportService  │   │
│  │  JsonIo           │  PdfExporter      │   │
│  │  RecordDao / DraftDao / AppDatabase  │   │
│  └──────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│           Domain Layer (Pure Dart)          │
│  ┌──────────────┐  ┌─────────────────────┐  │
│  │  Engine      │  │  Models             │  │
│  │  SocCalculator│  │  CalculationParams │  │
│  │  Resilience  │  │  CalculationResult  │  │
│  │  Assessment  │  │  ResilienceResult   │  │
│  └──────────────┘  │  SoilLayer          │  │
│                    └─────────────────────┘  │
└─────────────────────────────────────────────┘
```

## 2. 分层设计

### Domain 层（纯 Dart，零依赖）

所有计算逻辑为纯函数，无副作用，可直接移植。

- **`domain/engine/soc_calculator.dart`** — `computeAll()` 接收 `CalculationParams`，返回 `CalculationResult`
- **`domain/engine/resilience_assessment.dart`** — `assessResilience()` 接收分层数据，返回 `ResilienceResult`
- **`domain/models/`** — 4 个手写模型类，含 `toJson()/fromJson()`

**黄金数据集验证**: 两组参考数据，精度 ±1e-6，防止回归。

### Data 层

| 模块 | 技术 | 职责 |
|---|---|---|
| `app_database.dart` | Drift (SQLite) | 建表、数据库初始化 |
| `record_dao.dart` | Drift 查询 | 历史记录 CRUD、分页、批量 |
| `draft_dao.dart` | Drift 查询 | 草稿（固定 id=1）、过期检查 |
| `ai_report_service.dart` | Dio SSE | 流式 API 请求、[DONE] 终止、CancelToken |
| `ai_report_prompt.dart` | — | 默认提示词模板、fillPrompt() |
| `ai_config_service.dart` | flutter_secure_storage + SharedPreferences | 多模型 API 配置持久化 |
| `pdf_exporter.dart` | pdf 包 | PDF 文档生成、图表截图 |
| `json_io.dart` | file_picker | JSON 导入/导出 |

### Presentation 层

**Provider 层**（Riverpod 2.6）：

| Provider | 类型 | 用途 |
|---|---|---|
| `calculatorProvider` | NotifierProvider (keepAlive) | 9 个参数更新、计算、自动存历史/草稿 |
| `aiReportProvider` | NotifierProvider | 流式报告状态、取消、重置 |
| `aiConfigProvider` | Provider\<AiConfigService\> | API 配置服务单例 |
| `databaseProvider` | FutureProvider\<AppDatabase\> | 数据库延迟初始化 |
| `recordDaoProvider` | FutureProvider\<RecordDao\> | DAO 注入 |
| `draftDaoProvider` | FutureProvider\<DraftDao\> | 草稿 DAO 注入 |
| `historyListProvider` | FutureProvider | 历史记录列表（invalidate 刷新） |

**页面层**：

- `HomePage` — 单体页面（参数输入 + 结果卡片 + 8 图表 IndexedStack + AI 报告）
- `HistoryPage` — 历史列表 + JSON 导入/导出
- `SettingsPage` — 多模型配置 + 思考模式
- `ComparePage` — 多记录勾选 + 对比表格 + 雷达图

**Widget 层**：

- 8 个图表组件，各自独立 `StatelessWidget`
- `AiReportCard` — 流式文本 / flutter_markdown 渲染 Markdown / 思考过程 / 错误
- `ComparisonRadarChart` — 双数据集叠加雷达图

## 3. 数据流

### 计算流

```
用户输入 → calculatorProvider.update*() → CalculatorNotifier
  → (2s debounce) DraftDao.save() ← 自动草稿
  → 用户点击"计算"
  → CalculatorNotifier.calculate()
    → SocCalculator.computeAll(params)
    → RecordDao.insert(params, result, resilience)
    → 状态更新 → UI 渲染
```

### AI 报告流

```
用户点击"生成报告"
  → _generateReport() 读取 AiConfigService (baseUrl, apiKey, model, thinking params)
  → AiReportNotifier.generateReport()
    → AiReportService.generateStream() — SSE 请求
    → stream 逐 chunk 累积
    → state.streamContent 更新 → AiReportCard 实时渲染
  → [DONE] 终止
  → isGenerating = false
  → 用户可"重新生成"或"取消"
```

### PDF 导出流

```
用户点击 PDF 按钮
  → PdfExporter.captureCharts(_chartKeys) — 8 张 RepaintBoundary 截图
  → PdfExporter.generate(params, result, resilience, chartImages, aiReport)
    → pw.Document.addPage(MultiPage)
      → 标题 + 参数表 + 结果表 + 恢复力表
      → 8 张图表图片
      → AI 报告（纯文本）
    → pdf.save() → Uint8List
  → 平台分支保存：
    Android: writeAsBytes → Share.shareXFiles
    Windows: FilePicker.saveFile → writeAsBytes
```

## 4. 关键设计决策

### IndexedStack 替代 TabBarView

PDF 需要截图所有 8 个图表。TabBarView 使用懒加载，未访问的 Tab 在渲染树中不存在，无法截图。IndexedStack 将所有 children 常驻渲染树，任意 Tab 均可截图。

代价：8 图表同时占用内存。对此工具类 app 可忽略。

### 截图方案替代 PDF 绘图

手动用 `pdf` 包绘制 8 种图表需 8 倍工作量。RepaintBoundary + `toImage()` 截图方案 1 套代码覆盖全部图表。约 100 行 vs 800+ 行。

### Drift 替代 Isar v3

Isar v3 停止维护。Drift 社区活跃，SQL 稳定。

### 纯文本 PDF AI 报告

`pdf` 包无 Markdown 解析器。选用纯文本剥离 Markdown 符号（选项 A），在 PDF 中标注"完整格式见 APP 内"。

### keepAlive NotifierProvider

`calculatorProvider` 使用 NotifierProvider（非 autoDispose），确保页面跳转至历史页再返回时，表单数据不丢失。

## 5. 安全

- API Key 永不在源码中硬编码
- `flutter_secure_storage` 使用平台原生加密（Windows DPAPI / Android Keystore）
- `WindowsOptions(useBackwardCompatibility: false)` 避免 DPAPI 兼容模式
- 所有 `readApiKey()` 调用包 try/catch，失败降级返回 null

## 6. 平台差异

| 行为 | Android | Windows |
|---|---|---|
| PDF 保存 | share_plus 分享菜单 | FilePicker.saveFile() |
| 安全存储 | Android Keystore | DPAPI |
| 文件选择 | FilePicker | FilePicker |

## 7. 扩展点

- **云同步**: `RecordDao` 层预留，可添加远程 API 调用
- **新模型**: 在 `kAiProviderPresets` 中添加条目即可
- **新图表**: 在 `_ChartCarousel.charts` 列表中添加即可
- **路由**: 页面增多后可引入 `go_router`
