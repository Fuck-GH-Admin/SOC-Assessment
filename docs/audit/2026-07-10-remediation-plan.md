# 2026-07-10 修复执行计划

## 背景

本轮修复基于两个原始资料：

- `../index_new.html`：旧版单页原型，提供原始界面、数据表和部分 JS 计算逻辑。
- `../第五章 不同侵蚀程度下土壤有机.docx`：第五章方法说明，提供 SOC 碳库、净变化量、恢复速率和秸秆还田公式。

执行原则：不把项目中任何现有代码或文档当作权威；以原始资料中的数据表和方法公式为基准，代码只作为待验证实现。

## 本轮口径决策

1. `baseData` 表已按施肥、侵蚀和土层深度给出实测/基础 SOC 值，因此 SOC 计算不再叠加旧 HTML 中未解释清楚的额外 `erosionCoeff` 和 `depthFactor`，避免重复计算侵蚀/深度影响。
2. `depth` 字段按原 HTML 选项解释为土层键：`10 => 0-20cm`、`25 => 20-30cm`、`35 => 30-40cm`、`45 => 40-50cm`、`55 => 50-60cm`，不再当作从地表到该厘米数的剖面深度。
3. 单层碳库使用 DOCX 公式 `SOC × BD × thickness / 100`。
4. CK 剖面评估使用完整 0-60cm 分层数据：
   - 0-60cm 当前剖面相对 CK 的静态碳库差；
   - 0-20cm 当前表层相对 CK 的静态碳库差；
   - 静态差值 / 20 只作为明确标注的折算代理。
5. 现阶段以 `erosion=0`、相同施肥方式和相同土层作为 CK。原始 DOCX 未提供逐年时间序列末期数据，因此应用不再把这些字段表述为真实 20 年/100 年预测或恢复趋势。

## 执行步骤

- [x] 写入本计划文档。
- [x] 修复计算引擎：深度层语义、单层碳库、0-60cm 分层静态 CK 差异。
- [x] 修复状态一致性：参数变化清空旧结果，AI 报告绑定计算指纹。
- [x] 修复 AI 提示词：静态 CK 差异、折算代理与单位同步。
- [x] 修复历史导入：保留原始创建时间，增加删除确认。
- [x] 修复 PDF：单位/标签、图表截图完整性检查。
- [x] 增加 PDF 应用本地持久化、历史记录关联和文件生命周期管理。
- [x] 增加算法版本、数据库 v3 迁移和 JSON v2 数据契约。
- [x] 增加历史详情、重命名、参数载入和原子导入。
- [x] 修复重复计算、参数编辑/异步计算竞态和历史缓存失效。
- [x] 修复自定义 AI 接口无 Key、完整 endpoint 重复拼接和 SSE 格式兼容。
- [x] 整理文件结构：新增项目结构说明，明确 release/temp 为本地产物。
- [x] 运行 `flutter analyze` 和 `flutter test`，记录结果。

## 暂不在本轮完成

- 真正的 20 年/100 年动态模拟模型：需要原始逐年观测或明确模型参数。
- 大规模 UI 重构为左右分栏/路由体系：本轮先修正确性和数据链路。
- 依赖大版本整体升级：当前版本已通过分析、测试和构建，升级需单独回归。

## 执行记录

### 已完成

- 修复计算引擎土层语义：`10/25/35/45/55` 作为土层键而非剖面厘米数。
- 单层碳库按土层厚度计算，表层为 20cm，其余层为 10cm。
- CK 剖面比较改为完整 0-60cm 分层，并校验连续覆盖、20cm 边界、厚度和当前/CK 划分一致性。
- 参数变化后清空旧计算结果，避免参数/结果/图表/AI/PDF 混用。
- AI 报告增加计算指纹，PDF 只导出与当前计算匹配的 AI 报告。
- AI 提示词补齐静态 CK 差异、折算代理、秸秆情景和正确单位。
- 历史导入保留原始 `createdAt`；删除历史记录增加确认弹窗。
- PDF 标签同步当前口径，图表截图增加 end-of-frame 等待和完整性检查。
- PDF 固定保存到应用文档目录的 `SOC-Shield/report_pdfs/`，数据库升级到 v3 并记录 `pdfPath` 与算法版本。
- 同一计算记录重复导出时覆盖稳定文件名，避免产生不可管理的孤立 PDF。
- 历史页增加 PDF 打开/分享、目录定位、路径复制、失效关联清理和随记录删除。
- 碳库饼图改为基于分层碳库而不是 SOC 浓度占比。
- 图表 SOC 值统一走当前 `calculateSOCValue()` 口径。
- 移除 `AGENTS.md` 中的明文 API Key。
- 将 v1.1.3 旧架构、功能和问题报告移入 `docs/history/legacy-v1.1.3/`。
- 新增 `docs/project/architecture.md`、`logic-and-data-contract.md` 和 `structure.md`。
- 新增 `docs/project/pdf-report-storage.md` PDF 持久化设计说明。

### 验证结果

```text
cd C:\Users\Bot\Bot\SOC\soc-assessment\soc_app
dart analyze lib test
# No issues found!

flutter test
# +96: All tests passed!

flutter build windows --release
# Built build\windows\x64\runner\Release\soc_app.exe

flutter build apk --release
# Built build\app\outputs\flutter-apk\app-release.apk (70.6MB)

# 额外运行验证
# Windows Release 启动 10 秒无立即崩溃
# Android 真机安装/启动/默认计算/历史详情/PDF 生成分享/持久化关联通过
# 运行流程中无 E/flutter、Unhandled Exception 或 FATAL EXCEPTION
```

### 测试发布包

```text
release\v1.1.4-logic-consistency-20260710\
├── soc-assessment-v1.1.4-android.apk
├── soc-assessment-v1.1.4-windows-x64.zip
├── soc-assessment-v1.1.4-source.zip
├── BUILD-INFO.txt
└── SHA256.txt
```

### 仍需后续专项处理

- 真实 20 年/100 年动态模拟需要逐年末期数据或明确模型参数，目前只提供静态 CK 差异。
- 对比页雷达图仍只展示前两条记录，本轮仅增加提示；如需 3-5 条雷达图，需要扩展图表组件。
- `flutter_markdown` 已被上游标记为 discontinued，需单独迁移到替代包。
- Android Release 当前沿用既有 Android Debug 签名证书，以保持对本机既有测试包的升级兼容；正式公开发布前需要确定长期签名策略。
- `share_plus` 在 Flutter 3.44.2 构建时提示未来 Built-in Kotlin 迁移要求，当前不影响构建和运行。
