<template>
  <div class="section-card">
    <div class="section-header">
      <div class="section-icon">⚙️</div>
      <div class="section-title">系统设置</div>
    </div>

    <div class="card-grid">
      <div class="settings-card">
        <h4>🤖 AI 报告接口配置</h4>
        <p class="settings-desc">可选。配置 OpenAI 格式的 API 后，可在计算结果页生成评估报告。</p>
        <div class="form-group" style="margin-top: 1rem;">
          <label class="form-label">API Endpoint URL</label>
          <input type="url" v-model="form.apiUrl" class="form-input" placeholder="https://api.openai.com/v1/chat/completions" />
        </div>
        <div class="form-group" style="margin-top: 1rem;">
          <label class="form-label">API Key</label>
          <input type="password" v-model="form.apiKey" class="form-input" placeholder="sk-..." />
        </div>
        <div class="form-group" style="margin-top: 1rem;">
          <label class="form-label">模型名称</label>
          <input type="text" v-model="form.model" class="form-input" placeholder="deepseek-v4-flash / gpt-3.5-turbo / ..." />
        </div>
        <div class="form-group" style="margin-top: 1rem;">
          <label class="form-label" style="display:flex;align-items:center;gap:0.5rem;">
            <input type="checkbox" v-model="form.enableThinking" />
            DeepSeek 思考模式（reasoning_content）
          </label>
        </div>
        <div class="btn-group" style="margin-top: 1rem;">
          <button class="btn btn-primary" @click="saveAISettings" :disabled="saving">
            {{ saving ? '⏳ 保存中...' : '💾 保存' }}
          </button>
          <button class="btn btn-secondary" @click="testConnection" :disabled="testing || !form.apiUrl || !form.apiKey">
            {{ testing ? '⏳ 测试中...' : '🔗 测试连接' }}
          </button>
        </div>
        <div v-if="testResult" class="test-result" :class="testSuccess ? 'success' : 'error'">
          {{ testResult }}
        </div>
      </div>

      <div class="settings-card">
        <h4>📝 AI 报告提示词</h4>
        <p class="settings-desc">自定义生成报告的提示词。使用 <code>{{变量名}}</code> 引用计算数据。</p>
        <div class="form-group" style="margin-top: 1rem;">
          <textarea v-model="form.prompt" class="form-input prompt-editor" rows="10" placeholder="输入自定义提示词..."></textarea>
        </div>
        <div class="btn-group" style="margin-top: 0.5rem;">
          <button class="btn btn-sm btn-secondary" @click="form.prompt = DEFAULT_PROMPT">↩️ 重置为默认</button>
        </div>
      </div>

      <div class="settings-card">
        <h4>📦 数据管理</h4>
        <p class="settings-desc">导入/导出所有历史评估记录，防止数据丢失。</p>
        <div class="btn-group" style="margin-top: 1rem;">
          <button class="btn btn-secondary" @click="handleExport">📤 导出所有数据 (JSON)</button>
          <label class="btn btn-secondary" style="cursor: pointer;">
            📥 导入数据
            <input type="file" accept=".json" hidden @change="handleImport" />
          </label>
        </div>
        <p style="margin-top: 1rem; font-size: 0.75rem; color: var(--text-muted);">
          建议定期导出备份。浏览器存储可能被清理。
        </p>
      </div>

      <div class="settings-card">
        <h4>ℹ️ 关于</h4>
        <p class="settings-desc">东北黑土区农田土壤有机碳评估系统</p>
        <ul class="info-list">
          <li><span>版本</span><span>{{ appVersion }}</span></li>
          <li><span>研究区域</span><span>黑龙江省嫩江市鹤山农场</span></li>
          <li><span>数据来源</span><span>长期定位试验观测数据</span></li>
          <li><span>网络状态</span><span :style="{ color: online ? 'var(--success)' : 'var(--danger)' }">{{ online ? '在线' : '离线' }}</span></li>
          <li><span>记录总数</span><span>{{ recordCount }}</span></li>
        </ul>
        <a href="https://github.com/Fuck-GH-Admin/SOC-Assessment" target="_blank" rel="noopener" class="github-link">
          <svg class="github-icon" viewBox="0 0 16 16" width="16" height="16"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8"/></svg>
          SOC-Assessment
        </a>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useOnlineStatus } from '@/composables/useOnlineStatus.js'
import { useHistoryStore } from '@/stores/history.js'
import db from '@/db/index.js'
import { DEFAULT_PROMPT } from '@/composables/useAIReport.js'
import { version } from '../../package.json'

