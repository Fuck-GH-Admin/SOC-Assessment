# 项目文件结构说明

## 当前建议结构

```text
soc-assessment/
├── soc_app/                 # Flutter 主项目（Android / Windows）
│   ├── lib/
│   │   ├── core/            # 主题等通用能力
│   │   ├── data/            # 数据库、AI、PDF、JSON I/O
│   │   ├── domain/          # 纯计算引擎与模型
│   │   └── presentation/    # 页面、Provider、图表组件
│   ├── test/                # 单元测试
│   ├── android/             # Android 平台工程
│   ├── windows/             # Windows 平台工程
│   └── assets/              # 字体、图标等资源
├── docs/
│   ├── audit/               # 审计、修复计划、验证记录
│   ├── project/             # 项目结构与维护说明
│   ├── history/             # 历史报告
│   └── superpowers/specs/   # 迁移设计资料
├── release/                 # 本地发布产物，仅本地保留，不提交
└── temp/                    # 本地临时文件，仅本地保留，不提交
```

## 整理原则

1. 应用源码只放在 `soc_app/`。
2. 审计、算法口径、修复计划放在 `docs/audit/`，避免顶层继续堆积临时说明。
3. 构建产物和安装包放在 `release/`，并由 `.gitignore` 忽略。
4. 临时 PDF、字体实验、抓取文件放在 `temp/`，并由 `.gitignore` 忽略。
5. 不在仓库写入真实 API Key、本地 SDK 路径或个人机器配置。

## 应用运行时文件

应用运行时数据不放进源码目录：

```text
ApplicationDocumentsDirectory/
├── soc_app.db                  # Drift/SQLite 数据库
└── SOC-Shield/
    └── report_pdfs/            # 与历史记录关联的持久化 PDF
        └── soc-report-<记录ID>.pdf
```

PDF 的保存、关联、删除和失效路径清理规则见
`docs/project/pdf-report-storage.md`。

计算字段、CK 参照、土层映射和时间口径见
`docs/project/logic-and-data-contract.md`。

当前代码架构见 `docs/project/architecture.md`。修复前的详细报告统一归档到
`docs/history/legacy-v1.1.3/`，避免旧口径继续出现在仓库根目录。

## 后续建议

- 将顶层长期文档逐步归档进 `docs/project/`，顶层只保留 `README.md`、`BUILD.md`、`LICENSE` 等入口文档。
- 发布包继续使用 `git archive` 生成源码包，避免把 `release/`、`temp/`、`.git/` 打进源码包。
- 若要彻底瘦身仓库历史，需要单独做 Git 历史清理，本轮不执行破坏性历史重写。
