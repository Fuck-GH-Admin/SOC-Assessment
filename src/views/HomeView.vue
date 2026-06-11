<template>
  <div>
    <div class="page-title">
      <div class="page-title-bar"></div>
      <div>
        <h2>东北黑土区农田土壤有机碳模拟系统</h2>
        <p>输入土壤参数，系统将自动计算SOC含量及碳库变化</p>
      </div>
    </div>

    <div class="section-card">
      <div class="section-header">
        <div class="section-icon">⚙️</div>
        <div class="section-title">基本参数输入</div>
      </div>
      <div class="form-grid">
        <div class="form-group">
          <label class="form-label">施肥处理 <span class="param-badge">Fert</span></label>
          <select v-model="store.inputs.fert" class="form-select">
            <option value="F">施肥 (F)</option>
            <option value="UNF">不施肥 (UNF)</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">侵蚀强度 <span class="param-badge">Erosion</span></label>
          <select v-model="store.inputs.erosion" class="form-select">
            <option v-for="e in erosionOptions" :key="e.value" :value="e.value">{{ e.label }}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">土层深度 <span class="param-badge">Depth</span></label>
          <select v-model="store.inputs.depth" class="form-select">
            <option value="10">0-20 cm (表层)</option>
            <option value="25">20-30 cm (亚表层)</option>
            <option value="35">30-40 cm (中层)</option>
            <option value="45">40-50 cm (深层)</option>
            <option value="55">50-60 cm (底层)</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">土壤容重 <span class="param-badge">BD</span></label>
          <input type="number" v-model.number="store.inputs.bd" class="form-input" step="0.01" />
        </div>
        <div class="form-group">
          <label class="form-label">pH值 <span class="param-badge">pH</span></label>
          <input type="number" v-model.number="store.inputs.ph" class="form-input" step="0.01" />
        </div>
        <div class="form-group">
          <label class="form-label">含水量 <span class="param-badge">WC</span></label>
          <input type="number" v-model.number="store.inputs.wc" class="form-input" step="0.1" />
        </div>
        <div class="form-group">
          <label class="form-label">黏+粉粒含量 <span class="param-badge">Clay</span></label>
          <input type="number" v-model.number="store.inputs.clay" class="form-input" step="0.1" />
        </div>
        <div class="form-group">
          <label class="form-label">全氮含量 <span class="param-badge">TN</span></label>
          <input type="number" v-model.number="store.inputs.tn" class="form-input" step="0.01" />
        </div>
        <div class="form-group">
          <label class="form-label">秸秆生物量 <span class="param-badge">Biomass</span></label>
          <input type="number" v-model.number="store.inputs.cropBiomass" class="form-input" step="100" placeholder="8500" />
        </div>
        <div class="form-group">
          <label class="form-label">秸秆碳含量 <span class="param-badge">C%</span></label>
          <input type="number" v-model.number="store.inputs.strawCarbonRatio" class="form-input" step="0.01" placeholder="0.45" />
        </div>
      </div>
      <div class="btn-group">
        <button class="btn btn-primary" @click="handleCalculate">
          <span>🧮</span> 执行计算
        </button>
        <button class="btn btn-secondary" @click="store.reset()">
          <span>🔄</span> 重置
        </button>
      </div>
    </div>

    <div v-if="store.errors.length" class="section-card" style="border-color: var(--danger)">
      <div class="section-header">
        <div class="section-icon" style="background: var(--danger)">✗</div>
        <div class="section-title" style="color: var(--danger)">参数验证失败</div>
      </div>
      <ul style="list-style: none;">
        <li v-for="err in store.errors" :key="err" class="error-msg">• {{ err }}</li>
      </ul>
    </div>

    <div v-if="store.results" ref="pdfArea" id="resultsSection">
      <div class="section-card">
      <div class="section-header">
        <div class="section-icon">📈</div>
        <div class="section-title">计算结果</div>
        <button class="btn btn-secondary" style="margin-left: auto; padding: 0.4rem 0.8rem; font-size: 0.8rem;" @click="saveResult">
          💾 保存
        </button>
        <button class="btn" style="padding: 0.4rem 0.8rem; font-size: 0.8rem; background: var(--accent); color: #fff; border: none; border-radius: 8px; cursor: pointer;" @click="handleExportPDF" :disabled="pdfExporting">
          {{ pdfExporting ? '⏳ ...' : '📄 PDF' }}
        </button>
      </div>
      <div class="results-grid">
        <div class="result-card highlight">
          <div class="result-label">SOC含量</div>
          <div class="result-value">{{ store.results.soc }}</div>
          <div class="result-unit">g/kg</div>
        </div>
        <div class="result-card">
          <div class="result-label">碳库储量</div>
          <div class="result-value">{{ store.results.carbonStorage }}</div>
          <div class="result-unit">kg C/m²</div>
        </div>
        <div class="result-card">
          <div class="result-label">碳库净变化量</div>
          <div class="result-value">{{ store.results.netChange }}</div>
          <div class="result-unit">kg C/m²</div>
        </div>
        <div class="result-card">
          <div class="result-label">年恢复速率</div>
          <div class="result-value">{{ store.results.recoveryRate }}</div>
          <div class="result-unit">kg C/m²/年</div>
        </div>
        <div class="result-card">
          <div class="result-label">碳密度</div>
          <div class="result-value">{{ store.results.carbonDensity }}</div>
          <div class="result-unit">kg C/m³</div>
        </div>
        <div class="result-card">
          <div class="result-label">SOC损失率</div>
          <div class="result-value">{{ store.results.lossRate }}</div>
          <div class="result-unit">%</div>
        </div>
      </div>

      <table class="data-table">
        <thead>
          <tr>
            <th>参数名称</th><th>符号</th><th>数值</th><th>单位</th><th>说明</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in resultRows" :key="row.symbol">
            <td>{{ row.name }}</td><td>{{ row.symbol }}</td>
            <td>{{ row.value }}</td><td>{{ row.unit }}</td><td>{{ row.note }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="store.resilience" class="section-card">
      <div class="section-header">
        <div class="section-icon" style="background: linear-gradient(135deg, #00c853, #00a040)">🌱</div>
        <div class="section-title">土壤恢复力评估（论文方法）</div>
      </div>
      <div class="results-grid">
        <div class="result-card">
          <div class="result-label">表层碳库 0-20cm</div>
          <div class="result-value">{{ store.resilience.carbonPool_0_20 }}</div>
          <div class="result-unit">kg C/m²</div>
        </div>
        <div class="result-card">
          <div class="result-label">剖面碳库 0-60cm</div>
          <div class="result-value">{{ store.resilience.carbonPool_0_60 }}</div>
          <div class="result-unit">kg C/m²</div>
        </div>
        <div class="result-card">
          <div class="result-label">20年净变化量</div>
          <div class="result-value">{{ store.resilience.netChange_20yr }}</div>
          <div class="result-unit">kg C/m²</div>
        </div>
        <div class="result-card">
          <div class="result-label">100年净变化量</div>
          <div class="result-value">{{ store.resilience.netChange_100yr }}</div>
          <div class="result-unit">kg C/m²</div>
        </div>
        <div class="result-card highlight">
          <div class="result-label">年恢复速率</div>
          <div class="result-value">{{ store.resilience.recoveryRate_annual }}</div>
          <div class="result-unit">kg C/m²/年</div>
        </div>
        <div class="result-card" :style="{ borderColor: store.resilience.status.includes('亏损') ? 'var(--danger)' : 'var(--success)' }">
          <div class="result-label">恢复状态</div>
          <div class="result-value" style="font-size:1rem; -webkit-text-fill-color: initial; background: none; color: var(--text);">
            {{ store.resilience.status }}
          </div>
        </div>
      </div>

      <div v-if="store.resilience.strawScenarios" class="formula-display" style="margin-top: 1rem;">
        <div class="flow-title" style="font-size: 1rem; font-weight: 600; margin-bottom: 1rem; color: var(--accent);">
          🌾 秸秆还田情景模拟
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem;">
          <div v-for="s in store.resilience.strawScenarios" :key="s.label"
            class="result-card" style="text-align: center;">
            <div class="result-label">{{ s.label }}</div>
            <div class="result-value" style="font-size: 1.2rem;">{{ s.totalInput.toFixed(3) }}</div>
            <div class="result-unit">kg C/m² 总碳输入</div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="store.results" class="section-card">
      <div class="section-header">
        <div class="section-icon">📊</div>
        <div class="section-title">数据可视化</div>
      </div>
      <div class="tabs">
        <button v-for="tab in chartTabs" :key="tab.id"
          class="tab" :class="{ active: activeTab === tab.id }"
          @click="activeTab = tab.id">{{ tab.label }}</button>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'erosion' }">
        <div class="chart-container">
          <canvas ref="erosionCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'depth' }">
        <div class="chart-container">
          <canvas ref="depthCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'time' }">
        <div class="chart-container">
          <canvas ref="timeCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'radar' }">
        <div class="chart-container">
          <canvas ref="radarCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'pie' }">
        <div class="chart-container">
          <canvas ref="pieCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'scatter' }">
        <div class="chart-container">
          <canvas ref="scatterCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'stacked' }">
        <div class="chart-container">
          <canvas ref="stackedCanvas"></canvas>
        </div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'heatmap' }">
        <div style="text-align:right;margin-bottom:0.4rem;">
          <button class="btn btn-sm btn-secondary" @click="toggleHeatmapValues" style="font-size:0.7rem;padding:0.25rem 0.5rem;">
            {{ showHeatmapValues ? '隐藏数值' : '显示数值' }}
          </button>
        </div>
        <div class="chart-container">
          <canvas ref="heatmapCanvas"></canvas>
        </div>
      </div>
    </div>

    <div v-if="store.results && hasApiConfig" class="section-card">
      <div class="section-header">
        <div class="section-icon" style="background: linear-gradient(135deg, #9c27b0, #e040fb)">🤖</div>
        <div class="section-title">AI 评估报告</div>
        <span v-if="!online" class="warning-banner" style="margin:0;padding:0.3rem 0.6rem;">🛜 离线</span>
      </div>
      <button v-if="!aiReport && !reportGenerating" class="btn btn-primary" @click="handleAIReport" :disabled="reportGenerating || !online">
        📝 生成评估报告
      </button>
      <div v-if="reportGenerating && !aiReport" class="ai-report" style="text-align:center;color:var(--text-muted);">
        <div class="loading-dots">⏳ AI 正在生成报告</div>
      </div>
      <div v-if="reasoningContent" class="ai-report reasoning-box">
        <details>
          <summary style="cursor:pointer;font-weight:600;color:var(--accent);">🤔 思考过程（点击展开）</summary>
          <div style="white-space:pre-wrap;font-size:0.85rem;color:var(--text-muted);margin-top:0.5rem;">{{ reasoningContent }}</div>
        </details>
      </div>
      <div v-if="aiReport" class="ai-report">
        <div class="markdown-body" v-html="renderMarkdown(aiReport)"></div>
        <button class="btn btn-secondary" @click="resetReport()" style="margin-top: 1rem;">
          🔄 重新生成
        </button>
      </div>
      <div v-if="reportError" class="error-msg" style="margin-top: 0.5rem;">{{ reportError }}</div>
    </div>
  </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useCalculatorStore } from '@/stores/calculator.js'
