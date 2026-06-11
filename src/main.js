import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import db from '@/db/index.js'
import { DEFAULT_PROMPT } from '@/composables/useAIReport.js'
import './assets/styles/main.css'

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')

// Seed default config on first launch (no API key pre-filled)
db.settings.get('ai').then(s => {
  if (!s?.apiUrl) {
    db.settings.put({
      key: 'ai',
      apiUrl: 'https://api.deepseek.com/chat/completions',
      apiKey: '',
      model: 'deepseek-v4-flash',
      enableThinking: false,
      reasoningEffort: 'high',
      prompt: DEFAULT_PROMPT
    }).catch(() => {})
  }
}).catch(() => {})
