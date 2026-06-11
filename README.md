# SOC Assessment — 东北黑土区农田土壤有机碳评估系统

## 简介

基于黑龙江省鹤山农场长期定位试验数据，对农田土壤有机碳（SOC）进行模拟计算与恢复力评估。

## 功能

- **参数计算** — 输入土壤理化参数，自动计算 SOC 含量、碳库储量、碳密度、恢复速率等指标
- **数据可视化** — 8 种图表（侵蚀影响、深度分布、时间变化、综合评估、碳库组成、参数关联、碳库对比、热力图）
- **土壤恢复力评估** — 基于论文方法的碳库变化与恢复状态评估
- **AI 报告生成** — 接入 DeepSeek 等 OpenAI-compatible API，流式生成评估报告（支持思考模式）
- **历史记录** — 保存/查看/搜索/对比历史计算记录
- **PDF 导出** — 导出含完整数据表格和图表的评估报告
- **数据导入导出** — JSON 格式批量导入导出历史数据

## 快速开始

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
npm run dev
```

浏览器打开 `http://localhost:5173`

### 构建

```bash
# Web
npm run build

# Windows EXE
npm run build:win

# Android APK (需 Android SDK)
npx cap sync android
cd android && ./gradlew assembleDebug
```

### 测试

```bash
npm test
```

## 使用说明

### 1. 参数计算

在首页输入土壤参数：施肥处理、侵蚀强度、土层深度、土壤容重、pH 值、含水量、黏+粉粒含量、全氮含量、秸秆生物量、秸秆碳含量。点击「执行计算」查看结果。

### 2. 数据可视化

计算结果下方提供 8 个图表面板的切换查看，包括柱状图、折线图、雷达图、饼图、散点图、热力图等。

### 3. AI 报告

在「设置」页面配置 DeepSeek API（或其他 OpenAI 兼容接口），返回首页计算后点击「生成评估报告」即可获得流式 AI 分析。支持自定义提示词模板和思考模式（reasoning）。

### 4. 导出 PDF

点击结果区域的「PDF」按钮，自动生成含输入参数、计算结果、恢复力评估、数据图表和 AI 报告的完整 PDF。

### 5. 历史管理

在「历史」页面查看、搜索、删除历史记录，支持 JSON 导入导出。

### 6. 多记录对比

在「对比」页面选择 2 条以上记录进行指标对比。

## 技术栈

Vue 3 + Vite + Pinia + Dexie.js + Chart.js + jsPDF + Electron + Capacitor

## 许可证

MIT License
