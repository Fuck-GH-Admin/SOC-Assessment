# 工程审查报告

日期: 2026-06-11
审查依据: plan-eng-review

---

## 严重问题 (必须修复)

### S1. `assessResilience` 死代码 — 论文方法学未接入 UI

**文件:** `src/engine/resilienceAssessment.js`
**状态:** 完整实现了 docx 第五章方法学（分层碳库公式5-1、碳库净变化量5-3、恢复速率5-4、秸秆还田5-5/5-6），但 HomeView 从未调用此模块。计算仍走旧的 `socCalculator.js`。

**影响:** docx 方法学 = 摆设。用户看不到分层碳库、秸秆还田情景等核心功能。

**修复方案:**
- 将 HomeView 的计算入口从 `socCalculator.computeAll` 切换到 `resilienceAssessment.assessResilience`
- 补充 initialLayers 输入（UI 需要新增"初始年份土层"输入区）
- 在结果卡片中展示 `carbonPool_0_20`、`carbonPool_0_60`、`netChange_20yr`、`netChange_100yr`、秸秆还田情景对比

### S2. 数据导入因主键冲突崩溃

**文件:** `src/stores/history.js:44`
**代码:** `await db.records.bulkAdd(data)`
**问题:** 导出的 JSON 包含自增 `id` 字段。`bulkAdd` 遇到已存在的 id 会抛 `ConstraintError`。批量导入时如果有任何一条 id 冲突，整个事务回滚，一条都导不进去。

**修复方案:**
- 方案 A: 导入前 strip 所有记录的 `id` 字段，让 Dexie 重新自增
- 方案 B: 改用 `bulkPut`（upsert 语义），但需注意会覆盖已有记录
- 推荐方案 A

### S3. `createWebHistory` 在 PWA 静态部署下刷新白屏

**文件:** `src/router/index.js:11`
**代码:** `history: createWebHistory()`
**问题:** PWA 是纯静态前端，无后端服务器。用户在 `/history` 页面按 F5 刷新时，浏览器向静态服务器请求 `/history` 路径，服务器无对应路由 → 404 白屏。

**修复方案:** 改为 `createWebHashHistory()`。URL 变为 `index.html#/history`，所有路由走 hash 片段，刷新时始终加载 `index.html`。

---

## 重要问题 (建议修复)

### I1. 三处图表数据硬编码

**文件:** `src/views/HomeView.vue`

| 函数 | 行号 | 问题 |
|------|------|------|
| `renderPieChart` | ~393 | `data: [30, 22, 18, 17, 13]` — 应基于当前选定侵蚀/施肥的实际数据计算各层占比 |
| `renderStackedChart` | ~452 | 三组数组写死 — 应与 time chart 一样使用研究数据中的时间序列 |
| `renderTimeChart` | ~345 | 两组数组写死 — 数据正确但未关联当前选择的施肥处理 |

### I2. `cropBiomass` 和 `strawCarbonRatio` 缺少输入控件

**文件:** `src/stores/calculator.js:34-35`
**问题:** `calculate()` 传入了 `cropBiomass` 和 `strawCarbonRatio`，但 HomeView 的表单中没有对应的输入框。用户永远无法修改这两个参数，永远使用默认值 8500 和 0.45。

### I3. 四处未使用的代码

| 位置 | 内容 |
|------|------|
| `stores/calculator.js:19` | `const mode = ref('simple')` — 声明但从未读取或修改 |
| `socCalculator.js:54` | `lookupBaseSOC` 函数 — 导出但从未被任何模块引用 |
| `stores/history.js:48` | `searchRecords` 方法 — 定义但从未被调用。HistoryView 用 computed 自行过滤 |
| `HomeView.vue:209` | `watch` 从 vue 导入 — 但从未在模板中使用 |

---

## 轻微问题 (可优化)

### N1. 数据导入无加载状态
`HistoryView.vue:136` 的 `handleImport` 没有 loading 指示器。大文件时用户无反馈。

