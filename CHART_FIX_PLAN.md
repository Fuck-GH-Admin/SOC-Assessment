# PDF 图表尺寸修复方案

## 现象
图表在 PDF 中变扁（被压缩）

## 原因
`chart.resize()` 无参数使用 canvas 原始尺寸。隐藏 tab 切换后 canvas 尺寸未正确更新（浏览器未触发重排），导致截图尺寸异常。

## 历史尝试

| 方案 | 参数 | 结果 |
|------|------|------|
| resize(600,350) + pixelRatio:2 | 1200×700 每图 | OOM 崩溃 |
| resize() + pixelRatio:1.5 | 依赖 canvas 原始尺寸 | 图变扁 |

## 建议方案

折中：`resize(500, 280)` + `pixelRatio: 1.5`
- 截图尺寸 750×420 = 315K px/图
- 8图 = 2.5M px ≈ 10MB raw
- 在 A4 PDF 中显示为 180×100mm（正常比例）

## 改动范围
仅 `usePDF.js` 第 75 行，1 处修改。
