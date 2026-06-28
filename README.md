# 碳盾 SOC-Shield — 土壤有机碳评估系统

基于 Flutter 的跨平台（Android / Windows）土壤有机碳（SOC）评估工具，支持参数计算、多维度图表分析、AI 报告生成与 PDF 导出。

## 快速开始

```bash
cd soc_app
flutter pub get
flutter run          # 启动桌面端（Windows）
flutter run -d android   # 启动移动端（Android）
```

> 完整编译打包指南见 [BUILD.md](./BUILD.md)
> **重要**：Release APK 需手动添加 INTERNET 权限，详见 [BUILD.md](./BUILD.md#androidapk)

## 主要功能

- **SOC 计算**：基于施肥处理、侵蚀强度、土壤容重等参数计算 SOC 含量、碳库储量、碳密度、恢复速率等指标
- **8 种可视化图表**：侵蚀条形图、深度折线图、时间序列图、雷达评估图、饼图、散点图、填充对比图、热力图
- **AI 报告**：流式生成专业中文评估报告，支持思考模式（DeepSeek）
- **PDF 导出**：包含参数表、结果表、图表截图、AI 报告
- **历史记录**：本地 SQLite 存储，支持导入/导出 JSON
- **多记录对比**：选择 2+ 条记录进行参数/结果/雷达图对比
- **草稿自动保存**：2 秒防抖自动保存，5 分钟过期清理

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.12+ / Dart 3.12+ |
| 状态管理 | Riverpod 2.6 |
| 数据库 | Drift (SQLite) |
| 图表 | fl_chart 0.70 + CustomPainter |
| AI 请求 | Dio 5 (SSE 流式) |
| PDF | pdf 3.11 (RepaintBoundary 截图) |
| 安全存储 | flutter_secure_storage |
| 分享 | share_plus |
| 测试 | flutter_test + mocktail |

## 项目结构

```
soc_app/lib/
├── domain/engine/        # 计算引擎（纯函数）
├── domain/models/        # 数据模型
├── data/                 # 数据层（数据库、API、文件 I/O）
├── presentation/
│   ├── providers/        # Riverpod 状态
│   ├── pages/            # 页面（首页、历史、设置、对比）
│   └── widgets/          # 组件（8 图表、AI 报告卡片）
test/                     # 53 个单元测试
```

## 配置

首次使用 AI 报告功能需在设置页面配置 API：

1. 点击 AppBar 齿轮图标 → 设置
2. 选择服务商（DeepSeek / OpenAI / Groq / OpenRouter / 自定义）
3. 填入 API Key 和模型名称
4. 支持开启思考模式（DeepSeek 专属）

## 测试

```bash
cd soc_app
flutter test           # 53 tests, all pass
dart analyze lib/      # 0 error, 0 warning（仅 test/ 有 3 个 info/warning）
```

## License

MIT