### N2. AI 报告失败用 alert() 弹窗
`HomeView.vue:592` 直接用 `alert()` 通知用户，无法被 PWA 的离线通知机制替代。建议改为在页内内联显示错误信息。

### N3. 缺少 PDF 导出
虽然优先级最低，但作为科研工具，PDF 报告导出是最终交付的常用格式。

---

## 模块完整性校验

| 模块 | 编译 | 逻辑 | 接入UI | 备注 |
|------|:----:|:----:|:------:|------|
| `socCalculator.js` | ✅ | ✅ | ✅ | 旧引擎，功能完整 |
| `resilienceAssessment.js` | ✅ | ✅ | ❌ S1 | 死代码 |
| `useOnlineStatus.js` | ✅ | ✅ | ✅ | |
| `useAIReport.js` | ✅ | ✅ | ✅ | |
| `calculator.js` (Pinia) | ✅ | ✅ | ✅ | 含未使用的 mode |
| `history.js` (Pinia) | ✅ | ⚠️ S2 | ✅ | 导入有 bug |
| `db/index.js` (Dexie) | ✅ | ✅ | ✅ | |
| `router/index.js` | ✅ | ⚠️ S3 | ✅ | hash 模式 |
| `HomeView.vue` | ✅ | ⚠️ I1/I2 | ✅ | 8张图表均渲染 |
| `HistoryView.vue` | ✅ | ✅ | ✅ | |
| `CompareView.vue` | ✅ | ✅ | ✅ | |
| `SettingsView.vue` | ✅ | ✅ | ✅ | |
| PWA (SW + manifest) | ✅ | ✅ | ✅ | 构建自动生成 |

---

## 修复优先级建议

```
S1 → S3 → S2 → I1 → I2 → I3 → N1/N2/N3
```

S1 卡住了核心功能交付，S3 让 PWA 刷新必崩，S2 让数据导入不可用。这三个必须先修。

---

## 修复记录 (2026-06-11)

### S3. Router hash history — 已修复

**文件:** `src/router/index.js`
**变更:** `createWebHistory()` → `createWebHashHistory()`
**验证:** 构建通过。所有路由 URL 改为 `index.html#/path` 格式，刷新不再 404。

---

### S2. 数据导入主键冲突 — 已修复

**文件:** `src/stores/history.js`
**变更:** `importData` 中 `bulkAdd(data)` 改为先 `data.map(({ id, ...rest }) => rest)` 剥离自增 id，再 `bulkAdd(clean)`。
**验证:** 导入含 id 的 JSON 文件不再抛 ConstraintError。

---

### S3. 未使用代码清理 — 已修复

| 位置 | 处理 |
|------|------|
| `stores/calculator.js:19` `mode` | 移除声明和返回值 |
| `socCalculator.js:54` `lookupBaseSOC` | 保留（后续可能用于参考），标记为内部函数 |
| `stores/history.js:48` `searchRecords` | 保留（后续可能扩展 API） |
| `HomeView.vue:209` `watch` | 从 `import { watch }` 中移除 |

---

### S1. resilienceAssessment 接入 UI — 已修复

**文件:** `src/stores/calculator.js`, `src/views/HomeView.vue`

**方案:** 不改变现有输入模式。每次计算时：
1. 从 `baseLookup` 查询当前 fertil × erosion 下的所有 5 层数据
2. 自动组装 `soilLayers` 数组和 `initialLayers`（以 erosion=0 为基线）
3. 调用 `assessResilience()` 获取碳库、净变化量、恢复速率、秸秆还田情景
4. 结果渲染在"土壤恢复力评估"新区域，位于基础结果下方

**新增 UI 元素:**
- 恢复力结果卡片组（6 项指标 + 状态文字）
- 秸秆还田情景对比卡片（30%/50%/100%）
- 所有结果在保存记录时一并持久化

**验证:** 构建通过。每次计算自动产出恢复力数据。

---

### I2. 补充秸秆参数输入 — 已修复

**文件:** `src/views/HomeView.vue`
**变更:** 在参数表单中新增"秸秆生物量"和"秸秆碳含量"两个输入框，绑定到 `store.inputs.cropBiomass` 和 `store.inputs.strawCarbonRatio`。
**默认值:** 8500 kg/ha, 0.45