import { useHistoryStore } from '@/stores/history.js'
import { useOnlineStatus } from '@/composables/useOnlineStatus.js'
import { useAIReport } from '@/composables/useAIReport.js'
import { usePDF } from '@/composables/usePDF.js'
import db from '@/db/index.js'
import { Chart, registerables } from 'chart.js'
import { MatrixController, MatrixElement } from 'chartjs-chart-matrix'

Chart.register(...registerables, MatrixController, MatrixElement)
const store = useCalculatorStore()
const historyStore = useHistoryStore()
const { online } = useOnlineStatus()
const { generateReport, generating: reportGenerating, error: reportError, streamContent: aiReport, reasoningContent, resetReport, renderMarkdown } = useAIReport()
const { exportPDF, exporting: pdfExporting } = usePDF()

const showHeatmapValues = ref(false)
const activeTab = ref('erosion')
const pdfArea = ref(null)
const erosionCanvas = ref(null)
const depthCanvas = ref(null)
const timeCanvas = ref(null)
const radarCanvas = ref(null)
const pieCanvas = ref(null)
const scatterCanvas = ref(null)
const stackedCanvas = ref(null)
const heatmapCanvas = ref(null)

const hasApiConfig = ref(false)
const calculating = ref(false)
let charts = []

const erosionOptions = [
  { value: '0', label: '0 cm - 无侵蚀' },
  { value: '10', label: '10 cm - 轻度' },
  { value: '20', label: '20 cm - 轻度' },
  { value: '30', label: '30 cm - 中度' },
  { value: '40', label: '40 cm - 中度' },
  { value: '50', label: '50 cm - 重度' },
  { value: '60', label: '60 cm - 重度' },
  { value: '70', label: '70 cm - 极重度' }
]

