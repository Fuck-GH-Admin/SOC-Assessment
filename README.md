# 碳盾 SOC-Shield

Flutter 跨平台土壤有机碳（SOC）评估工具，当前支持 Windows 与 Android。

Linux/Ubuntu 桌面版和 `.deb` 分发列为后续规划，当前尚未纳入正式构建目标；相关依赖清单见[开发环境标准](docs/project/development-environment.md)。

- 当前应用版本：**1.1.5+3**
- 当前算法版本：**v2**
- 当前数据库版本：**v3**

## 功能

- 按“施肥处理 × 侵蚀深度 × 土层”查询原始 SOC 数据。
- 按真实土层厚度换算当前土层及 0–60cm 剖面碳库。
- 与同施肥、同土层、侵蚀 0cm 的 CK 做静态比较。
- 恢复力评估：分层证据、侵蚀亏缺矩阵、秸秆情景覆盖对照（第五章 5.1 口径）。
- 生成 30%、50%、100% 秸秆还田碳输入情景。
- 叙事化图表：按"概览 / 剖面与侵蚀 / 管理情景 / 高级分析"分区，每图先给由数据推导的一句话结论。
- 报告页：本地确定性评估摘要（默认、离线），AI 辅助解读为可选，支持多家 OpenAI 兼容接口。
- 生成 PDF，并为每条历史记录持久化一份应用本地副本。
- 评估记录支持表格化浏览（桌面）、详情、重命名、参数载入、JSON 导入导出、PDF 管理和多记录对比。
- 桌面宽屏使用导航栏 + 参数/结果双栏工作台；移动端使用底部导航，两端页面结构一致。
- 2 秒防抖保存草稿，未完成草稿最多保留 7 天。

## 重要口径

pH、含水量、黏粉粒和全氮当前只作为辅助观测信息，不进入 SOC 查表或碳库换算。

原始资料没有逐年末期值或可复现的动态模型参数。因此应用中的 0–60cm/0–20cm 指标是**当前侵蚀处理相对 CK 的静态差异**，不是 20 年或 100 年预测。

完整业务契约见：

- [业务口径与数据契约](docs/project/logic-and-data-contract.md)
- [PDF 本地持久化](docs/project/pdf-report-storage.md)
- [项目结构](docs/project/structure.md)
- [开发环境标准](docs/project/development-environment.md)
- [本轮逻辑一致性审计](docs/audit/2026-07-10-logic-consistency-audit.md)

## 快速开始

Linux 主开发环境先按[开发环境标准](docs/project/development-environment.md)初始化，并在当前终端执行 `source tooling/dev-env.sh`。

```powershell
cd soc_app
flutter pub get
flutter run -d windows
```

Android：

```powershell
flutter devices
flutter run -d <device-id>
```

发布构建见 [BUILD.md](BUILD.md)。

## 验证

```powershell
cd soc_app
flutter analyze
flutter test
```

当前基线：

- Flutter 3.44.2
- Dart 3.12.2
- 静态分析：通过
- 自动化测试：96 项全部通过

## 目录

```text
soc-assessment/
├── soc_app/          # Flutter 应用
├── docs/
│   ├── audit/        # 当前审计与修复记录
│   ├── project/      # 当前业务、结构和存储文档
│   ├── user-guide/   # 用户说明书源码、资源和发布准备
│   └── history/      # 旧版本报告与归档文档
├── release/          # 本地发布产物（Git 忽略）
├── temp/             # 本地临时文件（Git 忽略）
├── AGENTS.md
├── BUILD.md
├── LICENSE
└── README.md
```

## License

MIT
