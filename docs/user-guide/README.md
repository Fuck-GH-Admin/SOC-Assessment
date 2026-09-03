# 碳盾 SOC-Shield 用户说明书

这是碳盾 SOC-Shield 的用户说明书源码目录。

当前发布版本：`1.1.5`。说明书版本与应用语义版本保持一致；应用的 Android/Windows build number 单独记录在封面元数据中。

## 文档组成

- [快速入门](quick-start.md)：用一条完整流程帮助用户完成第一次评估。
- [完整用户指南](user-guide.md)：覆盖页面、参数、结果、报告、历史和故障处理。
- [科学口径与附录](scientific-basis.md)：说明数据来源、公式、单位、版本和限制。
- [常见问题](faq.md)：整理用户操作和结果解释中的高频问题。
- [术语表](glossary.md)：统一 SOC、CK、碳库等专业词汇。
- [更新记录](changelog.md)：记录说明书与应用版本之间的变化。
- [封面与版本元数据](cover.md)：发布封面和当前版本信息。
- [资源说明](assets/README.md)：截图、插图和示例数据的命名及脱敏规则。

## 维护原则

Markdown 是唯一维护源。HTML 和 PDF 是由源码渲染得到的发布产物，不在本目录中单独维护一份正文。

编写和发布要求见 [用户说明书编写要求](../project/user-manual-requirements.md)。

## 当前文档状态

- 目录和内容边界：已建立。
- 快速入门正文：已完成。
- 完整用户指南正文：已完成当前版本功能说明。
- 科学附录：已完成当前算法口径和限制说明。
- HTML/PDF 渲染工具链：已确定并完成基础验证。

## 推荐渲染流程

```text
Ghostwriter 编写/预览 Markdown
  -> 固定渲染器生成 HTML
  -> 固定渲染器生成 PDF
  -> 应用内帮助页面或静态资源
```

生成文件不应包含真实 API Key、个人路径或未脱敏的历史记录。

## 当前工具状态

- Ghostwriter：已安装，用于 Markdown 编写和人工预览。
- Markdown 到 HTML：`docs/user-guide/tooling/render.mjs`，使用 `markdown-it` `14.1.0`。
- HTML 到 PDF：已用 Google Chrome `151.0.7922.137` 无头模式验证。
- 最终发布前：仍需用固定工具链复核中文字体、目录、图片、公式和分页。

工具安装、命令和验证结果见 [渲染工具说明](tooling/README.md)。
