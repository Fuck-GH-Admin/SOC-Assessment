import { ref } from 'vue'
import jsPDF from 'jspdf'

const exporting = ref(false)

function isMobile() {
  return typeof navigator !== 'undefined' && /android|ios/i.test(navigator.userAgent)
}

async function toBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onloadend = () => resolve(reader.result.split(',')[1])
    reader.onerror = reject
    reader.readAsDataURL(blob)
  })
}

async function nativeShare(blob, filename, mime) {
  if (!isMobile() || !navigator.share) return false
  try {
    const file = new File([blob], filename, { type: mime })
    if (navigator.canShare?.({ files: [file] })) {
      await navigator.share({ files: [file], title: filename })
      return true
    }
  } catch (e) {
    if (e?.name === 'AbortError') return true
  }
  return false
}

async function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  if (isMobile()) window.open(url, '_blank')
  setTimeout(() => URL.revokeObjectURL(url), 3000)
}

async function saveToFilesystem(blob, filename) {
  if (!isMobile()) return null
  try {
    const { Filesystem, Directory } = await import('@capacitor/filesystem')
    const base64 = await toBase64(blob)
    const result = await Filesystem.writeFile({
      path: filename, data: base64,
      directory: Directory.Documents, recursive: true
    })
    return result.uri
  } catch { return null }
}

function canvasToImage(canvas) {
  if (!canvas) return null
  if (canvas.width === 0 || canvas.height === 0) return null
  try { return canvas.toDataURL('image/png') }
  catch { return null }
}

function drawTitle(doc, text, y) {
  doc.setFont(undefined, 'bold')
  doc.setFontSize(16)
  doc.setTextColor('#0d1b2a')
  doc.text(text, 15, y)
  return y + 10
}

function drawSection(doc, text, y) {
  doc.setFont(undefined, 'bold')
  doc.setFontSize(12)
  doc.setTextColor('#4a9eff')
  doc.text(text, 15, y)
  doc.setDrawColor('#ddd')
  doc.line(15, y + 2, 195, y + 2)
  return y + 10
}

function drawText(doc, text, y, size = 9) {
  doc.setFont(undefined, 'normal')
  doc.setFontSize(size)
  doc.setTextColor('#333')
  const lines = doc.splitTextToSize(text, 180)
  for (const line of lines) {
    if (y > 275) { doc.addPage(); y = 20 }
    doc.text(line, 15, y)
    y += size * 0.55
  }
  return y + 4
}

function drawTable(doc, rows, y) {
  doc.setFontSize(8)
  const colW = [70, 50, 60]
  const startX = 15
  rows.forEach((row, ri) => {
    if (y > 275) { doc.addPage(); y = 20 }
    if (ri === 0) {
      doc.setFont(undefined, 'bold')
      doc.setFillColor('#f0f4f8')
    } else {
      doc.setFont(undefined, 'normal')
      doc.setFillColor(ri % 2 === 0 ? '#f9fafb' : '#ffffff')
    }
    doc.setTextColor('#333')
    let x = startX
    row.forEach((cell, ci) => {
      doc.rect(x, y - 4, colW[ci] || 60, 6, 'F')
      doc.text(String(cell), x + 2, y)
      x += colW[ci] || 60
    })
    y += 7
  })
  return y + 2
}

function drawChartImage(doc, canvas, y, maxW) {
  const img = canvasToImage(canvas)
  if (!img) return y
  const cw = canvas.width || 600
  const ch = canvas.height || 300
  const pdfW = maxW || 180
  const pdfH = (ch / cw) * pdfW
  if (y + pdfH > 280) { doc.addPage(); y = 20 }
  try { doc.addImage(img, 'PNG', 15, y, pdfW, pdfH) }
  catch { return y }
  return y + pdfH + 5
}

