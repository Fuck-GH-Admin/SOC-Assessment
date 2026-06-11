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

      <div class="data-scroll">
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
        <div class="chart-container" ref="erosionDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'depth' }">
        <div class="chart-container" ref="depthDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'time' }">
        <div class="chart-container" ref="timeDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'radar' }">
        <div class="chart-container" ref="radarDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'pie' }">
        <div class="chart-container" ref="pieDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'scatter' }">
        <div class="chart-container" ref="scatterDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'stacked' }">
        <div class="chart-container" ref="stackedDom"></div>
      </div>
      <div class="tab-content" :class="{ active: activeTab === 'heatmap' }">
        <div style="text-align:right;margin-bottom:0.4rem;">
          <button class="btn btn-sm btn-secondary" @click="toggleHeatmapValues" style="font-size:0.7rem;padding:0.25rem 0.5rem;">
            {{ showHeatmapValues ? '隐藏数值' : '显示数值' }}
          </button>
        </div>
        <div class="chart-container" ref="heatmapDom"></div>
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
import * as echarts from 'echarts'
const store = useCalculatorStore()
const historyStore = useHistoryStore()
const { online } = useOnlineStatus()
const { generateReport, generating: reportGenerating, error: reportError, streamContent: aiReport, reasoningContent, resetReport, renderMarkdown } = useAIReport()
const { exportReport, exporting: pdfExporting } = usePDF()

const showHeatmapValues = ref(false)
const activeTab = ref('erosion')
const pdfArea = ref(null)
const erosionDom = ref(null)
const depthDom = ref(null)
const timeDom = ref(null)
const radarDom = ref(null)
const pieDom = ref(null)
const scatterDom = ref(null)
const stackedDom = ref(null)
const heatmapDom = ref(null)

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

function destroyCharts() { charts.forEach(c => c.dispose()); charts = [] }

const chartTheme = {
  color: ['#4a9eff','#00d9a5','#ffc107','#e94560','#9c27b0','#ff9800','#03a9f4','#8bc34a'],
  backgroundColor: 'transparent',
  textStyle: { color: '#8899aa', fontSize: 11 },
  title: { textStyle: { color: '#e8e8e8', fontSize: 14 } }
}

function initChart(dom) {
  if (!dom) return null
  if (dom._echart) dom._echart.dispose()
  const c = echarts.init(dom, chartTheme, { renderer: 'svg' })
  dom._echart = c
  charts.push(c)
  return c
}

function renderErosionChart() {
  const c = initChart(erosionDom.value)
  if (!c) return
  const fert = store.inputs.fert
  const levels = [0,10,20,30,40,50,60,70]
  c.setOption({
    title: { text: '不同侵蚀强度下的SOC含量', left: 'center' },
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: levels.map(e => e+' cm'), axisLabel: { color: '#889' } },
    yAxis: { type: 'value', name: 'SOC (g/kg)', axisLabel: { color: '#889' } },
    series: [{ type: 'bar', data: levels.map(e => baseData[fert][e][0]), itemStyle: { borderRadius: [6,6,0,0] } }]
  })
}

function renderDepthChart() {
  const c = initChart(depthDom.value)
  if (!c) return
  const fert = store.inputs.fert
  const erosion = parseInt(store.inputs.erosion)
  c.setOption({
    title: { text: 'SOC含量的垂直分布特征', left: 'center' },
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: depthLabels, axisLabel: { color: '#889' } },
    yAxis: { type: 'value', name: 'SOC (g/kg)', axisLabel: { color: '#889' } },
    series: [{ type: 'line', data: baseData[fert][erosion], smooth: true, areaStyle: { opacity: 0.15 } }]
  })
}

function renderTimeChart() {
  const c = initChart(timeDom.value)
  if (!c) return
  const isF = store.inputs.fert === 'F'
  const fData = isF ? [23.9,21.5,19.2,17.8,16.6] : [23.9,22.1,20.5,19.1,17.7]
  const uData = isF ? [23.9,22.1,20.5,19.1,17.7] : [23.9,21.5,19.2,17.8,16.6]
  c.setOption({
    title: { text: 'SOC含量随时间变化趋势', left: 'center' },
    tooltip: { trigger: 'axis' },
    legend: { data: ['施肥','不施肥'], top: 30, textStyle: { color: '#889' } },
    xAxis: { type: 'category', data: ['0年','5年','10年','15年','20年'], axisLabel: { color: '#889' } },
    yAxis: { type: 'value', name: 'SOC (g/kg)', axisLabel: { color: '#889' } },
    series: [
      { name: '施肥', type: 'line', data: fData, smooth: true, areaStyle: { opacity: 0.1 } },
      { name: '不施肥', type: 'line', data: uData, smooth: true, areaStyle: { opacity: 0.1 } }
    ]
  })
}

function renderRadarChart() {
  const c = initChart(radarDom.value)
  if (!c || !store.results) return
  const r = store.results
  c.setOption({
    title: { text: '土壤碳库多维度综合评估', left: 'center' },
    radar: {
      indicator: [
        { name: 'SOC含量', max: 25 }, { name: '碳库储量', max: 10 },
        { name: '碳密度', max: 50 }, { name: '恢复速率', max: 1 }, { name: '净变化', max: 5 }
      ],
      axisName: { color: '#889' }
    },
    series: [{ type: 'radar', data: [{ value: [r.soc, r.carbonStorage, r.carbonDensity, r.recoveryRate, r.netChange] }] }]
  })
}

