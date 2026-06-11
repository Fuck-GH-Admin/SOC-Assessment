import { Filesystem, Directory } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'
import { Capacitor } from '@capacitor/core'

export async function exportBlob(blob, filename, label = '导出文件') {
  if (Capacitor.isNativePlatform()) {
    const base64 = await new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onerror = reject
      reader.onload = () => resolve(reader.result.split(',')[1])
      reader.readAsDataURL(blob)
    })
    const result = await Filesystem.writeFile({
      path: filename,
      data: base64,
      directory: Directory.Cache
    })
    await Share.share({
      title: label,
      url: result.uri,
      dialogTitle: '保存或分享'
    })
  } else {
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    setTimeout(() => URL.revokeObjectURL(url), 5000)
  }
}