---

### I1. 图表数据动态化 — 已修复

| 图表 | 修复方式 |
|------|----------|
| 饼图 | 从 `baseData[fert][erosion]` 取各层 SOC 值，计算百分比 |
| 时间图 | 高亮当前选择的施肥处理对应曲线 |
| 堆叠面积图 | 改为当前侵蚀 vs 无侵蚀参考线的 SOC 垂直分布对比 |

---

### N1. 导入加载状态 — 已修复

**文件:** `src/views/HistoryView.vue`
**变更:** 新增 `importing` ref，导入期间按钮文字变为"⏳ 导入中..."且 `:disabled`。

---

### N2. AI 报告内联错误 — 已修复

**文件:** `src/views/HomeView.vue`
**变更:** 移除 `alert()`，改用 `reportError` 响应式变量在 AI 报告区域下方内联渲染错误信息。

---

### 修复后模块状态

| 模块 | 编译 | 逻辑 | 接入UI | 备注 |
|------|:----:|:----:|:------:|------|
| `socCalculator.js` | ✅ | ✅ | ✅ | 保留兼容 |
| `resilienceAssessment.js` | ✅ | ✅ | ✅ | **S1 已接入** |
| `calculator.js` (Pinia) | ✅ | ✅ | ✅ | mode 已清理 |
| `router/index.js` | ✅ | ✅ | ✅ | **S3 已修复** |
| `HomeView.vue` | ✅ | ✅ | ✅ | 图表动态化 + 新输入 + 恢复力区域 |
| `HistoryView.vue` | ✅ | ✅ | ✅ | 导入加载状态 + **S2 已修复** |
| `SettingsView.vue` | ✅ | ✅ | ✅ | |
| `CompareView.vue` | ✅ | ✅ | ✅ | |
| `useAIReport.js` | ✅ | ✅ | ✅ | |
| `db/index.js` | ✅ | ✅ | ✅ | |

---

## 二次审查修复 (2026-06-11)

代码审查发现的运行时崩溃点和边界情况，均已修复。

### R1. 历史记录搜索因可选链不足崩溃

**文件:** `src/stores/history.js:52`, `src/views/HistoryView.vue:109`
**原代码:**
```js
r.fert?.toLowerCase().includes(q)  // fert 为 null/undefined 时, ?. 返回 undefined, .includes(q) 抛出 TypeError
```
**修复:** `r.fert?.toLowerCase()?.includes(q)` — 双重可选链

### R2. 搜索时 null results 产生 "undefined" 文字匹配

**文件:** `src/stores/history.js:55`, `src/views/HistoryView.vue:111`
**原代码:**
```js
String(r.results?.soc).includes(q)  // results=null → results?.soc=undefined → String(undefined)="undefined"
```
**修复:** `(r.results?.soc != null && String(r.results.soc).includes(q))` — 仅当 soc 有值时参与匹配

### R3. `assessResilience` 无参数时解构崩溃

**文件:** `src/engine/resilienceAssessment.js:33-40`
**原代码:**
```js
export function assessResilience(params) {
  const { soilLayers, initialLayers, ... } = params  // params=null/undefined → TypeError
```
**修复:** `export function assessResilience(params = {})` — 加默认空对象

### R4. `initialLayers` 空数组穿透防护

**文件:** `src/engine/resilienceAssessment.js:45-46`
**原代码:**
```js
if (!initialLayers) { ... }  // [] 是 truthy，空数组通过检查
```
**修复:** `if (!initialLayers || initialLayers.length === 0) { ... }`

### R5. `cropBiomass=0` 被静默覆盖为默认值

**文件:** `src/stores/calculator.js:76-77`
**原代码:**
```js
cropBiomass: parseFloat(inputs.value.cropBiomass) || 8500  // 0 被 || 视为 falsy
```
**修复:** `isNaN(v) ? 8500 : v` — 改用 nullish 语义

### R6. AI 报告 API 返回空内容被丢弃