const chartTabs = [
  { id: 'erosion', label: '侵蚀强度影响' },
  { id: 'depth', label: '深度分布' },
  { id: 'time', label: '时间变化' },
  { id: 'radar', label: '综合评估' },
  { id: 'pie', label: '碳库组成' },
  { id: 'scatter', label: '参数关联' },
  { id: 'stacked', label: '碳库时间变化' },
  { id: 'heatmap', label: '侵蚀×深度分布' }
]

const resultRows = computed(() => {
  if (!store.results) return []
  const fertLabel = store.inputs.fert === 'F' ? '施肥' : '不施肥'
  const depthLabels = { 10: '0-20 cm (表层)', 25: '20-30 cm (亚表层)', 35: '30-40 cm (中层)', 45: '40-50 cm (深层)', 55: '50-60 cm (底层)' }
  return [
    { name: '土壤有机碳含量', symbol: 'SOC', value: store.results.soc, unit: 'g/kg', note: '核心指标' },
    { name: '土壤碳库储量', symbol: 'C_storage', value: store.results.carbonStorage, unit: 'kg C/m²', note: '单位面积碳储量' },
    { name: '碳库净变化量', symbol: 'ΔC', value: store.results.netChange, unit: 'kg C/m²', note: '相对变化量' },
    { name: '年恢复速率', symbol: 'R_rate', value: store.results.recoveryRate, unit: 'kg C/m²/年', note: '年均变化' },
    { name: '碳密度', symbol: 'C_density', value: store.results.carbonDensity, unit: 'kg C/m³', note: '体积密度' },
    { name: 'SOC损失率', symbol: 'Loss', value: store.results.lossRate, unit: '%', note: '相对损失' },
    { name: '施肥处理', symbol: 'Fert', value: fertLabel, unit: '-', note: store.inputs.fert === 'F' ? '施氮肥' : '对照' },
    { name: '侵蚀强度', symbol: 'Erosion', value: store.inputs.erosion + ' cm', unit: '-', note: '土壤侵蚀深度' },
    { name: '土层深度', symbol: 'Depth', value: depthLabels[store.inputs.depth] || '', unit: '-', note: '采样深度' },
    { name: '土壤容重', symbol: 'BD', value: store.inputs.bd, unit: 'g/cm³', note: '实测值' }
  ]
})

