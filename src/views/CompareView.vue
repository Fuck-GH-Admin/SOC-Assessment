<template>
  <div class="section-card">
    <div class="section-header">
      <div class="section-icon">📊</div>
      <div class="section-title">多记录对比分析</div>
    </div>

    <div v-if="historyStore.records.length === 0" class="empty-state">
      <div class="icon">📭</div>
      <p>暂无历史记录可对比</p>
      <p style="font-size: 0.8rem; margin-top: 0.5rem;">先进行计算并保存记录</p>
    </div>

    <template v-else>
      <div class="search-bar">
        <select v-model="selectedIds" class="form-select" style="flex:1;" @change="updateSelectedList">
          <option value="" disabled>选择记录添加到对比...</option>
          <option v-for="rec in availableRecords" :key="rec.id" :value="rec.id">
            [{{ rec.fert === 'F' ? '施肥' : '不施肥' }}] 侵蚀{{ rec.erosion }}cm SOC={{ rec.results?.soc }} ({{ formatDate(rec.timestamp) }})
          </option>
        </select>
        <button class="btn btn-danger" style="padding: 0.5rem 1rem;" @click="clearSelection">清空</button>
      </div>

      <div v-if="compareRecords.length === 0" class="empty-state">
        <div class="icon">👆</div>
        <p>从上方选择2-4条记录进行对比</p>
      </div>

      <template v-else>
        <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-bottom: 1rem;">
          <span v-for="rec in compareRecords" :key="rec.id"
            class="record-badge" :class="rec.fert === 'F' ? 'badge-fert' : 'badge-unf'"
          >
            [{{ rec.fert === 'F' ? '施肥' : '不施肥' }}] 侵蚀{{ rec.erosion }}cm
            <span style="cursor: pointer; margin-left: 0.5rem;" @click="removeRecord(rec.id)">✕</span>
          </span>
        </div>

        <div class="chart-container" style="height: 400px;">
          <canvas ref="compareCanvas"></canvas>
        </div>

        <table class="data-table">
          <thead>
            <tr>
              <th>指标</th>
              <th v-for="rec in compareRecords" :key="rec.id">
                [{{ rec.fert === 'F' ? '施肥' : '不施肥' }}] 侵蚀{{ rec.erosion }}cm
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="metric in compareMetrics" :key="metric.key">
              <td>{{ metric.label }}</td>
              <td v-for="rec in compareRecords" :key="rec.id">
                {{ getMetricValue(rec, metric.key) }}
              </td>
            </tr>
          </tbody>
        </table>
      </template>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useHistoryStore } from '@/stores/history.js'
import { Chart, registerables } from 'chart.js'

Chart.register(...registerables)
const historyStore = useHistoryStore()
const compareCanvas = ref(null)
const selectedIds = ref('')
const compareRecordIds = ref([])
let chart = null

const availableRecords = computed(() =>
  historyStore.records.filter(r => !compareRecordIds.value.includes(r.id))
)

const compareRecords = computed(() =>
  historyStore.records.filter(r => compareRecordIds.value.includes(r.id))
)

const compareMetrics = [
  { key: 'soc', label: 'SOC含量 (g/kg)' },
  { key: 'carbonStorage', label: '碳库储量 (kg C/m²)' },
  { key: 'carbonDensity', label: '碳密度 (kg C/m³)' },
  { key: 'netChange', label: '碳库净变化量 (kg C/m²)' },
  { key: 'recoveryRate', label: '年恢复速率 (kg C/m²/年)' },
  { key: 'lossRate', label: 'SOC损失率 (%)' }
]

function getMetricValue(rec, key) { return rec.results?.[key] ?? '--' }

function updateSelectedList() {
  if (!selectedIds.value) return
  if (compareRecordIds.value.length >= 4) { alert('最多对比4条记录'); return }
  if (!compareRecordIds.value.includes(selectedIds.value)) {
    compareRecordIds.value.push(selectedIds.value)
    renderCompareChart()
  }
  selectedIds.value = ''
}

function removeRecord(id) {
  compareRecordIds.value = compareRecordIds.value.filter(i => i !== id)
  renderCompareChart()
}

function clearSelection() { compareRecordIds.value = []; renderCompareChart() }

function formatDate(ts) {
  const d = new Date(ts)
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}

async function renderCompareChart() {
  if (chart) { chart.destroy(); chart = null }
  if (compareRecords.value.length < 2 || !compareCanvas.value) return
  await nextTick()
  const ctx = compareCanvas.value.getContext('2d')
  const colors = ['rgba(74,158,255,0.8)', 'rgba(0,217,165,0.8)', 'rgba(255,193,7,0.8)', 'rgba(233,69,96,0.8)']
  chart = new Chart(ctx, {
    type: 'radar',
    data: {
      labels: ['SOC含量', '碳库储量', '碳密度', '净变化量', '恢复速率', '损失率'],
      datasets: compareRecords.value.filter(rec => rec.results).map((rec, i) => ({
        label: `[${rec.fert === 'F' ? '施肥' : '不施肥'}] 侵蚀${rec.erosion}cm`,
        data: [
          normalize(rec.results.soc, 0, 25),
          normalize(rec.results.carbonStorage, 0, 10),
          normalize(rec.results.carbonDensity, 0, 50),
          normalize(rec.results.netChange, -5, 5),
          normalize(rec.results.recoveryRate, 0, 1),
          100 - normalize(rec.results.lossRate, 0, 100)
        ],
        backgroundColor: colors[i].replace('0.8', '0.15'),
        borderColor: colors[i]
      }))
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      scales: { r: { min: 0, max: 100, ticks: { stepSize: 20 } } },
      plugins: { title: { display: true, text: '多记录综合对比', font: { size: 14 } } }
    }
  })
}

function normalize(value, min, max) {
  return Math.max(0, Math.min(100, ((value - min) / (max - min)) * 100))
}

onMounted(async () => {
  try {
    await historyStore.loadRecords()
  } catch (e) {
    console.error('加载历史记录失败:', e)
  }
})
</script>

<style scoped>
.record-badge {
  font-size: 0.75rem; padding: 0.35rem 0.75rem; border-radius: 6px;
  font-weight: 600;
}
.badge-fert { background: rgba(74, 158, 255, 0.2); color: var(--accent); border: 1px solid var(--accent); }
.badge-unf { background: rgba(233, 69, 96, 0.2); color: var(--danger); border: 1px solid var(--danger); }
</style>
