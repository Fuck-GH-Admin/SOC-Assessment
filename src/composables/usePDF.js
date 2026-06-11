import { ref } from 'vue'
import jsPDF from 'jspdf'

const exporting = ref(false)

const HELVETICA = 'helvetica'

function isAndroid() {
  return typeof navigator !== 'undefined' && /android/i.test(navigator.userAgent)
}

function drawTitle(doc, text, y) {
  doc.setFont(HELVETICA, 'bold')
  doc.setFontSize(16)
  doc.setTextColor('#1a1a2e')
  doc.text(text, 15, y)
  return y + 12
}

function drawSection(doc, text, y) {
  doc.setFont(HELVETICA, 'bold')
  doc.setFontSize(11)
  doc.setTextColor('#4a9eff')
  doc.text(text, 15, y)
  doc.setDrawColor('#ccc')
  doc.line(15, y + 2, 195, y + 2)
  return y + 9
}

function drawTable(doc, rows, y) {
  doc.setFontSize(8)
  const colW = [75, 55, 55]
  let curY = y
  rows.forEach((row, ri) => {
    if (curY > 275) { doc.addPage(); curY = 20 }
    if (ri === 0) {
      doc.setFont(HELVETICA, 'bold')
      doc.setFillColor('#eef2f7')
    } else {
      doc.setFont(HELVETICA, 'normal')
      doc.setFillColor(ri % 2 === 0 ? '#f7f9fc' : '#ffffff')
    }
    doc.setTextColor('#333')
    let x = 15
    row.forEach((cell, ci) => {
      doc.rect(x, curY - 4, colW[ci] || 60, 6, 'F')
      doc.text(String(cell), x + 2, curY)
      x += colW[ci] || 60
    })
    curY += 7
  })
  return curY + 3
}

function buildPDF(inputs, results, resilience, aiReport) {
  const doc = new jsPDF('p', 'mm', 'a4')
  let y = 20

  y = drawTitle(doc, 'SOC土壤有机碳评估报告', y)
  doc.setFont(HELVETICA, 'normal')
  doc.setFontSize(9)
  doc.setTextColor('#999')
  const now = new Date()
  const ts = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')} ${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`
  doc.text(`生成时间: ${ts}`, 15, y)
  y += 10

  if (inputs) {
    y = drawSection(doc, '输入参数', y)
    const fl = inputs.fert === 'F' ? '施肥' : (inputs.fert === 'UNF' ? '不施肥' : String(inputs.fert || '-'))
    y = drawTable(doc, [
      ['参数', '值', '说明'],
      ['施肥处理', fl, inputs.fert === 'F' ? '施氮肥' : '对照'],
      ['侵蚀强度', String(inputs.erosion ?? '0') + ' cm', '土壤侵蚀深度'],
      ['土层深度', String(inputs.depth ?? '0'), 'cm'],
      ['土壤容重', String(inputs.bd ?? '-'), 'g/cm\u00B3'],
      ['pH值', String(inputs.ph ?? '-'), ''],
      ['含水量', String(inputs.wc ?? '-'), '%'],
      ['黏+粉粒', String(inputs.clay ?? '-'), '%'],
      ['全氮含量', String(inputs.tn ?? '-'), '%'],
      ['秸秆生物量', String(inputs.cropBiomass ?? '-'), 'kg/ha'],
      ['秸秆碳含量', String(inputs.strawCarbonRatio ?? '-'), '比例']
    ], y)
  }

  if (results) {
    y = drawSection(doc, '计算结果', y)
    y = drawTable(doc, [
      ['指标', '数值', '单位'],
      ['SOC含量', String(results.soc ?? '-'), 'g/kg'],
      ['碳库储量', String(results.carbonStorage ?? '-'), 'kg C/m\u00B2'],
      ['碳密度', String(results.carbonDensity ?? '-'), 'kg C/m\u00B3'],
      ['碳库净变化量', String(results.netChange ?? '-'), 'kg C/m\u00B2'],
      ['年恢复速率', String(results.recoveryRate ?? '-'), 'kg C/m\u00B2/年'],
      ['SOC损失率', String(results.lossRate ?? '-'), '%']
    ], y)
  }

  if (resilience) {
    y = drawSection(doc, '土壤恢复力评估', y)
    y = drawTable(doc, [
      ['指标', '数值', '单位'],
      ['表层碳库(0-20cm)', String(resilience.carbonPool_0_20 ?? '-'), 'kg C/m\u00B2'],
      ['剖面碳库(0-60cm)', String(resilience.carbonPool_0_60 ?? '-'), 'kg C/m\u00B2'],
      ['20年净变化量', String(resilience.netChange_20yr ?? '-'), 'kg C/m\u00B2'],
      ['100年净变化量', String(resilience.netChange_100yr ?? '-'), 'kg C/m\u00B2'],
      ['年恢复速率', String(resilience.recoveryRate_annual ?? '-'), 'kg C/m\u00B2/年'],
      ['恢复状态', String(resilience.status ?? '-'), '-']
    ], y)
  }

  if (aiReport) {
    y = drawSection(doc, 'AI评估报告', y)
    const plain = aiReport.replace(/[*#`>\[\]]/g, '').replace(/\n{3,}/g, '\n\n').trim()
    if (plain) {
      doc.setFont(HELVETICA, 'normal')
      doc.setFontSize(8)
      doc.setTextColor('#333')
      const lines = doc.splitTextToSize(plain, 180)
      for (const line of lines) {
        if (y > 275) { doc.addPage(); y = 20 }
        doc.text(line, 15, y)
        y += 4.5
      }
    }
  }

  return doc
}

async function shareFile(blob, filename, mime) {
  const file = new File([blob], filename, { type: mime })
  try {
    await navigator.share({ files: [file] })
    return true
  } catch {
    return false
  }
}

function downloadAnchor(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  setTimeout(() => URL.revokeObjectURL(url), 5000)
}

export function usePDF() {
  async function exportReport(data) {
    exporting.value = true
    try {
      const doc = buildPDF(data.inputs, data.results, data.resilience, data.aiReport)
      const blob = doc.output('blob')
      const filename = `soc-report-${new Date().toISOString().slice(0, 10)}.pdf`

      if (isAndroid()) {
        const ok = await shareFile(blob, filename, 'application/pdf')
        if (!ok) downloadAnchor(blob, filename)
      } else {
        downloadAnchor(blob, filename)
      }
      exporting.value = false
    } catch (e) {
      exporting.value = false
      alert('PDF导出失败: ' + e.message)
    }
  }

  return { exportReport, exporting }
}
