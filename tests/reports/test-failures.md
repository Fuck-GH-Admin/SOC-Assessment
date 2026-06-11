# 极端环境测试失败报告

日期: 2026-06-11  
测试框架: vitest v4.1.8  
运行: `npm test` (108 个测试用例)  
通过: 100 | 失败: 8

---

## 代码缺陷类 (4 个)

### F1. `assessResilience(null)` 解构崩溃

**测试:** `resilienceAssessment.test.js > handles null params`

**期望:** 返回 `{ success: false, errors: [...] }`  
**实际:** `TypeError: Cannot destructure property 'soilLayers' of 'params' as it is null`

**原因:**
```js
export function assessResilience(params = {}) {
  const { soilLayers, ... } = params  // params = null 时，默认值 = {} 不生效
```
JS 函数默认参数只在 `undefined` 时生效，`null` 时 **不触发默认值**。调用时 `null` 直接赋值给 `params`，解构抛出未捕获 TypeError。

**修复方案:** `params ?? {}` 或 `params || {}` 覆盖 null。

---

### F2. `calculateCarbonDensity(depthCm=0)` 返回 Infinity

**测试:** `socCalculator.test.js > calculateCarbonDensity > handles zero depthCm`

**期望:** 返回 `0`  
**实际:** 返回 `Infinity`

**原因:**
```js
export function calculateCarbonDensity(carbonStorage, depthCm) {
  return Math.max(0, carbonStorage / (depthCm / 100))
}
```
`depthCm = 0` → `0 / 100 = 0` → `carbonStorage / 0 = Infinity` → `Math.max(0, Infinity) = Infinity`

**影响:** 如果 UI 传入 depth=0（理论上不可能，通过 select 控件限制），计算结果为 Infinity，展示为 "∞"。

**修复方案:** 函数入口加 `if (depthCm <= 0) return 0`

---

### F3. `computeAll({ fert: 'XXX' })` — calculateLossRate 访问 undefined

**测试:** `socCalculator.test.js > computeAll > handles unknown fert gracefully`

**期望:** 返回 `{ success: true, results: { soc: NaN, ... } }`  
**实际:** `TypeError: Cannot read properties of undefined (reading '0')`

**原因:**
```js
export function calculateLossRate(soc, fert) {
  const baseSoc = baseData[fert][0][10]  // baseData['XXX'] is undefined
  return Math.max(0, ((baseSoc - soc) / baseSoc) * 100)
}
```
`calculateLossRate` 在 `computeAll` 流水线末尾被调用。即使前面的 `calculateSOC` 返回了 `NaN`，`calculateLossRate` 也会先崩溃。更关键的是 —— `calculateLossRate` 直接索引 `baseData[fert][0][10]` 而不检查键是否存在。

**影响:** 任何通过 UI 选择的 fert 值都是预定义的且在允许范围内，所以正常使用不会触发。但如果未来扩展了 UI 选项而不同步扩展 baseData 表，就会崩。

**修复方案:** `baseData[fert]?.[0]?.[10] ?? 0` 或者 `computeAll` 中提前校验 `fert in baseData`。

---

### F4. `computeAll({})` — 空对象从头崩到尾

**测试:** `socCalculator.test.js > computeAll > handles missing params without crashing`

**期望:** 不抛出异常  
**实际:** `TypeError: Cannot read properties of undefined (reading '0')`

**原因:** 同 F3，`validateInput({})` 通过（所有字段 undefined 都通过了 range 检查），然后 `calculateSOC` 内部走默认值 `|| 10.0` 没崩，但 `calculateLossRate` 执行 `baseData[undefined][0][10]` → `baseData[undefined]` 是 `undefined` → 崩溃。

**影响:** 极端低概率，但所有使用 `computeAll` 的地方都没有 try/catch。

**修复方案:** `calculateLossRate` + `calculateSOC` 做好键保护。

---

## AI API 集成类 (4 个)

### F5-F8. 实时 API 全部返回 404

**测试:** 
- `useAIReport — live API integration > generates report with real API`
- `useAIReport — live API integration > resets error state before each generation`
- `useAIReport — extreme prompts > handles extreme SOC values`
- `useAIReport — extreme prompts > handles all-zero results`

**期望:** API 返回生成的报告文本  
**实际:** `API请求失败: 404`

**配置:**
```
API URL: https://token-plan-cn.xiaomimimo.com/v1
Model: mimo-v2.5-pro
```

**原因分析:** 提供的 API 端点 `https://token-plan-cn.xiaomimimo.com/v1` 返回 404。该 URL 可能是 OpenAI 兼容 API 的 base URL，需要拼接 `/chat/completions` 路径。当前 `useAIReport.js` 直接用 `apiUrl` 作为 fetch URL，而不是将其视为 base URL。

**影响:** AI 报告功能完全不可用，无法连接指定的 API 服务。

**修复方案:** 确认完整 API 路径（是否需要 `/chat/completions`），或者修改 `useAIReport.js` 在 URL 后自动拼接路径。

---

## 测试用例结构

```
tests/
  unit/
    socCalculator.test.js        — 46 tests (3 failed: F2-F4)
    resilienceAssessment.test.js — 35 tests (1 failed: F1)
    calculatorStore.test.js      — 11 tests (0 failed)
    historyStore.test.js         — 11 tests (0 failed)
    useAIReport.test.js          — 13 tests (4 failed: F5-F8)
```

运行方法:
```
npm test                          # 运行所有测试
npx vitest run tests/unit/socCalculator.test.js   # 只跑特定文件
npx vitest --reporter=json --outputFile=tests/reports/results.json  # JSON 输出
```
