import { ref } from 'vue'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'
import { exportBlob } from '@/utils/exportFile.js'

const exporting = ref(false)

function nowStr() {
  const d = new Date()
  return `${d.getFullYear()}${String(d.getMonth()+1).padStart(2,'0')}${String(d.getDate()).padStart(2,'0')}-${String(d.getHours()).padStart(2,'0')}${String(d.getMinutes()).padStart(2,'0')}${String(d.getSeconds()).padStart(2,'0')}`
}

export function usePDF() {
  async function exportReport(el) {
    exporting.value = true
    try {
      const canvas = await html2canvas(el, {
        scale: 3,
        useCORS: true,
        backgroundColor: '#0d1b2a',
        logging: false
      })
      const imgData = canvas.toDataURL('image/png')
      const imgW = 210
      const imgH = (canvas.height * imgW) / canvas.width
      const pdf = new jsPDF('p', 'mm', 'a4')
      let y = 0
      const pageH = 297
      while (y < imgH) {
        if (y > 0) pdf.addPage()
        pdf.addImage(imgData, 'PNG', 0, -y, imgW, imgH)
        y += pageH
      }
      const blob = pdf.output('blob')
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