const baseData = {
  F: {
    0: [23.90,16.64,13.09,10.30,8.10], 10: [17.64,10.16,7.09,4.91,5.89],
    20: [11.77,8.48,6.84,5.77,4.94], 30: [9.30,12.62,8.93,7.47,7.06],
    40: [12.51,11.50,8.80,8.28,6.50], 50: [19.92,13.39,11.54,9.94,7.17],
    60: [8.82,9.81,8.36,8.20,6.79], 70: [7.40,9.81,7.95,7.46,7.70]
  },
  UNF: {
    0: [23.90,17.71,15.03,8.34,10.58], 10: [17.64,18.31,12.43,9.04,7.89],
    20: [21.03,17.02,15.03,11.93,9.47], 30: [13.76,13.45,10.54,8.52,7.81],
    40: [13.16,14.08,10.91,9.04,7.71], 50: [12.41,14.52,12.15,10.19,8.26],
    60: [10.53,10.80,8.80,8.30,7.21], 70: [12.81,13.24,11.36,9.38,8.56]
  }
}

const depthLabels = ['表层', '亚表层', '中层', '深层', '底层']

function destroyCharts() { charts.forEach(c => c.destroy()); charts = [] }

function renderErosionChart() {
  if (!erosionCanvas.value) return
  const ctx = erosionCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const erosionLevels = [0, 10, 20, 30, 40, 50, 60, 70]
  const socValues = erosionLevels.map(e => baseData[fert][e][0])
  const c = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: erosionLevels.map(e => e + ' cm'),
      datasets: [{
        label: fert === 'F' ? '施肥处理 SOC' : '不施肥处理 SOC',
        data: socValues,
        backgroundColor: 'rgba(74, 158, 255, 0.8)',
        borderColor: 'rgba(74, 158, 255, 1)',
        borderWidth: 1,
        borderRadius: 8
      }]
    },
    options: chartOpts('不同侵蚀强度下的SOC含量', '侵蚀强度 (cm)', 'SOC (g/kg)')
  })
  charts.push(c)
}

