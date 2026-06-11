import { ref } from 'vue'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'

const exporting = ref(false)

export function usePDF() {
  async function exportPDF(element, filename) {
    exporting.value = true
    try {
      const canvas = await html2canvas(element, {
        scale: 2,
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
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = filename
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      URL.revokeObjectURL(url)
      exporting.value = false
      return true
    } catch (e) {
      exporting.value = false
      throw e
    }
  }

  return { exportPDF, exporting }
}
