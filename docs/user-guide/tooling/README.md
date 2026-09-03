# 说明书渲染工具

本目录提供说明书的 Markdown 到 HTML 渲染脚本。PDF 使用已安装的 Google Chrome 无头模式从 HTML 打印生成。

## 依赖

- Node.js 22 或兼容版本。
- `markdown-it` 14.1.0，记录在本目录的 `package-lock.json` 中。
- Google Chrome 或兼容 Chromium 浏览器。
- Ghostwriter 用于人工编辑和实时预览，不参与命令行构建。

## 安装依赖

在仓库根目录执行：

```bash
npm install --prefix docs/user-guide/tooling --ignore-scripts
```

## 生成 HTML

```bash
node docs/user-guide/tooling/render.mjs
```

默认输出到：

```text
release/user-guide/index.html
```

也可以指定输出目录：

```bash
node docs/user-guide/tooling/render.mjs --output /path/to/output
```

脚本会读取 `metadata.json`，合并封面、快速入门、完整用户指南、科学附录、常见问题、术语表和更新记录，并复制说明书资源、生成目录和内部锚点。当前正文采用文字优先策略，不依赖界面截图。

生成前会自动比较 `metadata.json`、`soc_app/pubspec.yaml` 和设置页版本。三者或说明书版本不一致时，脚本会失败，避免发布出版本错配的说明书。

## 生成 PDF

Linux 环境的验证命令如下：

```bash
mkdir -p /tmp/soc-guide-chrome
google-chrome \
  --headless=new \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --user-data-dir=/tmp/soc-guide-chrome \
  --no-pdf-header-footer \
  --print-to-pdf=/absolute/path/to/release/user-guide/index.pdf \
  file:///absolute/path/to/release/user-guide/index.html
```

PDF 使用 CSS 指定 A4 页面。正式发布前必须检查中文字体、目录、图片、表格、分页和链接。

## 当前验证结果

- HTML：生成成功，目录和内部锚点正常，无界面截图依赖。
- PDF：生成成功，A4，页数随正文内容变化，无浏览器页眉页脚。
- 文本提取：中文标题和正文可正常提取。
- 产物位置：`release/user-guide/`，该目录属于本地发布产物，不提交到源码。
