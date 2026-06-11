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
  let binary = ''
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i])
  fontBase64 = btoa(binary)
  fontReady = true
}

function registerFont(doc) {
  doc.addFileToVFS('SimHei.ttf', fontBase64)
  doc.addFont('SimHei.ttf', 'SimHei', 'normal')
}

export function usePDF() {
  async function exportReport(data) {
    exporting.value = true
    try {
      await loadFont()

      const doc = new jsPDF('p', 'mm', 'a4')
      registerFont(doc)

      doc.setFont('SimHei')
      let y = 20

      doc.setFontSize(16)
      doc.setTextColor('#1a1a2e')
      doc.text('SOC土壤有机碳评估报告', 15, y)
      y += 12

      doc.setFont('helvetica')
      doc.setFontSize(8)
      doc.setTextColor('#999')
      doc.text(`Generated: ${new Date().toISOString().replace('T', ' ').slice(0, 19)}`, 15, y)
      y += 8

      doc.setFont('SimHei')
      doc.setFontSize(12)
      doc.setTextColor('#4a9eff')
      doc.text('输入参数', 15, y)
      y += 8

      const rows = [
        ['参数', '值', '说明'],
        ['施肥处理', data.fert || '-', data.fert?.includes('施肥') ? '施氮肥' : '对照'],
        ['侵蚀强度', String(data.erosion || '0') + ' cm', '土壤侵蚀深度'],
        ['土壤容重', String(data.bd ?? '-'), 'g/cm\u00B3'],
        ['pH值', String(data.ph ?? '-'), ''],
        ['含水量', String(data.wc ?? '-'), '%'],
        ['黏+粉粒', String(data.clay ?? '-'), '%'],
        ['全氮含量', String(data.tn ?? '-'), '%'],
        ['秸秆生物量', String(data.cropBiomass ?? '-'), 'kg/ha'],
        ['秸秆碳含量', String(data.strawCarbon ?? '-'), '比例']
      ]

      doc.setFontSize(8)
      doc.setTextColor('#333')
      const colW = [36, 48, 48]
      rows.forEach((row, ri) => {
        if (y > 275) { doc.addPage(); y = 20; registerFont(doc); doc.setFont('SimHei'); doc.setFontSize(8) }
        if (ri === 0) {
          doc.setFont('SimHei', 'bold')
          doc.setFillColor('#eef2f7')
        } else {
          doc.setFont('SimHei', 'normal')
          doc.setFillColor(ri % 2 === 0 ? '#f7f9fc' : '#ffffff')
        }
        doc.setTextColor('#333')
        let x = 15
        row.forEach((cell, ci) => {
          doc.rect(x, y - 4, colW[ci] || 40, 6, 'F')
          doc.text(String(cell), x + 2, y)
          x += colW[ci] || 40
        })
        y += 7
      })
      y += 5

      if (data.results) {
        doc.setFontSize(12)
        doc.setTextColor('#4a9eff')
        doc.text('计算结果', 15, y)
        y += 8
        doc.setFontSize(8)
        const resRows = [
          ['指标', '数值', '单位'],
          ['SOC含量', String(data.results.soc ?? '-'), 'g/kg'],
          ['碳库储量', String(data.results.carbonStorage ?? '-'), 'kg C/m\u00B2'],
          ['碳密度', String(data.results.carbonDensity ?? '-'), 'kg C/m\u00B3'],
          ['净变化量', String(data.results.netChange ?? '-'), 'kg C/m\u00B2'],
          ['恢复速率', String(data.results.recoveryRate ?? '-'), 'kg C/m\u00B2/yr'],
          ['SOC损失率', String(data.results.lossRate ?? '-'), '%']
        ]
        resRows.forEach((row, ri) => {
          if (y > 275) { doc.addPage(); y = 20; registerFont(doc); doc.setFont('SimHei'); doc.setFontSize(8) }
          if (ri === 0) { doc.setFont('SimHei', 'bold'); doc.setFillColor('#eef2f7') }
          else { doc.setFont('SimHei', 'normal'); doc.setFillColor(ri % 2 === 0 ? '#f7f9fc' : '#ffffff') }
          doc.setTextColor('#333')
          let x = 15
          row.forEach((cell, ci) => {
            const w = ci === 0 ? 56 : (ci === 1 ? 48 : 40)
            doc.rect(x, y - 4, w, 6, 'F')
            doc.text(String(cell), x + 2, y)
            x += w
          })
          y += 7
        })
        y += 5
      }

      if (data.resilience) {
        doc.setFontSize(12)
        doc.setTextColor('#4a9eff')
        doc.text('土壤恢复力评估', 15, y)
        y += 8
        doc.setFontSize(8)
        const resRows = [
          ['指标', '数值', '单位'],
          ['表层碳库(0-20cm)', String(data.resilience.carbonPool_0_20 ?? '-'), 'kg C/m\u00B2'],
          ['剖面碳库(0-60cm)', String(data.resilience.carbonPool_0_60 ?? '-'), 'kg C/m\u00B2'],
          ['20年净变化量', String(data.resilience.netChange_20yr ?? '-'), 'kg C/m\u00B2'],
          ['100年净变化量', String(data.resilience.netChange_100yr ?? '-'), 'kg C/m\u00B2'],
          ['年恢复速率', String(data.resilience.recoveryRate_annual ?? '-'), 'kg C/m\u00B2/yr'],
          ['恢复状态', String(data.resilience.status ?? '-'), '-']
        ]
        resRows.forEach((row, ri) => {
          if (y > 275) { doc.addPage(); y = 20; registerFont(doc); doc.setFont('SimHei'); doc.setFontSize(8) }
          if (ri === 0) { doc.setFont('SimHei', 'bold'); doc.setFillColor('#eef2f7') }
          else { doc.setFont('SimHei', 'normal'); doc.setFillColor(ri % 2 === 0 ? '#f7f9fc' : '#ffffff') }
          doc.setTextColor('#333')
          let x = 15
          row.forEach((cell, ci) => {
            const w = ci === 0 ? 56 : (ci === 1 ? 48 : 40)
            doc.rect(x, y - 4, w, 6, 'F')
            doc.text(String(cell), x + 2, y)
            x += w
          })
          y += 7
        })
        y += 5
      }

      if (data.aiReport) {
        doc.setFontSize(12)
        doc.setTextColor('#4a9eff')
        doc.text('AI评估报告', 15, y)
        y += 8
        doc.setFontSize(8)
        doc.setTextColor('#333')
        const plain = data.aiReport.replace(/[*#`>\[\]]/g, '').replace(/\n{3,}/g, '\n\n').trim()
        if (plain) {
          const lines = doc.splitTextToSize(plain, 180)
          for (const line of lines) {
            if (y > 275) { doc.addPage(); y = 20; registerFont(doc); doc.setFont('SimHei'); doc.setFontSize(8) }
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
