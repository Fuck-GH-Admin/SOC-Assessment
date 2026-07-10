# 当前架构

## 分层

```text
Presentation
  pages / providers / charts
          │
          ▼
Domain
  calculation models / SOC engine / CK profile assessment
          │
          ▼
Data
  Drift database / JSON / PDF / AI service / secure settings
```

### Domain

- `soc_calculator.dart`
  - 原始 SOC 表查询
  - 输入校验
  - 土层定义
  - 单层碳库、碳密度、同层 CK 差和损失率
- `resilience_assessment.dart`
  - 0–60cm 剖面结构校验
  - 当前剖面与 CK 剖面静态差
  - 秸秆还田情景
- `models/`
  - 参数、结果、土层和情景的 JSON 模型

### Data

- `app_database.dart`：Drift 数据库，schema v3。
- `record_dao.dart`：历史记录、算法版本、PDF 路径和名称。
- `draft_dao.dart`：单草稿保存。
- `json_io.dart`：版本化 JSON，文件大小与记录数上限。
- `pdf_report_storage.dart`：应用报告目录和受控删除。
- `pdf_exporter.dart`：报告生成与图表截图。
- `ai_report_service.dart`：OpenAI 兼容 SSE 流。
- `ai_config_service.dart`：服务商、模型、API Key 和思考参数。

### Presentation

- `CalculatorNotifier`
  - 参数变化立即使旧结果失效。
  - 计算 generation id 防止旧异步结果覆盖新输入。
  - 成功写入历史后主动刷新历史缓存。
- `AiReportNotifier`
  - 计算指纹绑定报告。
  - generation id 与 CancelToken 防止取消竞态。
- `HomePage`
  - 参数、结果、图表、AI 和 PDF。
- `HistoryPage`
  - 详情、重命名、参数载入、JSON、PDF 生命周期。
- `ComparePage`
  - 最多 5 条表格对比；雷达图展示选择顺序中的前两条。

## PDF 导出

正常浏览时只渲染当前图表。导出开始后，应用临时在屏幕外挂载 8 个固定尺寸的
`RepaintBoundary`，等待一帧后截图，生成 PDF，再卸载隐藏图表层。

PDF 首先写入：

```text
ApplicationDocumentsDirectory/SOC-Shield/report_pdfs/
```

若当前计算已有历史记录 ID，则使用稳定文件名 `soc-report-<id>.pdf` 并更新数据库关联。

## 数据一致性边界

- 当前结果、AI 报告和 PDF 都绑定同一组计算参数。
- 修改任意参数会清空旧结果并取消旧 AI 状态。
- 算法版本写入历史和 JSON；旧版本记录可查看但不应直接比较。
- 从历史载入只恢复参数，重新计算使用当前算法。

科学口径见 [logic-and-data-contract.md](logic-and-data-contract.md)。
