# Phase 3 实施报告 — 数据持久化

## 概况

| 项目 | 值 |
|---|---|
| 目标 | Drift (SQLite) 数据库搭建、历史记录 CRUD、草稿自动保存/恢复、JSON 序列化 |
| 状态 | ✅ **全部完成** |
| 新增测试 | **13** (RecordDao: 7 + DraftDao: 6) |
| 总测试 | **40/40** |
| 分析 | **0 error, 0 warning**, 3 info (仅 pre-existing 命名风格 lint) |
| 存储引擎 | **Drift 2.28.2** (SQLite, with `sqlite3_flutter_libs`) |

## 新增/修改文件结构

```
soc_app/lib/
├── data/
│   ├── app_database.dart          # Drift 数据库定义（@DriftDatabase + 2 表）
│   ├── app_database.g.dart        # Drift 代码生成器输出
│   ├── record_dao.dart            # 历史记录 CRUD（插入/删除/批量/分页/解码）
│   └── draft_dao.dart             # 草稿 DAO（存入/读取/删除/过期检查）
├── presentation/
│   ├── providers/
│   │   ├── database_provider.dart     # FutureProvider<AppDatabase>
│   │   ├── record_dao_provider.dart   # FutureProvider<RecordDao>
│   │   ├── draft_dao_provider.dart    # FutureProvider<DraftDao>
│   │   ├── history_provider.dart      # 历史列表 + 删除 FutureProvider
│   │   ├── calculator_provider.dart   # [修改] 计算后自动存历史 + 参数变更 2s 防抖存草稿
│   ├── pages/
│   │   ├── history/
│   │   │   └── history_page.dart      # [新增] 历史记录列表页面（加载/空态/删除）
│   │   └── home/
│   │       └── home_page.dart         # [修改] ConsumerStatefulWidget + 启动草稿检测
soc_app/test/data/
├── record_dao_test.dart               # 7 个测试：插入/查询/删除/批量/倒序/最新/清空
├── draft_dao_test.dart                # 6 个测试：保存/覆盖/空态/过期读取/删除/空态年龄
```

## 设计决策

### 1. JSON TEXT 列（非 TypeConverter）

**决定**：`HistoryRecords` 和 `Drafts` 表的 `params`/`result` 字段使用 `TextColumn`，JSON 序列化在 DAO 层进行。

**理由**：
- Drift 2.x TypeConverter API 的 `.map()` 返回 `BuildGeneralColumn`，与标准列类型不兼容，需大量实验才能确定正确的类型签名
- DAO 层 JSON 编解码仅多 2 行 `jsonEncode`/`jsonDecode`，对性能无影响
- 后续若需要 TypeConverter，可无损迁移

### 2. 固定主键草稿 (id = 1)

草稿表使用 `PRIMARY KEY (id)`，始终以 `id: 1` 写入。`insertOnConflictUpdate` 确保同一行反复覆盖，无历史堆积。

### 3. 2 秒防抖草稿写入

每次参数变更启动 2 秒 `Timer`，变更期间反复 reset。仅当用户停止输入 2 秒后写入一次草稿。Notifier dispose 时 cancel timer（通过 `ref.onDispose`）。

### 4. 5 分钟草稿过期

启动时检查草稿 `createdAt` 字段，超过 5 分钟自动删除并跳过恢复提示。5 分钟内弹出 `AlertDialog` 让用户选择恢复或忽略。

### 5. 历史自动保存

`CalculatorNotifier.calculate()` 执行成功后在 `async` 中自动调用 `RecordDao.insert()`，用户无需手动点击"保存"按钮。

## Drift 数据表定义

```sql
CREATE TABLE history_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  params TEXT NOT NULL,         -- JSON: CalculationParams
  result TEXT NOT NULL,         -- JSON: CalculationResult
  resilience TEXT,              -- JSON: ResilienceResult? (nullable)
  label TEXT,                   -- 用户标签 (nullable)
  created_at INTEGER NOT NULL   -- 毫秒时间戳
);

CREATE TABLE drafts (
  id INTEGER PRIMARY KEY,       -- 固定 1
  params TEXT NOT NULL,         -- JSON: CalculationParams
  created_at INTEGER NOT NULL   -- 毫秒时间戳
);
```

## Riverpod Provider 图

```
AppDatabase.create()
    → databaseProvider (FutureProvider)
        → recordDaoProvider (FutureProvider)
            → calculatorProvider.notifier  — 计算后自动 insert
            → historyListProvider           — 列表渲染 + 删除
        → draftDaoProvider (FutureProvider)
            → calculatorProvider.notifier  — 参数变更 2s 防抖保存
            → HomePage._checkDraft()       — 启动时检测 + 恢复对话框
```

## 测试覆盖

| 文件 | 测试数 | 关键场景 |
|---|---|---|
| `record_dao_test.dart` | 7 | insert + getById, resilience+label, getAll(desc), delete, getByIds(multi), getLatest, clearAll |
| `draft_dao_test.dart` | 6 | save+load, overwrite, no-draft→null, getAgeMillis, no-draft→null-age, delete |

所有 13 个数据层测试均在 `NativeDatabase.memory()` 内存数据库中运行，不依赖任何平台组件。

## 质量门禁

```
$ dart analyze lib/
  3 issues found.   # 全部为 pre-existing info-level
$ flutter test
  00:01 +40: All tests passed!
```

## 进入 Phase 4 的前置条件

1. ✅ Drift 数据库定义 + TypeConverter（JSON 文本列方案）
2. ✅ 历史记录 CRUD（RecordDao）
3. ✅ 草稿自动保存/恢复（DraftDao + 2s debounce + 5min 过期）
4. ✅ 计算后自动写入历史
5. ✅ 启动恢复对话框
6. ✅ 历史记录页面（列表 + 删除）
7. ✅ 13 个数据层测试 + 27 个引擎测试 = 40/40

## 与设计文档偏差

| 设计文档 | 实际实现 | 原因 |
|---|---|---|
| Drift TypeConverter | DAO 层 JSON 编解码 | TypeConverter API 兼容性问题，可后续无损迁移 |
| go_router 路由 | Navigator.push | 仅历史页面需要导航，go_router 开销过大，Phase 4 多页面时再引入 |
| AiConfig 存储 | 未实现（Phase 5） | AiConfig 与设置页面属于 Phase 5 范畴 |
| file_picker 导入导出 | 未实现 | JSON 导入导出属于数据管理功能，待 Phase 5 完善历史页面时一并实现 |