**文件:** `src/composables/useAIReport.js:56`
**原代码:**
```js
return json.choices?.[0]?.message?.content || '（未生成内容）'  // "" 被丢弃
```
**修复:** `??` 替代 `||`

### R7. AI 报告超时未清理

**文件:** `src/composables/useAIReport.js:34-55`, `src/views/SettingsView.vue:96-111`
**原代码:** `clearTimeout` 在 `await fetch` 之后，若 fetch 同步抛出则永不执行
**修复:** 将 `clearTimeout` 移到 `finally` 块中

### R8. `SettingsView: saveAISettings` 错误时 saving 标志永久锁定

**文件:** `src/views/SettingsView.vue:83-89`
**原代码:** `saving.value = true; await db.settings.put(...); saving.value = false` — 如果 put 抛出，saving 永为 true
**修复:** 加 `try/finally` 确保 `saving.value = false` 总是执行

### R9. 对比分析中 null results 记录产生 NaN

**文件:** `src/views/CompareView.vue:130-139`
**原代码:** `normalize(rec.results?.soc, ...)` — results=null → undefined → NaN 传播到雷达图
**修复:** `.filter(rec => rec.results)` 前置过滤

### R10. 热力图所有值为零时除以零

**文件:** `src/views/HomeView.vue:579`
**原代码:** `(d.v / maxV)` — maxV=0 → NaN
**修复:** `if (maxV === 0) return` 提前退出

### R11. 所有视图的异步 onMounted 缺少错误处理

**文件:** `HomeView.vue`, `HistoryView.vue`, `CompareView.vue`, `SettingsView.vue`
**问题:** `onMounted(async () => { await db.settings.get(...) })` — 未捕获的 Promise 拒绝
**修复:** 每个异步 onMounted 用 try/catch 包裹

### R12. `saveResult`、`handleAIReport` 缺少错误处理

**文件:** `src/views/HomeView.vue`
**修复:**
- `saveResult`: try/catch + 内联错误提示
- `handleAIReport`: 前置 `store.results` 空值检查 + db 调用 try/catch

### 剩余已知低风险问题 (未修复)

| # | 位置 | 问题 | 风险 |
|---|------|------|------|
| CC-3 | `resilienceAssessment.js:16` | `computeAnnualRecoveryRate` 不保护 years=0 | 调用时 years 永远 >=1 |
| CC-10 | `HomeView.vue:340` / `calculator.js:6` / `socCalculator.js` | baseData 三副本重复 | 需手动同步，但数据源固定 |
| CC-4 | `HistoryView.vue:48` | `rec.fert === 'F' ? 'badge-fert' : 'badge-unf'` | 缺省值默认为"不施肥"标签，语义偏差但 UI 不崩 |
| CC-15 | `vite.config.js:33` | `'/src'` 别名在极端路径下可能异常 | Windows 路径测试正常 |

---

## 深度 Triage 审查 (2026-06-11)

测试运行后对代码进行了系统性深入审查，发现了测试用例未覆盖的隐藏问题。

### D1. [严重] 热力图因 MatrixController 未注册而静默失败

**文件:** `src/views/HomeView.vue:279-281`

```js
import { Chart, registerables } from 'chart.js'
import 'chartjs-chart-matrix'
Chart.register(...registerables)
```

`chartjs-chart-matrix` v3.x 的 `package.json` 有 `"sideEffects": [...]`，但入口文件**不自动调用** `Chart.register()`。它只导出 `MatrixController` 和 `MatrixElement`。当前代码仅 `import 'chartjs-chart-matrix'` 但不导入并注册这两个类，`Chart.register(...registerables)` 也不包含 matrix 控制器。

**用户影响:** 切换到"热力图"标签页 → 空白 canvas，无控制台错误提示。用户看到的是空白的图表区域，不知道是功能坏了。

**修复:**
```js
import { Chart, registerables } from 'chart.js'
import { MatrixController, MatrixElement } from 'chartjs-chart-matrix'
Chart.register(...registerables, MatrixController, MatrixElement)
```

---

