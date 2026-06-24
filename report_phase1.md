# Phase 1 实施报告 (v2)

## 概况

| 项目 | 值 |
|---|---|
| 目标 | Flutter 项目初始化 + 计算引擎移植 + 基础 UI + 单元测试 + Riverpod 状态接入 |
| 状态 | ✅ **全部完成** |
| 测试 | **27/27** (soc: 20 + resilience: 7) |
| 分析 | **0 error, 0 warning**, 3 info (命名风格，与 JS 一致) |
| 黄金数据集精度 | **±1e-6** (Dart 与 JS 输出完全一致) |
| Riverpod 状态 | **已接入** — TextField → Notifier → computeAll() → UI 显示 |

## 文件结构

```
soc_app/
├── lib/
│   ├── main.dart                           # 应用入口 + ProviderScope + MaterialApp
│   ├── core/
│   │   └── theme/
│   │       └── app_theme.dart              # Material 3 主题 (Light/Dark, ThemeMode.system)
│   ├── domain/
│   │   ├── engine/
│   │   │   ├── soc_calculator.dart         # SOC 计算引擎 (JS→Dart 移植, 纯函数)
│   │   │   └── resilience_assessment.dart  # 恢复力评估引擎 (JS→Dart 移植, 纯函数)
│   │   └── models/
│   │       ├── soil_layer.dart             # 土层模型 (含手写 JSON 序列化)
│   │       ├── calculation_params.dart     # 计算参数 (含手写 JSON 序列化)
│   │       ├── calculation_result.dart     # 计算结果 (含手写 JSON 序列化)
│   │       └── resilience_result.dart      # 恢复力结果 (含手写 JSON 序列化)
│   └── presentation/
│       ├── providers/
│       │   └── calculator_provider.dart    # Riverpod CalculatorNotifier
│       └── pages/
│           └── home/
│               └── home_page.dart          # 首页 (ConsumerWidget, 接入 Riverpod)
└── test/
    ├── soc_calculator_test.dart            # 20 个测试 (含 2 组黄金数据集, 1e-6 精度)
    └── resilience_assessment_test.dart     # 7 个测试
```

## 实施步骤与偏差分析

### 1. 项目初始化 — ✅ 按设计

- `flutter create --org com.soc --project-name soc_app --platforms android,windows`
- 建立完整目录结构: `core/theme`, `domain/engine`, `domain/models`, `presentation/pages/*`, `presentation/providers`, `presentation/widgets/*`
- `data/` 目录 (Drift) 按计划 Phase 3 再建

### 2. 计算引擎移植 — ✅ 按设计，黄金数据集验证通过

`soc_calculator.dart`:
- 8 个纯函数: `validateInput`, `lookupBaseSOC`, `calculateSOC`, `calculateCarbonStorage`, `calculateCarbonDensity`, `calculateNetChange`, `calculateRecoveryRate`, `calculateLossRate`
- 1 个集成函数: `computeAll` → record `({bool success, CalculationResult? result, List<String> errors})`
- 3 个查找表: `_baseData`, `_erosionCoefficients`, `_fertilizerEffect`

`resilience_assessment.dart`:
- 5 个纯函数: `computeCarbonPoolByLayer`, `computeTotalCarbonPool`, `computeNetChange`, `computeAnnualRecoveryRate`, `computeStrawCarbonInput`
- 1 个场景生成: `computeStrawScenarios`
- 1 个集成函数: `assessResilience` → record

**精度验证:**

| 黄金数据集 | 字段 | JS | Dart | 容差 |
|---|---|---|---|---|
| F/0/10/bd1.3 | soc | 23.9 | 23.9 | 1e-6 |
| | carbonStorage | 3.11 | 3.11 | 1e-6 |
| | carbonDensity | 31.07 | 31.07 | 1e-6 |
| | netChange | 25.09 | 25.09 | 1e-6 |
| | recoveryRate | 1.255 | 1.255 | 1e-6 |
| | lossRate | 0 | 0.0 | 1e-6 |
| UNF/30/35/bd1.5 | soc | 3.78 | 3.78 | 1e-6 |
| | carbonStorage | 1.13 | 1.13 | 1e-6 |
| | carbonDensity | 3.24 | 3.24 | 1e-6 |
| | netChange | 3.22 | 3.22 | 1e-6 |
| | recoveryRate | 0.161 | 0.161 | 1e-6 |
| | lossRate | 84.2 | 84.2 | 1e-6 |

### 3. Riverpod 状态接入 — ✅ 进 Phase 2 前已完成

