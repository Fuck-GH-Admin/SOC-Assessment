# 功能文档

## 1. 参数输入与计算

### 输入参数

| 参数 | 范围 | 说明 |
|---|---|---|
| 施肥方式 | F / UNF | 施肥 / 未施肥 |
| 侵蚀程度 | 0–70 cm | 步长 10 cm |
| 取样深度 | 10–55 cm | 5 档可选 |
| 土壤容重 | 0.5–2.5 g/cm³ | |
| pH 值 | 3–11 | |
| 含水量 | 0–100% | |
| 黏粉粒含量 | 0–100% | |
| 全氮含量 | 0–10 g/kg | |

### 输出指标

- **SOC 含量** (g/kg) — 土壤有机碳浓度
- **碳库储量** (kg C/m²) — 单位面积碳储量
- **碳密度** (kg C/m³) — 单位体积碳密度
- **碳库净变化量** (kg C/m²) — 相对基准的变化
- **年恢复速率** (kg C/m²/yr) — 碳库年变化速率
- **SOC 损失率** (%) — 相对损失百分比

### 恢复力评估

- 分层碳库计算（0–20 cm / 0–60 cm）
- 20 年/100 年净变化量预测
- 年恢复速率
- 恢复状态判定（恢复 / 退化 / 稳定）
- 秸秆还田情景模拟（低/中/高还田率）

---

## 2. 图表分析

8 种图表，由 TabBar + IndexedStack 管理，常驻内存以确保 PDF 截图可用。

| # | 图表 | 类型 | 用途 |
|---|---|---|---|
| 1 | 侵蚀条形图 | BarChart | 不同侵蚀程度下 SOC 对比 |
| 2 | 深度折线图 | LineChart | SOC 随深度变化趋势 |
| 3 | 时间序列图 | LineChart | 碳库随时间演替 |
| 4 | 雷达评估图 | RadarChart | 多维度综合评分 |
| 5 | 碳库饼图 | PieChart | 碳库组成占比 |
| 6 | 关联散点图 | ScatterChart | SOC 与各参数相关性 |
| 7 | 填充对比图 | LineChart (fill) | F/UNF 填充对比 |
| 8 | 热力图 | CustomPainter | 多参数交叉分析 |

---

## 3. AI 报告

### 支持的提供商

| 提供商 | 基础 URL | 思考模式 |
|---|---|---|
| DeepSeek | https://api.deepseek.com | ✅ |
| OpenAI | https://api.openai.com/v1 | ❌ |
| Groq | https://api.groq.com/openai/v1 | ❌ |
| OpenRouter | https://openrouter.ai/api/v1 | ❌ |
| 自定义 | 用户指定 | 取决于提供商 |

### 思考模式（DeepSeek 专属）

- 推理强度: low / medium / high
- 通过 `thinking: {"type": "enabled"}` 和 `reasoning_effort` 参数开启
- 响应中包含 `reasoning_content` 字段，在 UI 中折叠显示

### 流式输出

- 基于 Dio + SSE (Server-Sent Events)
- `[DONE]` 终止符判定
- CancelToken 支持中断
- 错误分类提示（超时 / 网络 / 服务端）

### 报告内容

- 当前碳库状况解读
- 侵蚀影响评估
- 种植建议
- 土壤恢复力综合评价

---

## 4. PDF 导出

### 生成内容（按页面顺序）

1. 标题 + 时间戳
2. 输入参数表
3. 计算结果表
4. 土壤恢复力评估表
5. 8 张图表截图（RepaintBoundary → PNG）
6. AI 评估报告（纯文本，Markdown 符号已剥离）

### 保存方式

| 平台 | 方式 |
|---|---|
| Android | share_plus 分享菜单（可保存/发送） |
| Windows | FilePicker.saveFile() 原生保存对话框 |

### 中文字体

- 使用 SimHei (黑体) 子集化字体（~0.9MB，覆盖 3449 个常用 CJK 字符）
- 通过 fonttools 子集化：`pyftsubset SimHei.ttf --text-file=cjk-3500.txt --output-file=SimHei-subset.ttf`

---

## 5. 历史记录

### 存储

- SQLite (Drift ORM)
- `history_records` 表：id, params(JSON), result(JSON), resilience(JSON), label, createdAt
- `drafts` 表：id=1, params(JSON), createdAt

### 操作

- 查看：倒序列表，显示标签 + 时间 + SOC 值
- 删除：单条删除
- 导入：`JsonIo.importFromFile()` → FilePicker → JSON 解析 → DB 批量插入
- 导出：DB 读取 → `JsonIo.exportToFile()` → FilePicker 保存 → JSON 文件

### 草稿

- 每次参数变化触发自动保存（2 秒防抖）
- 页面加载时检查 5 分钟内草稿，弹出恢复对话框
- `_draftChecked` 守卫防止 rebuild 时多次弹窗

---

## 6. 记录对比

- 从历史页面进入
- 勾选 2+ 条记录
- 对比视图：参数表 / 结果表 / 恢复力表（水平滚动 DataTable）+ 雷达图叠加
- 雷达图支持双数据集叠加（蓝/红配色 + 手动图例）

---

## 7. 配置

### API 配置（持久化）

- API Key → `flutter_secure_storage`（Windows DPAPI，Android Keystore）
- 服务商预设、Base URL、模型名、思考模式开关 → `SharedPreferences`
- `clearAll()` 一键清除全部配置

### 字体

- `assets/fonts/SimHei-subset.ttf`，仅用于 PDF 导出
- App UI 使用系统默认字体

---

## 8. 质量保证

### 测试覆盖

```
$ flutter test
  00:02 +47: All tests passed!

  27 — 引擎计算（含 2 组黄金数据集 ±1e-6）
   7 — RecordDao CRUD
   6 — DraftDao 生命周期
   7 — AI Report Service（Dio + SSE 流式）
```

### 代码分析

```
$ dart analyze lib/
  3 issues found (全部 info-level, pre-existing)
```