export function usePDF() {
  async function exportReport({ inputs, results, resilience, aiReport, charts }) {
    exporting.value = true
    try {
      const doc = new jsPDF('p', 'mm', 'a4')
      doc.setFont('helvetica')
      let y = 20

      y = drawTitle(doc, 'SOC土壤有机碳评估报告', y)
      doc.setFontSize(9)
      doc.setTextColor('#888')
      doc.text(`生成时间: ${new Date().toLocaleString()}`, 15, y)
      y += 8

      y = drawSection(doc, '输入参数', y)
      const fertLabel = inputs.fert === 'F' ? '施肥' : (inputs.fert === 'UNF' ? '不施肥' : inputs.fert || '')
      y = drawTable(doc, [
        ['参数', '值', '说明'],
        ['施肥处理', fertLabel, inputs.fert === 'F' ? '施氮肥' : '对照'],
        ['侵蚀强度', String(inputs.erosion || 0) + ' cm', '土壤侵蚀深度'],
        ['土层深度', String(inputs.depth || 0), 'cm'],
        ['土壤容重', String(inputs.bd ?? '-'), 'g/cm³'],
        ['pH值', String(inputs.ph ?? '-'), '-'],
        ['含水量', String(inputs.wc ?? '-'), '%'],
        ['黏+粉粒', String(inputs.clay ?? '-'), '%'],
        ['全氮含量', String(inputs.tn ?? '-'), '%'],
        ['秸秆生物量', String(inputs.cropBiomass ?? '-'), 'kg/ha'],
        ['秸秆碳含量', String(inputs.strawCarbonRatio ?? '-'), '比例']
      ], y)

      if (results) {
        y = drawSection(doc, '计算结果', y)
        y = drawTable(doc, [
          ['指标', '数值', '单位'],
          ['SOC含量', String(results.soc ?? '-'), 'g/kg'],
          ['碳库储量', String(results.carbonStorage ?? '-'), 'kg C/m²'],
          ['碳密度', String(results.carbonDensity ?? '-'), 'kg C/m³'],
          ['碳库净变化量', String(results.netChange ?? '-'), 'kg C/m²'],
          ['年恢复速率', String(results.recoveryRate ?? '-'), 'kg C/m²/年'],
          ['SOC损失率', String(results.lossRate ?? '-'), '%']
        ], y)
      }

      if (resilience) {
        y = drawSection(doc, '土壤恢复力评估', y)
        y = drawTable(doc, [
          ['指标', '数值', '单位'],
          ['表层碳库(0-20cm)', String(resilience.carbonPool_0_20 ?? '-'), 'kg C/m²'],
          ['剖面碳库(0-60cm)', String(resilience.carbonPool_0_60 ?? '-'), 'kg C/m²'],
          ['20年净变化量', String(resilience.netChange_20yr ?? '-'), 'kg C/m²'],
          ['100年净变化量', String(resilience.netChange_100yr ?? '-'), 'kg C/m²'],
          ['年恢复速率', String(resilience.recoveryRate_annual ?? '-'), 'kg C/m²/年'],
          ['恢复状态', String(resilience.status ?? '-'), '-']
        ], y)
      }

      if (charts?.length) {
        y = drawSection(doc, '数据图表', y)
        for (const canvas of charts) {
          y = drawChartImage(doc, canvas, y, 180)
        }
      }

      if (aiReport) {
        y = drawSection(doc, 'AI评估报告', y)
        const plain = aiReport.replace(/[#*`>\[\]]/g, '').replace(/\n{3,}/g, '\n\n').trim()
        if (plain) y = drawText(doc, plain, y, 8)
      }

      const blob = doc.output('blob')
      const filename = `soc-report-${new Date().toISOString().slice(0, 10)}.pdf`

      let path = null
      if (isMobile()) {
        const shared = await nativeShare(blob, filename, 'application/pdf')
        if (!shared) {
          path = await saveToFilesystem(blob, filename)
          if (!path) await downloadBlob(blob, filename)
        }
      } else {
        await downloadBlob(blob, filename)
      }
      exporting.value = false
      return { method: path ? 'filesystem' : 'download', path }
    } catch (e) {
      exporting.value = false
      throw e
    }
  }

  return { exportReport, exporting, downloadBlob, saveToFilesystem }
}