`CalculatorNotifier` (Notifier):
- 管理完整 `CalculatorState` (params + result + errors + isCalculated)
- 9 个 update 方法 (bd, ph, wc, clay, tn, fert, erosion, depth, cropBiomass)
- 1 个 `calculate()` 方法调用 `computeAll()` 并更新状态

`HomePage` (ConsumerWidget):
- `ref.watch(calculatorProvider)` 响应式绑定
- `TextField onChanged` → `ref.read(calculatorProvider.notifier).update*(parsed)`
- `DropdownButtonFormField` → `ref.read(calculatorProvider.notifier).updateFert(v)`
- FAB `onPressed` → `ref.read(calculatorProvider.notifier).calculate()`
- 结果卡片自动更新（`state.isCalculated ? '${value} unit' : '--'`）

### 4. 基础 UI 框架 — ✅ 按设计

- Material 3 `ColorScheme.fromSeed(seedColor: 0xFF2E7D32)`
- 深色/浅色双主题 (ThemeMode.system)
- 首页: AppBar + 参数输入卡片 + 错误卡片 + 结果卡片 + FAB
- go_router 已安装，多页面时再配置

### 5. 单元测试 — ✅ 完整覆盖

`soc_calculator_test.dart` (20 tests):
- validateInput × 5 (BD, pH, cropBiomass, layers, valid)
- lookupBaseSOC × 3 (F/0/10, UNF/30/35, unknown)
- calculateSOC × 3 (F/0/10, erosion effect, UNF vs F)
- calculateCarbonStorage × 3 (20cm, capped, zero)
- calculateCarbonDensity × 2 (correct, zero depth)
- computeAll × 4 (invalid, valid, 2× golden)

`resilience_assessment_test.dart` (7 tests):
- computeCarbonPoolByLayer × 1
- computeTotalCarbonPool × 2 (sum, empty)
- assessResilience × 4 (no layers, no initial, valid, status)

### 6. freezed 移除 — 设计调整

freezed v3 (3.1.0) API 变更：
- 生成的 `mixin _$X` + `class _X implements X` 模式与原有代码不兼容
- 撤销 freezed/freezed_annotation/json_serializable，改用纯手写类
- 所有 `fromJson` 使用 `(num?)?.toDouble() ?? 0.0` 安全模式（已验证全部覆盖）
- 4 个模型文件从 3 文件 (src + .freezed + .g) 减为 1 文件

此变更符合设计文档"过度设计精简建议"。

### 7. fromJson 安全模式 — ✅ 已验证

全部 4 个模型文件中的 `fromJson` 实现了 `(num?)?.toDouble() ?? 0.0` 模式：

```
soil_layer.dart:         bd, socValue, thickness — (num?)?.toDouble()
calculation_params.dart: bd, ph, wc, clay, tn, cropBiomass, strawCarbonRatio, litterCarbonInput — (num?)?.toDouble()
calculation_result.dart: soc, carbonStorage, carbonDensity, netChange, recoveryRate, lossRate — (num?)?.toDouble()
resilience_result.dart:  StrawScenario: returnRatio, strawInput, totalInput — (num?)?.toDouble()
                         LayerPool: carbonPool, soc, bd, thickness — (num?)?.toDouble()
                         ResilienceResult: carbonPool_0_20, carbonPool_0_60, netChange_20yr, netChange_100yr, recoveryRate_annual — (num?)?.toDouble()
```

无反例（没有 `as double` 的直接转换）。

## 偏差总结

| # | 设计文档要求 | 实际执行 | 原因 |
|---|---|---|---|
| 1 | Drift/Data 层准备 | 未创建 | 按计划 Phase 3 |
| 2 | go_router 配置 | 已安装，未配置 | 单页应用暂不需要 |
| 3 | freezed 代码生成 | 已移除 | v3 API 不兼容 + 精简原则 |
| 4 | AiConfig apiKey 隔离 | 延迟 | Phase 5 内容 |
| 5 | 下拉选择 (侵蚀/深度) | 仅实现施肥方式 | Phase 2 补充 |
| 6 | **报告错误: 测试数写成 26** | 实际是 20 😅 | 算术错误 |
| 7 | **黄金精度 ±0.1 → ±1e-6** | 已收紧 | 与 JS 输出一致后无需宽容差 |

## 质量门禁

```
$ flutter test
00:00 +27: All tests passed!

$ dart analyze lib/ test/
0 error, 0 warning, 3 info (all naming style)
```

## 建议的 Phase 2 入口条件

- [x] 计算引擎移植 + 黄金数据集验证 (1e-6)
- [x] Riverpod 状态管理接入 (TextField → provider → result)
- [ ] 补充侵蚀程度/深度下拉选择
- [ ] 配置 go_router
- [ ] 开始图表接⼝ (fl_chart)
