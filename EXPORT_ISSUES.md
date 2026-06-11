# 导出功能分析与问题文档

## 背景

Android APK 版的 PDF 导出和 JSON 导出两个功能反复修改后仍然无法工作。

## 已尝试的方案及失败原因

### 方案1：anchor download（`<a download>`）
```js
const a = document.createElement('a')
a.href = blobUrl
a.download = filename
a.click()
```
**失败原因**：Android WebView（Capacitor 使用 Android 系统 WebView）不支持 `<a>` 标签的 `download` 属性。这是 Chromium WebView 的已知限制 — 点击 download anchor 在 WebView 中无任何反应，文件不会下载到任何位置，也没有错误抛出。此方案在桌面 Electron 中正常工作。

### 方案2：navigator.share（Web Share API）
```js
const file = new File([blob], filename, { type: mimeType })
await navigator.share({ files: [file] })
```
**失败原因**：Web Share API Level 2（支持 `files` 参数）需要 Chrome 76+ 的 WebView。部分 Android 设备的系统 WebView 版本较旧或实现不完整。在此设备的 Capacitor WebView 中，`navigator.share` 存在，但 `navigator.share({ files: [...] })` 抛出异常或静默失败。此方案在普通 Chrome 浏览器中正常工作（如 PWA 模式）。

### 方案3：Capacitor Filesystem + Share
```js
const { Filesystem, Directory } = await import('@capacitor/filesystem')
await Filesystem.writeFile({ path: filename, data: base64, directory: Directory.Documents })
const { Share } = await import('@capacitor/share')
await Share.share({ files: [uri] })
```
**失败原因**：
1. `Filesystem.writeFile` 报 "An Unknown error occurred" — 可能原因：`Directory.Documents` 目录在 APP 私有空间不存在且未设置 `recursive: true`；或 Android 10+ 的 scoped storage 权限限制
2. 即使写入成功，`Share.share` 的 `files` 参数在 Capacitor Share v8 中**不存在** — 该插件只支持 `{ title, text, url, dialogTitle }`，不支持分享二进制文件

### 方案4：navigator.share 兜底 + anchor fallback（当前方案）
```js
// Android: try navigator.share first, fallback to anchor download
// Desktop: anchor download only
```
**当前状态**：仍然失败。Android 上 `navigator.share` 过程无可见反应，anchor fallback 也不触发。

## 核心问题

1. **Android WebView 缺少原生的"保存文件"对话框机制** — 桌面浏览器有"另存为"对话框，移动端 Chrome 有下载管理器，但 WebView 什么都不提供
2. **Web Share API 不完全兼容** — `files` 参数在各 WebView 版本中表现不一致
3. **Capacitor Filesystem/Share 插件 API 有限** — Filesystem 可写但不能直接触发"另存为"；Share 不能分享文件

## 可行的解决方案方向

- **方向A**：使用 Capacitor 的 `@capacitor/browser` 插件，用 `Browser.open({ url: blobUrl })` 在系统浏览器中打开文件，系统浏览器会自动触发下载管理器的"另存为"对话框
- **方向B**：使用 Cordova 的 `cordova-plugin-file` + `cordova-plugin-file-opener2`（Capacitor 兼容 Cordova 插件）直接写入共享目录并调用系统文件管理器
- **方向C**：在 Capacitor Android 项目里写一个自定义插件，调用原生 Android `DownloadManager` 或 `Intent.ACTION_CREATE_DOCUMENT` 来保存文件
- **方向D**：将导出功能做成"复制到剪贴板 + 提示用户粘贴到备忘录/微信"的降级方案
- **方向E**：生成文件后，用 `window.open(blobUrl, '_system')` 的 Capacitor 特殊协议（如果存在）
