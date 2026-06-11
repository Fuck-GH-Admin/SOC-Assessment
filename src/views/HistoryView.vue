<template>
  <div class="section-card">
    <div class="section-header">
      <div class="section-icon">📋</div>
      <div class="section-title">历史评估记录</div>
      <div class="btn-group" style="margin-left: auto; margin-top: 0;">
        <button class="btn btn-secondary" @click="handleExport" style="padding: 0.4rem 0.8rem; font-size: 0.8rem;">
          📤 导出
        </button>
        <label class="btn btn-secondary" style="padding: 0.4rem 0.8rem; font-size: 0.8rem; cursor: pointer; :disabled { opacity: 0.6; }">
          {{ importing ? '⏳ 导入中...' : '📥 导入' }}
          <input type="file" accept=".json" hidden :disabled="importing" @change="handleImport" />
        </label>
      </div>
    </div>

    <div class="search-bar">
      <input type="text" v-model="searchQuery" class="search-input" placeholder="搜索施肥处理、侵蚀强度、SOC值..." />
      <select v-model="filterFert" class="form-select" style="max-width: 140px;">
        <option value="">全部处理</option>
        <option value="F">施肥</option>
        <option value="UNF">不施肥</option>
      </select>
      <select v-model="sortBy" class="form-select" style="max-width: 140px;">
        <option value="time_desc">最新优先</option>
        <option value="time_asc">最早优先</option>
        <option value="soc_desc">SOC从高到低</option>
        <option value="soc_asc">SOC从低到高</option>
      </select>
    </div>

    <div v-if="loading" class="empty-state">
      <div class="icon">⏳</div>
      <p>加载中...</p>
    </div>

    <div v-else-if="filteredRecords.length === 0" class="empty-state">
      <div class="icon">📭</div>
      <p>暂无历史记录</p>
      <p style="font-size: 0.8rem; margin-top: 0.5rem;">进行计算后点击「保存记录」即可在此查看</p>
    </div>

    <div v-else class="record-list">
      <div v-for="rec in filteredRecords" :key="rec.id" class="record-item" :class="{ expanded: expandedId === rec.id }">
        <div class="record-summary" @click="toggleExpand(rec.id)">
          <div class="record-main">
            <span class="record-badge" :class="rec.fert === 'F' ? 'badge-fert' : rec.fert === 'UNF' ? 'badge-unf' : 'badge-unknown'">
              {{ rec.fert === 'F' ? '施肥' : rec.fert === 'UNF' ? '不施肥' : '未知' }}
            </span>
            <span>侵蚀: {{ rec.erosion }}cm</span>
            <span>SOC: <strong>{{ rec.results?.soc }}</strong> g/kg</span>
            <span style="color: var(--text-muted); font-size: 0.75rem;">
              {{ formatDate(rec.timestamp) }}
            </span>
          </div>
          <div class="record-actions">
            <button class="btn btn-danger" style="padding: 0.25rem 0.5rem; font-size: 0.75rem;" @click.stop="handleDelete(rec.id)">
              🗑️
            </button>
          </div>
        </div>
        <div v-if="expandedId === rec.id" class="record-detail">
          <table class="data-table">
            <thead>
              <tr><th>指标</th><th>符号</th><th>数值</th><th>单位</th></tr>
            </thead>
            <tbody>
              <tr><td>SOC含量</td><td>SOC</td><td>{{ rec.results?.soc }}</td><td>g/kg</td></tr>
              <tr><td>碳库储量</td><td>C_storage</td><td>{{ rec.results?.carbonStorage }}</td><td>kg C/m²</td></tr>
              <tr><td>碳密度</td><td>C_density</td><td>{{ rec.results?.carbonDensity }}</td><td>kg C/m³</td></tr>
              <tr><td>碳库净变化量</td><td>ΔC</td><td>{{ rec.results?.netChange }}</td><td>kg C/m²</td></tr>
              <tr><td>年恢复速率</td><td>R_rate</td><td>{{ rec.results?.recoveryRate }}</td><td>kg C/m²/年</td></tr>
              <tr><td>SOC损失率</td><td>Loss</td><td>{{ rec.results?.lossRate }}</td><td>%</td></tr>
            </tbody>
          </table>
          <div style="margin-top: 0.75rem; display: flex; gap: 0.5rem;">
            <router-link to="/compare" class="btn btn-secondary" style="padding: 0.3rem 0.6rem; font-size: 0.75rem; text-decoration: none;">
              📊 前往对比
            </router-link>
          </div>
        </div>
      </div>
    </div>

    <div v-if="filteredRecords.length > 0" style="margin-top: 1rem; text-align: right; font-size: 0.8rem; color: var(--text-muted);">
      共 {{ filteredRecords.length }} 条记录
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useHistoryStore } from '@/stores/history.js'

const historyStore = useHistoryStore()
const searchQuery = ref('')
const filterFert = ref('')
const sortBy = ref('time_desc')
const expandedId = ref(null)
const loading = ref(true)
const importing = ref(false)
let mounted = true

const filteredRecords = computed(() => {
  let list = [...historyStore.records]
  if (filterFert.value) list = list.filter(r => r.fert === filterFert.value)
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(r =>
      r.fert?.toLowerCase()?.includes(q) ||
      String(r.erosion ?? '').includes(q) ||
      (r.results?.soc != null && String(r.results.soc).includes(q))
    )
  }
  switch (sortBy.value) {
    case 'time_asc': list.sort((a, b) => a.timestamp - b.timestamp); break
    case 'soc_desc': list.sort((a, b) => (b.results?.soc || 0) - (a.results?.soc || 0)); break
    case 'soc_asc': list.sort((a, b) => (a.results?.soc || 0) - (b.results?.soc || 0)); break
    default: list.sort((a, b) => b.timestamp - a.timestamp)
  }
  return list
})

function toggleExpand(id) { expandedId.value = expandedId.value === id ? null : id }

function formatDate(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}

async function handleDelete(id) {
  if (confirm('确定删除这条记录？')) await historyStore.deleteRecord(id)
}

async function handleExport() { await historyStore.exportData() }

async function handleImport(e) {
  const file = e.target.files[0]
  if (!file) return
  importing.value = true
  try { await historyStore.importData(file); alert('✅ 导入成功') }
  catch (err) { alert('❌ 导入失败: ' + err.message) }
  importing.value = false
  e.target.value = ''
}

onMounted(async () => {
  try {
    await historyStore.loadRecords()
  } catch (e) {
    console.error('加载历史记录失败:', e)
  }
  if (mounted) loading.value = false
})
onUnmounted(() => { mounted = false })
</script>

<style scoped>
.record-list { display: flex; flex-direction: column; gap: 0.5rem; }
.record-item {
  background: var(--primary); border: 1px solid var(--border);
  border-radius: 10px; overflow: hidden;
  transition: all 0.2s;
}
.record-item:hover { border-color: var(--accent); }
.record-summary {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0.85rem 1rem; cursor: pointer;
}
.record-main { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
.record-badge {
  font-size: 0.7rem; padding: 0.2rem 0.5rem; border-radius: 4px;
  font-weight: 600;
}
.badge-fert { background: rgba(74, 158, 255, 0.2); color: var(--accent); }
.badge-unf { background: rgba(233, 69, 96, 0.2); color: var(--danger); }
.badge-unknown { background: rgba(255, 193, 7, 0.2); color: var(--warning); }
.record-detail {
  border-top: 1px solid var(--border); padding: 1rem;
  background: rgba(13, 27, 42, 0.5);
}
.record-actions { display: flex; gap: 0.5rem; }
</style>