const { online } = useOnlineStatus()
const historyStore = useHistoryStore()
const prompt = DEFAULT_PROMPT
const appVersion = version

const form = ref({ apiUrl: '', apiKey: '', model: 'deepseek-v4-flash', enableThinking: false, reasoningEffort: 'high', prompt: prompt })
const saving = ref(false)
const testing = ref(false)
const testResult = ref('')
const testSuccess = ref(false)
const recordCount = ref(0)

async function saveAISettings() {
  saving.value = true
  try {
    await db.settings.put({ key: 'ai', apiUrl: form.value.apiUrl, apiKey: form.value.apiKey, model: form.value.model, enableThinking: form.value.enableThinking, reasoningEffort: form.value.reasoningEffort, prompt: form.value.prompt })
    testResult.value = '✅ 设置已保存'
    testSuccess.value = true
    setTimeout(() => testResult.value = '', 2000)
  } catch (e) {
    testResult.value = '❌ 保存失败: ' + e.message
    testSuccess.value = false
  }
  saving.value = false
}

async function testConnection() {
  testing.value = true
  testResult.value = ''
  try {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 10000)
    let resp
    try {
      resp = await fetch(form.value.apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${form.value.apiKey}`
        },
        body: JSON.stringify({
          model: form.value.model || 'gpt-3.5-turbo',
          messages: [{ role: 'user', content: 'Say "ok" only' }],
          max_tokens: 5
        }),
        signal: controller.signal
      })
    } finally {
      clearTimeout(timeout)
    }
    if (resp.ok) { testResult.value = '✅ 连接成功'; testSuccess.value = true }
    else { testResult.value = `❌ 连接失败: ${resp.status}`; testSuccess.value = false }
  } catch (e) {
    testResult.value = '❌ 连接失败: ' + (e.name === 'AbortError' ? '请求超时' : e.message)
    testSuccess.value = false
  }
  testing.value = false
}

async function handleExport() { await historyStore.exportData() }

async function handleImport(e) {
  const file = e.target.files[0]
  if (!file) return
  try {
    await historyStore.importData(file)
    recordCount.value = historyStore.records.length
    alert('✅ 导入成功')
    e.target.value = ''
  } catch (err) { alert('❌ 导入失败: ' + err.message) }
}

onMounted(async () => {
  try {
    await historyStore.loadRecords()
    recordCount.value = historyStore.records.length
  } catch (e) {
    console.error('加载历史记录失败:', e)
  }
  try {
    const settings = await db.settings.get('ai')
    if (settings) {
      form.value.apiUrl = settings.apiUrl || ''
      form.value.apiKey = settings.apiKey || ''
      form.value.model = settings.model || 'deepseek-v4-flash'
      form.value.enableThinking = settings.enableThinking ?? false
      form.value.reasoningEffort = settings.reasoningEffort || 'high'
      form.value.prompt = settings.prompt || DEFAULT_PROMPT
    }
  } catch (e) {
    console.error('加载AI设置失败:', e)
  }
})
</script>

<style scoped>
.settings-card {
  background: var(--primary); border: 1px solid var(--border);
  border-radius: 12px; padding: 1.5rem;
}
.settings-card h4 { font-size: 1rem; color: var(--accent); margin-bottom: 0.5rem; }
.settings-desc { font-size: 0.8rem; color: var(--text-muted); line-height: 1.5; }
.test-result {
  margin-top: 0.75rem; padding: 0.5rem 0.75rem; border-radius: 8px;
  font-size: 0.85rem;
}
.test-result.success { background: rgba(0, 217, 165, 0.1); color: var(--success); border: 1px solid var(--success); }
.test-result.error { background: rgba(233, 69, 96, 0.1); color: var(--danger); border: 1px solid var(--danger); }
.info-list { list-style: none; font-size: 0.85rem; margin-top: 0.75rem; }
.info-list li {
  padding: 0.5rem 0; border-bottom: 1px solid var(--border);
  display: flex; justify-content: space-between;
}
.info-list li:last-child { border-bottom: none; }
.prompt-editor {
  width: 100%; min-height: 200px; resize: vertical;
  font-family: 'Courier New', monospace; font-size: 0.8rem; line-height: 1.6;
}
.github-link {
  display: inline-flex; align-items: center; gap: 0.4rem;
  color: var(--text-muted); text-decoration: none; font-size: 0.8rem; margin-top: 0.75rem;
  transition: color 0.2s;
}
.github-link:hover { color: var(--accent); }
.github-icon { opacity: 0.7; }
</style>
