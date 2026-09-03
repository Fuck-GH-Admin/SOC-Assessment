import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import MarkdownIt from 'markdown-it';

const toolingDir = path.dirname(fileURLToPath(import.meta.url));
const guideDir = path.resolve(toolingDir, '..');
const defaultOutputDir = path.resolve(guideDir, '..', '..', 'release', 'user-guide');
const metadata = JSON.parse(await fs.readFile(path.join(guideDir, 'metadata.json'), 'utf8'));
const repoDir = path.resolve(guideDir, '..', '..');

const pubspec = await fs.readFile(path.join(repoDir, 'soc_app', 'pubspec.yaml'), 'utf8');
const pubspecVersion = /^version:\s*([^+\s]+)(?:\+([^\s]+))?/m.exec(pubspec);
const settingsSource = await fs.readFile(
  path.join(repoDir, 'soc_app', 'lib', 'presentation', 'pages', 'settings', 'settings_page.dart'),
  'utf8',
);
const settingsVersion = /_kVersion\s*=\s*'([^']+) \(build ([^')]+)\)'/.exec(settingsSource);
if (!pubspecVersion || !settingsVersion) {
  throw new Error('无法读取应用版本信息，请检查 pubspec.yaml 和 settings_page.dart');
}
if (
  metadata.applicationVersion !== metadata.manualVersion ||
  metadata.applicationVersion !== pubspecVersion[1] ||
  metadata.applicationBuild !== (pubspecVersion[2] ?? '') ||
  metadata.applicationVersion !== settingsVersion[1] ||
  metadata.applicationBuild !== settingsVersion[2]
) {
  throw new Error(
    `版本不同步：metadata=${metadata.applicationVersion}+${metadata.applicationBuild}, ` +
    `pubspec=${pubspecVersion[1]}+${pubspecVersion[2] ?? ''}, ` +
    `settings=${settingsVersion[1]}+${settingsVersion[2]}`,
  );
}

const sourceFiles = [
  'cover.md',
  'quick-start.md',
  'user-guide.md',
  'scientific-basis.md',
  'faq.md',
  'glossary.md',
  'changelog.md',
];

const metadataReplacements = {
  '{{applicationVersion}}': metadata.applicationVersion,
  '{{applicationBuild}}': metadata.applicationBuild,
  '{{manualVersion}}': metadata.manualVersion,
  '{{algorithmVersion}}': metadata.algorithmVersion,
  '{{databaseVersion}}': metadata.databaseVersion,
  '{{lastUpdated}}': metadata.lastUpdated,
};

const applyMetadata = (source) => Object.entries(metadataReplacements)
  .reduce((text, [placeholder, value]) => text.replaceAll(placeholder, value), source);

const htmlShell = ({body, title}) => `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>
  <link rel="stylesheet" href="guide.css">
</head>
<body>
  <main class="document">${body}</main>
</body>
</html>
`;

const outputArgIndex = process.argv.indexOf('--output');
const outputDir = outputArgIndex >= 0 && process.argv[outputArgIndex + 1]
  ? path.resolve(process.argv[outputArgIndex + 1])
  : defaultOutputDir;

const markdown = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: false,
});

const escapeHtml = (value) => value
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;');

const slugify = (value, fallback) => {
  const slug = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/[\s-]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug || fallback;
};

const sections = [];
let coverHtml = '';
const tocItems = [];
const slugCounts = new Map();
for (const fileName of sourceFiles) {
  const source = applyMetadata(await fs.readFile(path.join(guideDir, fileName), 'utf8'));
  const tokens = markdown.parse(source, {});
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (fileName === 'cover.md') continue;
    if (token.type !== 'heading_open') continue;
    const inline = tokens[i + 1];
    const label = inline?.content ?? '';
    const baseSlug = slugify(label, `section-${String(tocItems.length + 1).padStart(3, '0')}`);
    const count = slugCounts.get(baseSlug) ?? 0;
    slugCounts.set(baseSlug, count + 1);
    const id = count === 0 ? baseSlug : `${baseSlug}-${count + 1}`;
    token.attrSet('id', id);
    const level = Number(token.tag.slice(1));
    if (level <= 3) {
      tocItems.push({id, label, level});
    }
  }
  const rendered = markdown.renderer.render(tokens, markdown.options, {});
  if (fileName === 'cover.md') {
    coverHtml = `<section class="cover">${rendered}</section>`;
  } else {
    sections.push(rendered);
  }
}

const toc = `<nav class="toc" aria-label="章节目录">
  <h2>目录</h2>
  <ul>${tocItems.map(({id, label, level}) =>
    `<li class="toc-level-${level}"><a href="#${id}">${escapeHtml(label)}</a></li>`
  ).join('')}</ul>
</nav>`;

await fs.mkdir(outputDir, {recursive: true});
await fs.cp(path.join(guideDir, 'assets'), path.join(outputDir, 'assets'), {recursive: true});
await fs.copyFile(path.join(guideDir, 'styles', 'guide.css'), path.join(outputDir, 'guide.css'));

const html = htmlShell({
  title: '碳盾 SOC-Shield 用户说明书',
  body: coverHtml + '<div class="cover-break"></div>' + toc + sections.join('\n<hr class="section-break">\n'),
});

await fs.writeFile(path.join(outputDir, 'index.html'), html);
console.log(`Rendered ${sourceFiles.length} Markdown files to ${path.join(outputDir, 'index.html')}`);