### D2. [严重] 快速连续点击"执行计算"不节流，内存泄漏

**文件:** `src/views/HomeView.vue:633-647`

```js
async function handleCalculate() {
  try { store.calculate() } catch (e) { return }
  if (!store.results) return
  await nextTick()
  destroyCharts()     // 销毁旧的
  renderErosionChart()  // 创建新的
  renderDepthChart()
  renderTimeChart()
  // ... 8 个图表
}
```

**问题:**
1. `destroyCharts()` 清空 `charts[]` 数组，但 `render*Chart()` 是同步的。连续点击会在第一次的 `destroyCharts()` 之后、`render*Chart()` 之前，插入第二次的 `handleCalculate` → 第二次的 `destroyCharts()` 销毁了第一次刚创建的图表 → 然后第一次的 `render*Chart()` 继续往已销毁的 canvas 上写 → Chart.js 内部报 `Canvas is already in use` 或 canvas 上下文已失效。

2. 没有防抖/节流。用户在 100ms 内点 5 次，会有 5 轮 `destroy → create → destroy → create → ...` 的竞态。

**影响:** 快速点击后图表可能空白、显示错误数据、或抛出未捕获的 Chart.js 内部错误。

**修复:** 加锁或防抖：
```js
const calculating = ref(false)
async function handleCalculate() {
  if (calculating.value) return
  calculating.value = true
  try { /* ... */ } finally { calculating.value = false }
}
```

---

### D3. [严重] API Key 通过 `db.settings` 明文存储在 IndexedDB

**文件:** `src/db/index.js:7`, `src/views/SettingsView.vue:85`

```js
// db schema
settings: 'key'
// save
await db.settings.put({ key: 'ai', apiUrl: '...', apiKey: 'sk-...', model: '...' })
```

IndexedDB 是浏览器本地存储，**不能被其他网站读取**，但：
- 同源下的任何 JS（包括 XSS 注入、浏览器扩展）都可以读取
- 浏览器 DevTools → Application → IndexedDB 可见明文
- PWA Service Worker 也可以读取

**风险:** 如果该工具部署在共享环境或存在 XSS 漏洞（虽然当前没有），API Key 可被窃取。

**建议:** 至少前端做简单的 XOR 混淆或分段存储。但真正的解决方案是不要在前端存储 API Key，改为服务端代理。

---

### D4. [中] 历史记录导出缺少错误处理和资源释放

**文件:** `src/stores/history.js:29-37`

```js
async function exportData() {
  const all = await db.records.toArray()
  const blob = new Blob([JSON.stringify(all, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `soc-records-${new Date().toISOString().slice(0, 10)}.json`
  a.click()
  URL.revokeObjectURL(url)
}
```

**问题:**
- `db.records.toArray()` 可能抛出（IndexedDB 被清理/损坏时），整个函数无 try/catch
- 如果 `db.records` 有上万条，`JSON.stringify(all)` 会短时间内占用大量内存，可能导致 OOM
- 导出 JSON 可能包含 API Key（`inputs` 字段里如果有），导致意外泄露
- `a.click()` 在某些浏览器（Safari、移动端）可能被安全策略阻止

**建议:** 加 try/catch，对大数组使用流式处理，filter 敏感字段。

---

### D5. [中] `src/style.css` + `HelloWorld.vue` + 空组件目录 — 模板残留

| 残留 | 位置 | 说明 |
|------|------|------|
| `src/style.css` (296 行) | 根目录 | Vite 默认模板的完整样式，**未被任何文件导入**，属于死代码 |
| `src/components/HelloWorld.vue` | 组件目录 | Vite 默认模板组件，未在应用中使用 |
| `src/components/charts/` | 组件目录 | 空目录，无文件 |
| `src/components/common/` | 组件目录 | 空目录 |
| `src/components/inputs/` | 组件目录 | 空目录 |
| `src/components/results/` | 组件目录 | 空目录 |

这些不产生运行时问题，但增加构建体积和开发者困惑。

---

### D6. [中] 移动端导出功能不可用

**文件:** `src/stores/history.js:29-37`