function renderPieChart() {
  const c = initChart(pieDom.value)
  if (!c) return
  const vals = baseData[store.inputs.fert][parseInt(store.inputs.erosion)]
  c.setOption({
    title: { text: '各土层碳库组成比例', left: 'center' },
    tooltip: { trigger: 'item', formatter: '{b}: {c} g/kg ({d}%)' },
    legend: { orient: 'vertical', right: 5, top: 40, textStyle: { color: '#889' } },
    series: [{
      type: 'pie', radius: ['45%','70%'], center: ['40%','55%'],
      data: depthLabels.map((l,i) => ({ name: l, value: vals[i] })),
      label: { color: '#889' }
    }]
  })
}

function renderScatterChart() {
  const c = initChart(scatterDom.value)
  if (!c) return
  const fert = store.inputs.fert
  const data = [0,10,20,30,40,50,60,70].map(e => [e, baseData[fert][e][0]])
  c.setOption({
    title: { text: '侵蚀强度与SOC含量关联分析', left: 'center' },
    tooltip: { trigger: 'item', formatter: p => `侵蚀: ${p.value[0]}cm<br/>SOC: ${p.value[1]} g/kg` },
    xAxis: { type: 'value', name: '侵蚀强度(cm)', axisLabel: { color: '#889' }, nameTextStyle: { color: '#889' } },
    yAxis: { type: 'value', name: 'SOC(g/kg)', axisLabel: { color: '#889' }, nameTextStyle: { color: '#889' } },
    series: [{ type: 'scatter', data, symbolSize: 14 }]
  })
}

function renderStackedChart() {
  const c = initChart(stackedDom.value)
  if (!c) return
  const fert = store.inputs.fert
  const erosion = parseInt(store.inputs.erosion)
  c.setOption({
    title: { text: '当前侵蚀 vs 无侵蚀 SOC分布对比', left: 'center' },
    tooltip: { trigger: 'axis' },
    legend: { data: [`侵蚀${erosion}cm`,'无侵蚀'], top: 30, textStyle: { color: '#889' } },
    xAxis: { type: 'category', data: depthLabels.map((_,i) => `${(i*10)}-${(i+1)*10+10}cm`), axisLabel: { color: '#889' } },
    yAxis: { type: 'value', name: 'SOC(g/kg)', axisLabel: { color: '#889' } },
    series: [
      { name: `侵蚀${erosion}cm`, type: 'line', data: baseData[fert][erosion], areaStyle: { opacity: 0.3 } },
      { name: '无侵蚀', type: 'line', data: baseData[fert][0], areaStyle: { opacity: 0.1 }, lineStyle: { type: 'dashed' } }
    ]
  })
}

function renderHeatmapChart() {
  const c = initChart(heatmapDom.value)
  if (!c) return
  const fert = store.inputs.fert
  const data = []
  for (let e = 0; e <= 70; e += 10)
    for (let d = 0; d < 5; d++)
      data.push([e, d, baseData[fert][e][d] || 0])
  const showVal = showHeatmapValues.value
  c.setOption({
    title: { text: '侵蚀强度x土层深度 SOC分布热力图', left: 'center' },
    tooltip: { formatter: p => `侵蚀${p.value[0]}cm · ${depthLabels[p.value[1]]}: ${p.value[2]} g/kg` },
    visualMap: { min: 4, max: 24, calculable: true, orient: 'horizontal', left: 'center', bottom: 0, textStyle: { color: '#889' } },
    xAxis: { type: 'category', data: [0,10,20,30,40,50,60,70].map(e=>e+'cm'), axisLabel: { color: '#889' } },
    yAxis: { type: 'category', data: depthLabels, axisLabel: { color: '#889' } },
    series: [{
      type: 'heatmap', data,
      label: { show: showVal, color: '#fff', fontSize: 9, formatter: p => String(p.value?.[2] ?? '') + 'g/kg' },
      emphasis: { itemStyle: { shadowBlur: 10, shadowColor: 'rgba(0,0,0,0.5)' } }
    }]
  })
}

function toggleHeatmapValues() {
  showHeatmapValues.value = !showHeatmapValues.value
  heatmapDom.value?._echart?.setOption({ series: [{ label: { show: showHeatmapValues.value } }] })
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
    if (pdfExporting.value || !store.results) return
    try {
      await exportReport({
        fert: store.inputs.fert === 'F' ? '施肥' : (store.inputs.fert === 'UNF' ? '不施肥' : String(store.inputs.fert)),
        erosion: String(store.inputs.erosion || '0'),
        bd: String(store.inputs.bd || '-'),
        ph: String(store.inputs.ph || '-'),
        wc: String(store.inputs.wc || '-'),
        clay: String(store.inputs.clay || '-'),
        tn: String(store.inputs.tn || '-'),
        cropBiomass: String(store.inputs.cropBiomass || '-'),
        strawCarbon: String(store.inputs.strawCarbonRatio || '-'),
        results: store.results,
        resilience: store.resilience,
        aiReport: aiReport.value,
        charts
      })
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
