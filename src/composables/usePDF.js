import { ref } from 'vue'
import jsPDF from 'jspdf'
import { exportBlob } from '@/utils/exportFile.js'

const exporting = ref(false)
let fontReady = false
let fontBase64 = null

function nowStr() {
  const d = new Date()
  return `${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}${String(d.getDate()).padStart(2,'0')}-${String(d.getHours()).padStart(2,'0')}${String(d.getMinutes()).padStart(2,'0')}${String(d.getSeconds()).padStart(2,'0')}`
}

async function loadFont() {
  if (fontReady) return
  const resp = await fetch('./SimHei.ttf')
  if (!resp.ok) throw new Error('Font load failed: ' + resp.status)
  const buf = await resp.arrayBuffer()
  const bytes = new Uint8Array(buf)
  const chunks = []
  for (let i = 0; i < bytes.length; i += 0x2000) {
    chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + 0x2000)))
  }
  fontBase64 = btoa(chunks.join(''))
  fontReady = true
}

function reg(doc) {
  doc.addFileToVFS('SimHei.ttf', fontBase64)
  doc.addFont('SimHei.ttf', 'SimHei', 'normal')
}

function title(doc, text, y) {
  doc.setFont('SimHei')
  doc.setFontSize(16)
  doc.setTextColor('#000')
  doc.text(text, 15, y)
  return y + 12
}

function section(doc, text, y) {
  if (y > 270) { doc.addPage(); y = 20; reg(doc) }
  doc.setFont('SimHei')
  doc.setFontSize(12)
  doc.setTextColor('#000')
  doc.text(text, 15, y)
  doc.setDrawColor('#ddd')
  doc.line(15, y + 2, 195, y + 2)
  return y + 10
}

function table(doc, rows, y) {
  doc.setFont('SimHei')
  doc.setFontSize(8)
  const colW = [50, 46, 46]
  rows.forEach((row, ri) => {
    if (y > 260) { doc.addPage(); y = 20; reg(doc); doc.setFont('SimHei'); doc.setFontSize(8) }
    doc.setTextColor(ri === 0 ? '#000' : '#222')
    let x = 15
    row.forEach((cell, ci) => {
      const w = colW[ci] || 40
      if (ri === 0) { doc.setFillColor('#f0f0f0'); doc.rect(x, y - 4, w, 6, 'F') }
      if (ri > 0 && ri % 2 === 0) { doc.setFillColor('#fafafa'); doc.rect(x, y - 4, w, 6, 'F') }
      doc.text(String(cell), x + 2, y)
      x += w
    })
    y += 7
  })
  return y + 4
}

function chartToImg(chart) {
  if (!chart) return null
  try {
    chart.resize(500, 280)
    const img = chart.toBase64Image('image/png', 1.5)
    if (!img || img.length < 500) return null
    return img
  } catch { return null }
}

export function usePDF() {
  async function exportReport(data) {
    exporting.value = true
    try {
      await loadFont()
      const doc = new jsPDF('p', 'mm', 'a4')
      reg(doc)
      let y = 20

      y = title(doc, 'SOC土壤有机碳评估报告', y)
      doc.setFont('helvetica')
      doc.setFontSize(7)
      doc.setTextColor('#999')
      doc.text(`Generated: ${new Date().toISOString().replace('T',' ').slice(0,19)}`, 15, y)
      y += 10

      y = section(doc, '输入参数', y)
      y = table(doc, [
        ['参数', '值', '说明'],
        ['施肥处理', data.fert||'-', data.fert?.includes('施肥')?'施氮肥':'对照'],
        ['侵蚀强度', String(data.erosion||'0')+' cm', '土壤侵蚀深度'],
        ['土壤容重', String(data.bd??'-'), 'g/cm\u00B3'],
        ['pH值', String(data.ph??'-'), ''],
        ['含水量', String(data.wc??'-'), '%'],
        ['黏+粉粒', String(data.clay??'-'), '%'],
        ['全氮含量', String(data.tn??'-'), '%'],
        ['秸秆生物量', String(data.cropBiomass??'-'), 'kg/ha'],
        ['秸秆碳含量', String(data.strawCarbon??'-'), '比例']
      ], y)

      if (data.results) {
        y = section(doc, '计算结果', y)
        y = table(doc, [
          ['指标', '数值', '单位'],
          ['SOC含量', String(data.results.soc??'-'), 'g/kg'],
          ['碳库储量', String(data.results.carbonStorage??'-'), 'kg C/m\u00B2'],
          ['碳密度', String(data.results.carbonDensity??'-'), 'kg C/m\u00B3'],
          ['净变化量', String(data.results.netChange??'-'), 'kg C/m\u00B2'],
          ['恢复速率', String(data.results.recoveryRate??'-'), 'kg C/m\u00B2/yr'],
          ['SOC损失率', String(data.results.lossRate??'-'), '%']
        ], y)
      }

      if (data.resilience) {
        y = section(doc, '土壤恢复力评估', y)
        y = table(doc, [
          ['指标', '数值', '单位'],
          ['表层碳库(0-20cm)', String(data.resilience.carbonPool_0_20??'-'), 'kg C/m\u00B2'],
          ['剖面碳库(0-60cm)', String(data.resilience.carbonPool_0_60??'-'), 'kg C/m\u00B2'],
          ['20年净变化量', String(data.resilience.netChange_20yr??'-'), 'kg C/m\u00B2'],
          ['100年净变化量', String(data.resilience.netChange_100yr??'-'), 'kg C/m\u00B2'],
          ['年恢复速率', String(data.resilience.recoveryRate_annual??'-'), 'kg C/m\u00B2/yr'],
          ['恢复状态', String(data.resilience.status??'-'), '-']
        ], y)
      }

      if (data.charts?.length) {
        y = section(doc, '数据图表 (8张)', y)
        for (const c of data.charts) {
          const img = chartToImg(c)
          if (!img) continue
          if (y + 75 > 280) { doc.addPage(); y = 20; reg(doc) }
          doc.addImage(img, 'PNG', 15, y, 180, 105)
          y += 108
        }
      }

      if (data.aiReport) {
        y = section(doc, 'AI评估报告', y)
        const plain = data.aiReport.replace(/[*#`>\[\]]/g,'').replace(/\n{3,}/g,'\n\n').trim()
        if (plain) {
          doc.setFont('SimHei')
          doc.setFontSize(8)
          doc.setTextColor('#222')
          const lines = doc.splitTextToSize(plain, 180)
          for (const line of lines) {
            if (y > 275) { doc.addPage(); y = 20; reg(doc); doc.setFont('SimHei'); doc.setFontSize(8) }
            doc.text(line, 15, y)
            y += 4.5
          }
        }
      }

      const blob = doc.output('blob')
      const filename = `soc-report-${nowStr()}.pdf`
      await exportBlob(blob, filename, 'SOC评估报告')
      exporting.value = false
    } catch (e) {
      exporting.value = false
      alert('PDF导出失败: ' + e.message)
    }
  }

  return { exportReport, exporting }
}
