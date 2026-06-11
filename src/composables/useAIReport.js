import { ref } from 'vue'
import { marked } from 'marked'

const generating = ref(false)
const error = ref(null)
const streamContent = ref('')
const reasoningContent = ref('')

export const DEFAULT_PROMPT = `你是一位土壤学专家。请根据以下土壤有机碳(SOC)评估数据，生成一份专业的中文土壤碳库恢复力评估报告：

计算参数：
- 施肥处理：{{fert}}
- 侵蚀强度：{{erosion}} cm
- 土壤容重：{{bd}} g/cm³

计算结果：
- SOC含量：{{soc}} g/kg
- 碳库储量：{{carbonStorage}} kg C/m²
- 碳密度：{{carbonDensity}} kg C/m³
- 碳库净变化量：{{netChange}} kg C/m²
- 年恢复速率：{{recoveryRate}} kg C/m²/年
- SOC损失率：{{lossRate}}%

请包含以下内容：
1. 数据解读 — 当前碳库状况
2. 侵蚀影响评估
3. 未来种植建议
4. 土壤恢复力综合评价`

const FERT_MAP = { F: '施肥', M: '施肥', U: '不施肥' }

function fillPrompt(template, data) {
  return template
    .replace('{{fert}}', FERT_MAP[data.fert] || data.fert || '')
    .replace('{{erosion}}', data.erosion ?? '')
    .replace('{{bd}}', data.bd ?? '')
    .replace('{{soc}}', data.results?.soc ?? '')
    .replace('{{carbonStorage}}', data.results?.carbonStorage ?? '')
    .replace('{{carbonDensity}}', data.results?.carbonDensity ?? '')
    .replace('{{netChange}}', data.results?.netChange ?? '')
    .replace('{{recoveryRate}}', data.results?.recoveryRate ?? '')
    .replace('{{lossRate}}', data.results?.lossRate ?? '')
}

function renderMarkdown(text) {
  if (!text) return ''
  return marked.parse(text, { breaks: true, gfm: true })
}

export function useAIReport() {

  async function generateReport(apiUrl, apiKey, model, data, customPrompt, opts = {}) {
    generating.value = true
    error.value = null
    streamContent.value = ''
    reasoningContent.value = ''

    const prompt = fillPrompt(customPrompt || DEFAULT_PROMPT, data)
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 30000)

    try {
      const body = {
        model: model || 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: prompt }],
        stream: true
      }
      if (opts.enableThinking) {
        body.thinking = { type: 'enabled' }
      } else {
        body.temperature = 0.7
        body.max_tokens = 2000
      }
      if (opts.reasoningEffort && opts.enableThinking) {
        body.reasoning_effort = opts.reasoningEffort
      }

      const resp = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify(body),
        signal: controller.signal
      })
      clearTimeout(timeout)

      if (!resp.ok) throw new Error(`API请求失败: ${resp.status}`)

      const reader = resp.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ''

      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        buffer += decoder.decode(value, { stream: true })
        const lines = buffer.split('\n')
        buffer = lines.pop() || ''
        for (const line of lines) {
          if (line.startsWith('data: ') && line !== 'data: [DONE]') {
            try {
              const chunk = JSON.parse(line.slice(6))
              const c = chunk.choices?.[0]?.delta?.content || ''
              const rc = chunk.choices?.[0]?.delta?.reasoning_content || ''
              if (c) streamContent.value += c
              if (rc) reasoningContent.value += rc
            } catch {}
          }
        }
      }
      generating.value = false
      return streamContent.value || '（未生成内容）'
    } catch (e) {
      clearTimeout(timeout)
      if (e.name === 'AbortError') {
        error.value = '请求超时，请检查网络或API地址'
      } else if (e.name === 'TypeError' && e.message.includes('fetch')) {
        error.value = '网络连接失败，请检查网络或API地址'
      } else {
        error.value = e.message
      }
      generating.value = false
      return streamContent.value || null
    }
  }

  function resetReport() {
    streamContent.value = ''
    reasoningContent.value = ''
    error.value = null
    generating.value = false
  }

  return { generateReport, generating, error, streamContent, reasoningContent, resetReport, renderMarkdown }
}
