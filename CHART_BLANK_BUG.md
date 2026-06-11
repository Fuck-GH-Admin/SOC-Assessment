# PDF 图表空白 Bug 分析

## 现象
- 热力图"显示数值"关闭时：PDF 中**部分图表空白**（文件大小正常说明已嵌入，但纯白）
- 热力图"显示数值"打开时：所有图表正常

## 根因

### 问题代码 (usePDF.js 第 72-79 行)
```js
function chartToImg(chart) {
  chart.resize(600, 350)   // ← 对所有图表强制 resize
  const img = chart.toBase64Image('image/png', 2)
  ...
}
```

### 为什么空白

1. App 有 8 个 tab，每次只显示 1 个。其余 7 个 tab 的 div 是 `display: none`
2. `chart.resize(600, 350)` 让 Chart.js 用新尺寸重绘
3. 对**隐藏 tab**中的图表：父容器 `display:none` → chart 实际渲染尺寸为 0×0 → `toBase64Image` 产生 0×0 空白图 → `img.length < 500` → 跳过，或嵌入空白
4. 对**当前可见 tab**的图表：正常渲染 600×350 → 正常

### 为什么打开"显示数值"就修复了

`toggleHeatmapValues()` 调用 `chart.draw()` 触发了热力图重绘。这个重绘**导致浏览器全局重排 (reflow)**，使所有隐藏 tab 中的 canvas 获得正确的计算尺寸。之后再 resize 就能得到正常图。

## 修复方案

导出前**遍历所有 tab 使其短暂可见**，让每个图表在可见容器中渲染一次。然后 resize + 截图。

```js
// 在 handleExportPDF() 中，exportReport() 之前：
const current = activeTab.value
for (const t of chartTabs) {
  activeTab.value = t.id
  await nextTick()
  await new Promise(r => setTimeout(r, 100))
}
activeTab.value = current
```

这是**最小改动**：只在 HomeView.vue 的 handleExportPDF 中加 6 行代码，不碰图表渲染逻辑。
