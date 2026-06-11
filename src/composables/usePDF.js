import { ref } from 'vue'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'

const exporting = ref(false)

function isMobile() {
  return typeof navigator !== 'undefined' && /android|ios/i.test(navigator.userAgent)
}

async function shareOrDownload(blob, filename, mimeType) {
  if (isMobile() && navigator.share && navigator.canShare) {
    const file = new File([blob], filename, { type: mimeType })
    if (navigator.canShare({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: filename })
        return { method: 'share' }
      } catch (e) {
        if (e?.name === 'AbortError') return { method: 'cancelled' }
      }
    }
  }
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  setTimeout(() => URL.revokeObjectURL(url), 1000)
  return { method: 'download' }
}

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
      const result = await shareOrDownload(blob, filename, 'application/pdf')
      exporting.value = false
      return result
    } catch (e) {
      exporting.value = false
      throw e
    }
  }

  return { exportPDF, exporting, shareOrDownload }
}
