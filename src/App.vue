<template>
  <div class="app-shell">
    <header class="header-banner">
      <div class="header-content">
        <div class="logo-section">
          <div class="logo-icon">🌾</div>
          <div class="logo-text">
            <h1>东北黑土区农田土壤有机碳评估系统</h1>
          </div>
        </div>
        <nav class="nav-links">
          <router-link to="/" class="nav-link" :class="{ active: $route.path === '/' }">
            <span>🏠</span> 计算
          </router-link>
          <router-link to="/history" class="nav-link" :class="{ active: $route.path === '/history' }">
            <span>📋</span> 历史
          </router-link>
          <router-link to="/compare" class="nav-link" :class="{ active: $route.path === '/compare' }">
            <span>📊</span> 对比
          </router-link>
          <router-link to="/settings" class="nav-link" :class="{ active: $route.path === '/settings' }">
            <span>⚙️</span> 设置
          </router-link>
        </nav>
      </div>
    </header>
    <main class="main-container">
      <router-view />
    </main>
    <footer class="app-footer">
      <a href="https://github.com/Fuck-GH-Admin/SOC-Assessment" target="_blank" rel="noopener" class="github-link">
        <svg class="github-icon" viewBox="0 0 16 16" width="16" height="16"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8"/></svg>
        SOC-Assessment
      </a>
      <span class="app-version">v{{ version }}</span>
    </footer>
  </div>
</template>

<script setup>
import { version } from '../package.json'
</script>

<style scoped>
.app-shell { min-height: 100vh; }
.header-banner {
  background: linear-gradient(135deg, #1a2a4a 0%, #0d1b2a 100%);
  border-bottom: 1px solid #2d4a6a;
  padding: 0.75rem 2rem;
  position: sticky; top: 0; z-index: 100;
  backdrop-filter: blur(10px);
}
.header-content {
  max-width: 1400px; margin: 0 auto;
  display: flex; align-items: center; justify-content: space-between;
}
.logo-section { display: flex; align-items: center; gap: 1rem; }
.logo-icon {
  width: 42px; height: 42px;
  background: linear-gradient(135deg, #00c853 0%, #00a040 100%);
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.2rem;
  box-shadow: 0 4px 12px rgba(0, 200, 83, 0.3);
}
.logo-text h1 { font-size: 1.1rem; font-weight: 700; color: #00d9a5; }
.nav-links { display: flex; gap: 0.5rem; }
.nav-link {
  padding: 0.5rem 1rem;
  border-radius: 8px;
  color: #8899aa;
  text-decoration: none;
  font-size: 0.85rem;
  display: flex; align-items: center; gap: 0.35rem;
  transition: all 0.2s;
}
.nav-link:hover { background: rgba(74, 158, 255, 0.1); color: #e8e8e8; }
.nav-link.active {
  background: linear-gradient(135deg, #4a9eff 0%, #00d9a5 100%);
  color: white;
}
.main-container { max-width: 1400px; margin: 0 auto; padding: 1.5rem 2rem; }
.app-footer {
  text-align: center; padding: 1.5rem 2rem 2rem;
  border-top: 1px solid var(--border); margin-top: 2rem;
  display: flex; align-items: center; justify-content: center; gap: 1.5rem;
}
.github-link {
  display: inline-flex; align-items: center; gap: 0.4rem;
  color: var(--text-muted); text-decoration: none; font-size: 0.8rem;
  transition: color 0.2s;
}
.github-link:hover { color: var(--accent); }
.github-icon { opacity: 0.7; }
.app-version { color: var(--text-muted); font-size: 0.75rem; }

@media (max-width: 768px) {
  .header-content { flex-direction: column; gap: 0.75rem; }
  .nav-links { width: 100%; justify-content: center; }
  .nav-link { font-size: 0.75rem; padding: 0.4rem 0.6rem; }
  .logo-text h1 { font-size: 0.95rem; }
  .main-container { padding: 1rem; }
  .app-footer { flex-direction: column; gap: 0.5rem; }
}
</style>