function renderDepthChart() {
  if (!depthCanvas.value) return
  const ctx = depthCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const erosion = parseInt(store.inputs.erosion)
  const socValues = baseData[fert][erosion]
  const c = new Chart(ctx, {
    type: 'line',
    data: {
      labels: depthLabels,
      datasets: [{
        label: `侵蚀${erosion}cm时SOC垂直分布`,
        data: socValues,
        borderColor: 'rgba(0, 217, 165, 1)',
        backgroundColor: 'rgba(0, 217, 165, 0.1)',
        fill: true, tension: 0.4,
        pointBackgroundColor: 'rgba(0, 217, 165, 1)',
        pointRadius: 6
      }]
    },
    options: chartOpts('SOC含量的垂直分布特征', '土层深度', 'SOC (g/kg)')
  })
  charts.push(c)
}

function renderTimeChart() {
  if (!timeCanvas.value) return
  const ctx = timeCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const fData = fert === 'F'
    ? [23.9, 21.5, 19.2, 17.8, 16.6]
    : [23.9, 22.1, 20.5, 19.1, 17.7]
  const unfData = fert === 'F'
    ? [23.9, 22.1, 20.5, 19.1, 17.7]
    : [23.9, 21.5, 19.2, 17.8, 16.6]
  const c = new Chart(ctx, {
    type: 'line',
    data: {
      labels: ['0年', '5年', '10年', '15年', '20年'],
      datasets: [
        { label: '施肥处理', data: fert === 'F' ? fData : unfData,
          borderColor: 'rgba(74, 158, 255, 1)', backgroundColor: 'rgba(74, 158, 255, 0.1)',
          fill: true, tension: 0.4 },
        { label: '不施肥处理', data: fert === 'F' ? unfData : fData,
          borderColor: 'rgba(233, 69, 96, 1)', backgroundColor: 'rgba(233, 69, 96, 0.1)',
          fill: true, tension: 0.4 }
      ]
    },
    options: chartOpts('SOC含量随时间变化趋势', '种植年限', 'SOC (g/kg)')
  })
  charts.push(c)
}

function renderRadarChart() {
  if (!radarCanvas.value || !store.results) return
  const ctx = radarCanvas.value.getContext('2d')
  const r = store.results
  const c = new Chart(ctx, {
    type: 'radar',
    data: {
      labels: ['SOC含量', '碳库储量', '碳密度', '年恢复速率', '碳库净变化'],
      datasets: [{
        label: '当前评估',
        data: [normalize(r.soc, 0, 25), normalize(r.carbonStorage, 0, 10),
               normalize(r.carbonDensity, 0, 50), normalize(r.recoveryRate, 0, 1),
               normalize(r.netChange, -5, 5)],
        backgroundColor: 'rgba(74, 158, 255, 0.2)',
        borderColor: 'rgba(74, 158, 255, 1)',
        pointBackgroundColor: 'rgba(74, 158, 255, 1)'
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      scales: { r: { min: 0, max: 100, ticks: { stepSize: 20 } } },
      plugins: { title: { display: true, text: '土壤碳库多维度综合评估', font: { size: 14 } } }
    }
  })
  charts.push(c)
}

function renderPieChart() {
  if (!pieCanvas.value) return
  const ctx = pieCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const erosion = parseInt(store.inputs.erosion)
  const vals = depthLabels.map((_, i) => baseData[fert][erosion][i])
  const total = vals.reduce((a, b) => a + b, 0)
  const c = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: ['0-20cm', '20-30cm', '30-40cm', '40-50cm', '50-60cm'],
      datasets: [{
        data: vals.map(v => +((v / total) * 100).toFixed(1)),
        backgroundColor: ['rgba(74,158,255,0.8)', 'rgba(0,217,165,0.8)',
                         'rgba(255,193,7,0.8)', 'rgba(233,69,96,0.8)',
                         'rgba(156,39,176,0.8)']
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        title: { display: true, text: '各土层碳库组成比例', font: { size: 14 } },
        legend: { position: 'right' },
        tooltip: { callbacks: { label: ctx => `${ctx.label}: ${ctx.parsed}%` } }
      }
    }
  })
  charts.push(c)
}

