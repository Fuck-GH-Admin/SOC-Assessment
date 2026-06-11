import { defineStore } from 'pinia'
import { ref } from 'vue'
import db from '@/db/index.js'

export const useHistoryStore = defineStore('history', () => {
  const records = ref([])
  const loading = ref(false)

  async function loadRecords() {
    loading.value = true
    records.value = await db.records.orderBy('timestamp').reverse().toArray()
    loading.value = false
  }

  async function saveRecord(data) {
    const id = await db.records.add({
      ...data,
      timestamp: Date.now()
    })
    await loadRecords()
    return id
  }

  async function deleteRecord(id) {
    await db.records.delete(id)
    await loadRecords()
  }

  async function exportData() {
    try {
      const all = await db.records.toArray()
      const sanitized = all.map(({ inputs, ...rest }) => {
        if (inputs) {
          const { apiKey, ...safeInputs } = inputs
          return { ...rest, inputs: safeInputs }
        }
        return rest
      })
      const json = JSON.stringify(sanitized, null, 2)
      const filename = `soc-records-${new Date().toISOString().slice(0, 10)}.json`
      const blob = new Blob([json], { type: 'application/json' })

      const isM = /android|ios/i.test(navigator.userAgent)
      if (isM) {
        try {
          const { Filesystem, Directory } = await import('@capacitor/filesystem')
          const reader = new FileReader()
          const base64 = await new Promise((resolve, reject) => {
            reader.onloadend = () => resolve(reader.result.split(',')[1])
            reader.onerror = reject
            reader.readAsDataURL(blob)
          })
          const result = await Filesystem.writeFile({
            path: filename,
            data: base64,
            directory: Directory.Documents,
            recursive: true
          })
          alert('数据已保存到: ' + (result.uri || 'Documents'))
          return
        } catch (fsErr) {
          console.warn('Filesystem write failed, fallback to download:', fsErr)
        }
      }

      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = filename
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      if (isM) window.open(url, '_blank')
      setTimeout(() => URL.revokeObjectURL(url), 1000)
      alert('数据已导出到下载目录')
    } catch (e) {
      console.error('导出失败:', e)
      alert('导出失败: ' + e.message)
    }
  }

  async function importData(file) {
    const text = await file.text()
    const data = JSON.parse(text)
    if (!Array.isArray(data)) throw new Error('数据格式错误')
    const clean = data.map(({ id, ...rest }) => rest)
    await db.records.bulkAdd(clean)
    await loadRecords()
  }

  function searchRecords(query) {
    if (!query) return records.value
    const q = query.toLowerCase()
    return records.value.filter(r =>
      r.fert?.toLowerCase()?.includes(q) ||
      String(r.erosion ?? '').includes(q) ||
      (r.results?.soc != null && String(r.results.soc).includes(q))
    )
  }

  return { records, loading, loadRecords, saveRecord, deleteRecord, exportData, importData, searchRecords }
})
