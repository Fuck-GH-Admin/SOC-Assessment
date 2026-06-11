import { ref } from 'vue'
import html2canvas from 'html2canvas'
import jsPDF from 'jspdf'

const exporting = ref(false)

function isMobile() {
  return typeof navigator !== 'undefined' && /android|ios/i.test(navigator.userAgent)
}

async function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  if (isMobile()) {
    window.open(url, '_blank')
  }
  setTimeout(() => URL.revokeObjectURL(url), 3000)
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

      const shared = await nativeShare(blob, filename, 'application/pdf')
      if (!shared) {
        await downloadBlob(blob, filename)
      }
      exporting.value = false
      return { method: shared ? 'share' : 'download' }
    } catch (e) {
      exporting.value = false
      throw e
    }
  }

  return { exportPDF, exporting, downloadBlob }
}