function renderScatterChart() {
  if (!scatterCanvas.value) return
  const ctx = scatterCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const socByErosion = [0, 10, 20, 30, 40, 50, 60, 70].map(e => ({
    x: e, y: baseData[fert][e][0]
  }))
  const c = new Chart(ctx, {
    type: 'scatter',
    data: {
      datasets: [{
        label: 'SOC随侵蚀强度变化',
        data: socByErosion,
        backgroundColor: 'rgba(74, 158, 255, 0.8)',
        borderColor: 'rgba(74, 158, 255, 1)',
        pointRadius: 8,
        pointHoverRadius: 12
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { display: true, position: 'top' },
        title: { display: true, text: '侵蚀强度与SOC含量关联分析', font: { size: 14 } }
      },
      scales: {
        x: { title: { display: true, text: '侵蚀强度 (cm)' } },
        y: { title: { display: true, text: 'SOC (g/kg)' }, beginAtZero: true }
      }
    }
  })
  charts.push(c)
}

function renderStackedChart() {
  if (!stackedCanvas.value) return
  const ctx = stackedCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const erosion = parseInt(store.inputs.erosion)
  const top = baseData[fert][erosion][0]
  const sub = baseData[fert][erosion][1]
  const mid = baseData[fert][erosion][2]
  const deep = baseData[fert][erosion][3]
  const bottom = baseData[fert][erosion][4]
  const c = new Chart(ctx, {
    type: 'line',
    data: {
      labels: ['0-20cm', '20-30cm', '30-40cm', '40-50cm', '50-60cm'],
      datasets: [
        { label: `侵蚀${erosion}cm`, data: [top, sub, mid, deep, bottom],
          borderColor: 'rgba(74,158,255,0.9)', backgroundColor: 'rgba(74,158,255,0.8)',
          fill: true, tension: 0.4 },
        { label: '无侵蚀参考', data: baseData[fert][0],
          borderColor: 'rgba(0,217,165,0.9)', backgroundColor: 'rgba(0,217,165,0.3)',
          fill: true, tension: 0.4, borderDash: [5, 5] }
      ]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { display: true, position: 'top' },
        title: { display: true, text: '当前侵蚀 vs 无侵蚀 SOC分布对比', font: { size: 14 } },
        tooltip: { callbacks: { label: ctx => `${ctx.dataset.label}: ${ctx.parsed.y} g/kg` } }
      },
      scales: {
        x: { title: { display: true, text: '土层深度' } },
        y: { stacked: false, title: { display: true, text: 'SOC (g/kg)' }, beginAtZero: true }
      }
    }
  })
  charts.push(c)
}

let heatmapPluginId = 0

const heatmapValuePlugin = {
  id: 'heatmapValueLabels',
  afterDraw(chart) {
    if (!showHeatmapValues.value) return
    const cty = chart.ctx
    cty.save()
    cty.font = 'bold 11px sans-serif'
    cty.fillStyle = '#fff'
    cty.textAlign = 'center'
    cty.textBaseline = 'middle'
    const meta = chart.getDatasetMeta(0)
    if (meta && meta.data) {
      meta.data.forEach(el => {
        const v = el.$context?.raw?.v
        if (v != null && isFinite(v)) {
          cty.fillText(String(Math.round(v * 10) / 10), el.x, el.y)
        }
      })
    }
    cty.restore()
  }
}

function heatmapColor(value, min, max) {
  if (max === min) return 'rgba(74,158,255,0.8)'
  const t = (value - min) / (max - min)
  const r = Math.round(233 - t * 159)
  const g = Math.round(69 + t * 116)
  const b = Math.round(96 - t * 96)
  return `rgba(${r},${g},${b},0.85)`
}