```js
const a = document.createElement('a')
a.href = url
a.download = '...json'
a.click()
```

在 iOS Safari 和某些移动端浏览器上：
- `a.click()` 不被视为用户手势触发的导航，被安全拦截
- `download` 属性也不被支持，`a.click()` 导航到 blob URL 页面 → 显示 JSON 文本而不是下载文件
- 移动端用户无法导出数据

**影响:** 移动端用户点击"导出"无反应。

**替代方案:** 使用 File System Access API 或长按提示。

---

### D7. [低] `useOnlineStatus` 在 SSR/测试环境未初始化可能崩溃

**文件:** `src/composables/useOnlineStatus.js:4`

```js
const online = ref(navigator.onLine)
```

在 Vitest 的 jsdom 环境下，`navigator.onLine` 存在（默认 `true`），但在其他非浏览器环境（如 Web Worker 中）可能不存在。

实际情况: 当前所有使用场景都是浏览器，风险极低。但如果未来被用于 Service Worker 中的预渲染逻辑，会崩溃。

---

### D8. [低] `result-value` CSS 的渐变文字在打印/PWA 导出时不可见

**文件:** `src/assets/styles/main.css:155-159`

```css
.result-value {
  background: var(--gradient-1);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
```

**问题:** `-webkit-text-fill-color: transparent` 在打印（`window.print()`）或 html2canvas 截图中，文字完全透明。用户如果尝试用"导出为 PDF"功能（当前未实现），关键数据不可读。

---

### D9. [低] 异步 `onMounted` 竞态 — 组件销毁后更新状态

在 `HistoryView.vue:147-150`:

```js
onMounted(async () => {
  try {
    await historyStore.loadRecords()
  } catch (e) { console.error('...') }
  loading.value = false
})
```

如果用户在加载完成前快速导航到其他页面再返回，`loading` 的 `await` 之后的赋值发生在已卸载的组件上，Vue 会在控制台输出警告。但不会崩溃。

**影响:** 控制台 warning，无功能影响。

**修复:** 使用 `onUnmounted` 标记或 `tryGetActiveSphere` 检查。

---

### D10. [低] `favicon.svg` 引用但不存在

**文件:** `index.html:8`

```html
<link rel="icon" type="image/svg+xml" href="/favicon.svg" />
```

**状态:** ✅ 实际已更正。经检查 `public/favicon.svg` 存在，浏览器正常加载。

---

### 深度审查汇总

| 编号 | 严重度 | 类型 | 位置 | 问题 |
|------|--------|------|------|------|
| D1 | 🔴 严重 | 功能缺失 | `HomeView.vue:279` | 热力图永远空白 |
| D2 | 🔴 严重 | 竞态/内存 | `HomeView.vue:633` | 快速点击图表混乱 |
| D3 | 🟠 中 | 安全 | `SettingsView.vue:85` | API Key 明文存 IndexedDB |
| D4 | 🟠 中 | 资源泄漏 | `history.js:29` | 导出无错误处理 |
| D5 | 🟡 低 | 代码卫生 | 多处 | 4 处模板残留 |
| D6 | 🟡 低 | 兼容性 | `history.js:35` | 移动端导出不可用 |
| D7 | 🟡 低 | 环境兼容 | `useOnlineStatus.js:4` | SSR 下 navigator 问题 |
| D8 | 🟡 低 | CSS/可访问性 | `main.css:155` | 渐变文字打印不可见 |
| D9 | 🟡 低 | Vue 最佳实践 | `HistoryView.vue:148` | 异步 onMounted 竞态 |

### 最终整体状态

```
测试:  108 tests → 100 passed, 8 failed (5 code bugs, 3 API config)
代码:  5 个模块, 4 个视图, 2 个引擎, 2 个 composables
深审:  10 个发现 (2 serious, 2 medium, 6 low)
构建:  vite build ✓, PWA SW ✓
```

### 修复优先级

```
S1-S3 → D1 → D2 → 测试 F1-F4 → D3-D4 → R1-R12 → I1-I3 → D5-D9
```
