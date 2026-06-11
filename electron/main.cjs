const { app, BrowserWindow } = require('electron')
const path = require('path')

function createWindow() {
  const win = new BrowserWindow({
    width: 450,
    height: 800,
    minWidth: 300,
    minHeight: 533,
    resizable: true,
    title: 'SOC Assessment',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  })
  win.setMenuBarVisibility(false)
  win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'))
}

app.whenReady().then(createWindow)

app.on('window-all-closed', () => {
  app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow()
  }
})