function renderHeatmapChart() {
  if (!heatmapCanvas.value) return
  const ctx = heatmapCanvas.value.getContext('2d')
  const fert = store.inputs.fert
  const erosionLevels = [0, 10, 20, 30, 40, 50, 60, 70]
  const depthIdx = [0, 1, 2, 3, 4]
  const data = erosionLevels.flatMap(e =>
    depthIdx.map(d => ({
      x: e, y: d, v: baseData[fert][e][d] || 0
    }))
  )
  const maxV = Math.max(...data.map(d => d.v))
  const minV = Math.min(...data.map(d => d.v))
  if (maxV === 0 && minV === 0) return
  const heatData = data.map(d => ({
    x: d.x, y: d.y,
    v: d.v,
    backgroundColor: heatmapColor(d.v, minV, maxV)
  }))
  const c = new Chart(ctx, {
    type: 'matrix',
    plugins: [heatmapValuePlugin],
    data: {
      datasets: [{
        label: 'SOC (g/kg)',
        data: heatData,
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.15)',
        width: ({ chart }) => (chart.chartArea.width / 8) * 0.85,
        height: ({ chart }) => (chart.chartArea.height / 5) * 0.85
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      animation: false,
      plugins: {
        legend: false,
        title: { display: true, text: '侵蚀强度x土层深度 SOC分布热力图', font: { size: 14 } },
        tooltip: {
          callbacks: {
            title: () => '',
            label: ctx => `侵蚀${ctx.parsed.x}cm · ${depthLabels[ctx.parsed.y]}: ${ctx.raw.v} g/kg`
          }
        }
      },
      scales: {
        x: { offset: true, ticks: { stepSize: 10, callback: v => v + 'cm' }, title: { display: true, text: '侵蚀强度(cm)' } },
        y: { offset: true, ticks: { callback: v => depthLabels[v] || '' }, title: { display: true, text: '土层深度' } }
      }
    }
  })
  charts.push(c)
}

function toggleHeatmapValues() {
  showHeatmapValues.value = !showHeatmapValues.value
  const idx = charts.findIndex(c => c.config.type === 'matrix')
  if (idx >= 0) { charts[idx].update('none') }
}

function normalize(value, min, max) {
  return Math.max(0, Math.min(100, ((value - min) / (max - min)) * 100))
}

function chartOpts(title, xLabel, yLabel) {
  return {
    responsive: true, maintainAspectRatio: false,
    plugins: { legend: { display: true, position: 'top' }, title: { display: true, text: title, font: { size: 14 } } },
    scales: {
      y: { beginAtZero: true, title: { display: true, text: yLabel } },
      x: { title: { display: true, text: xLabel } }
    }
  }
}

async function handleCalculate() {
  if (calculating.value) return
  calculating.value = true
  try {
    store.calculate()
  } catch (e) {
    console.error('计算失败:', e)
    calculating.value = false
    return
  }
  if (!store.results) { calculating.value = false; return }
  await renderAllCharts()
  document.getElementById('resultsSection')?.scrollIntoView({ behavior: 'smooth' })
  calculating.value = false
}

function sanitize(v) {
  if (typeof v === 'number' && isNaN(v)) return 0
  if (v === null || v === undefined) return 0
  return v
}

async function handleExportPDF() {
  if (pdfExporting.value || !pdfArea.value) return
  try {
    const result = await exportPDF(pdfArea.value, `soc-report-${new Date().toISOString().slice(0, 10)}.pdf`)
    if (result?.method === 'download') {
      alert('PDF已导出到下载目录')
    }
  } catch (e) {
    alert('PDF导出失败: ' + e.message)
  }
}

async function saveResult() {
  try {
    const raw = {
      fert: store.inputs.fert || '',
      erosion: parseInt(store.inputs.erosion) || 0,
      depth: parseInt(store.inputs.depth) || 0,
      inputs: { ...store.inputs },
      results: store.results ? { ...store.results } : null,
      resilience: store.resilience ? { ...store.resilience } : null
    }
    for (const [k, v] of Object.entries(raw.inputs)) raw.inputs[k] = typeof v === 'string' ? v : sanitize(v)
    for (const [k, v] of Object.entries(raw.results || {})) raw.results[k] = sanitize(v)
    const clone = JSON.parse(JSON.stringify(raw))
    await historyStore.saveRecord(clone)
    alert('✅ 记录已保存')
  } catch (e) {
    alert('❌ 保存失败: ' + e.message)
  }
}

async function handleAIReport() {
  if (!store.results) return
  let settings
  try {
    settings = await db.settings.get('ai')
  } catch (e) {
    reportError.value = '加载设置失败: ' + e.message
    return
  }
  if (!settings?.apiUrl || !settings?.apiKey) { hasApiConfig.value = false; return }
  hasApiConfig.value = true
  resetReport()
  await generateReport(settings.apiUrl, settings.apiKey, settings.model, {
    fert: store.inputs.fert,
    erosion: store.inputs.erosion,
    bd: store.inputs.bd,
    results: store.results
  }, settings.prompt, {
    enableThinking: settings.enableThinking,
    reasoningEffort: settings.reasoningEffort || 'high'
  })
}

async function renderAllCharts() {
  await nextTick()
  destroyCharts()
  renderErosionChart()
  renderDepthChart()
  renderTimeChart()
  renderRadarChart()
  renderPieChart()
  renderScatterChart()
  renderStackedChart()
  renderHeatmapChart()
}

onMounted(async () => {
  try {
    const settings = await db.settings.get('ai')
    hasApiConfig.value = !!(settings?.apiUrl && settings?.apiKey)
  } catch (e) {
    console.error('加载AI设置失败:', e)
  }
  if (store.results) await renderAllCharts()
})

onUnmounted(() => {
  destroyCharts()
})
</script>

<style scoped>
.page-title {
  display: flex; align-items: flex-start; gap: 0.75rem;
  margin-bottom: 2rem; padding: 1.5rem;
  background: var(--surface2); border: 1px solid var(--border);
  border-radius: 12px; box-shadow: var(--shadow);
}
.page-title-bar {
  width: 4px; height: 1.2rem;
  background: var(--gradient-1); border-radius: 2px; flex-shrink: 0;
  margin-top: 0.2rem;
}
.page-title h2 { font-size: 1.3rem; font-weight: 700; margin-bottom: 0.5rem; color: var(--text); }
.page-title p { color: var(--text-muted); font-size: 0.85rem; }
.ai-report {
  background: var(--primary); border: 1px solid var(--border);
  border-radius: 12px; padding: 1.5rem; margin-top: 1rem;
}
.reasoning-box {
  background: var(--surface2); border-color: var(--accent);
}
.markdown-body { font-size:0.9rem; line-height:1.8; color:var(--text); }
.markdown-body h1 { font-size:1.25rem; margin:1.2rem 0 0.6rem; color:var(--accent); font-weight:700; }
.markdown-body h2 { font-size:1.1rem; margin:1rem 0 0.5rem; font-weight:600; }
.markdown-body h3 { font-size:1rem; margin:0.8rem 0 0.4rem; font-weight:600; }
.markdown-body p { margin:0.6rem 0; }
.markdown-body strong { color:var(--accent); }
.markdown-body code, .markdown-body pre {
  background:var(--surface2); border-radius:6px; font-size:0.85rem;
}
.markdown-body code { padding:0.15rem 0.4rem; }
.markdown-body pre { padding:1rem; overflow-x:auto; margin:0.8rem 0; }
.markdown-body pre code { padding:0; background:none; }
.markdown-body ul, .markdown-body ol { padding-left:1.8rem; margin:0.6rem 0; }
.markdown-body li { margin:0.3rem 0; }
.markdown-body blockquote {
  border-left:3px solid var(--accent); padding:0.5rem 1rem; margin:0.8rem 0;
  background:var(--surface2); border-radius:0 8px 8px 0; color:var(--text-muted);
}
.markdown-body table { border-collapse:collapse; width:100%; margin:0.8rem 0; font-size:0.85rem; }
.markdown-body th, .markdown-body td {
  border:1px solid var(--border); padding:0.4rem 0.6rem; text-align:left;
}
.markdown-body th { background:var(--surface2); font-weight:600; }
.loading-dots { display:flex; align-items:center; justify-content:center; gap:0.3rem; }
.loading-dots::after {
  content:'...'; animation: dots 1.5s infinite;
}
@keyframes dots {
  0%,20% { content:'..'; } 40% { content:'...'; }
  60% { content:''; } 80%,100% { content:'.'; }
}
</style>
