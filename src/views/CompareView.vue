<template>
  <div class="section-card">
    <div class="section-header">
      <div class="section-icon">📊</div>
      <div class="section-title">多记录对比分析</div>
    </div>

    <div v-if="!historyStore.records.length" class="empty-state">
      <div class="icon">📭</div>
      <p>暂无历史记录，请先进行计算</p>
    </div>

    <div v-else>
      <div style="display:flex;gap:1rem;margin-bottom:1rem;align-items:center;flex-wrap:wrap;">
        <select v-model="compareRecordIds" multiple class="form-select" style="flex:1;min-height:120px;">
          <option v-for="rec in historyStore.records" :key="rec.id" :value="rec.id">
            SOC: {{ rec.results?.soc }} g/kg | {{ rec.fert === 'F' ? '施肥' : '不施肥' }} | 侵蚀{{ rec.erosion }}cm | {{ new Date(rec.timestamp).toLocaleDateString() }}
          </option>
        </select>
        <button class="btn btn-primary" @click="updateChart">📊 对比</button>
      </div>

      <div class="chart-container" ref="compareDom" style="min-height:400px;"></div>

      <div v-if="compareRecordIds.length >= 2" class="data-scroll" style="margin-top:1rem;">
        <table class="data-table">
          <thead><tr><th>指标</th><th v-for="(id,i) in compareRecordIds" :key="id">记录{{ i+1 }}</th></tr></thead>
          <tbody>
            <tr><td>SOC (g/kg)</td><td v-for="id in compareRecordIds" :key="id">{{ getRec(id)?.results?.soc }}</td></tr>
            <tr><td>碳库储量</td><td v-for="id in compareRecordIds" :key="id">{{ getRec(id)?.results?.carbonStorage }}</td></tr>
            <tr><td>碳密度</td><td v-for="id in compareRecordIds" :key="id">{{ getRec(id)?.results?.carbonDensity }}</td></tr>
            <tr><td>恢复速率</td><td v-for="id in compareRecordIds" :key="id">{{ getRec(id)?.results?.recoveryRate }}</td></tr>
            <tr><td>施肥</td><td v-for="id in compareRecordIds" :key="id">{{ getRec(id)?.fert === 'F' ? '施肥' : '不施肥' }}</td></tr>
            <tr><td>侵蚀(cm)</td><td v-for="id in compareRecordIds" :key="id">{{ getRec(id)?.erosion }}</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { useHistoryStore } from '@/stores/history.js'
import * as echarts from 'echarts'

const historyStore = useHistoryStore()
const compareDom = ref(null)
const compareRecordIds = ref([])
let chart = null

function getRec(id) {
  return historyStore.records.find(r => r.id === id)
}

function updateChart() {
  if (!compareDom.value || compareRecordIds.value.length < 2) return
  if (chart) chart.dispose()

  const ids = compareRecordIds.value
  const records = ids.map(id => getRec(id)).filter(Boolean)
  const labels = ['SOC含量','碳库储量','碳密度','恢复速率','净变化']

  chart = echarts.init(compareDom.value, null, { renderer: 'svg' })
  chart.setOption({
    title: { text: '多记录对比分析', left: 'center', textStyle: { color: '#e8e8e8' } },
    tooltip: { trigger: 'axis' },
    legend: { data: records.map((_,i) => `记录${i+1}`), top: 30, textStyle: { color: '#889' } },
    xAxis: { type: 'category', data: labels, axisLabel: { color: '#889' } },
    yAxis: { type: 'value', axisLabel: { color: '#889' } },
    series: records.map((r, i) => ({
      name: `记录${i+1}`,
      type: 'bar',
      data: [
        r.results?.soc || 0,
        r.results?.carbonStorage || 0,
        r.results?.carbonDensity || 0,
        r.results?.recoveryRate || 0,
        Math.abs(r.results?.netChange || 0)
      ]
    })),
    backgroundColor: 'transparent'
  })
}

onMounted(async () => {
  await historyStore.loadRecords()
})
</script>

<style scoped>
.chart-container { background: var(--primary); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; }
</style>
