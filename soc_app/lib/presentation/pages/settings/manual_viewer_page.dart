import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 内置用户说明书查看器：加载 assets/manual/ 下的 Markdown 文件，
/// 在当前主题下渲染。说明书 Markdown 是唯一维护源，
/// 构建时从 docs/user-guide 同步进 assets（tooling/sync-manual.sh）。
class ManualViewerPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const ManualViewerPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<ManualViewerPage> createState() => _ManualViewerPageState();
}

class _ManualViewerPageState extends State<ManualViewerPage> {
  late Future<String> _content;

  @override
  void initState() {
    super.initState();
    _content = DefaultAssetBundle.of(context).loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<String>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '说明书加载失败：${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SelectionArea(
            child: Markdown(
              data: snapshot.data ?? '',
              selectable: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              styleSheet: _manualStyle(theme),
            ),
          );
        },
      ),
    );
  }

  MarkdownStyleSheet _manualStyle(ThemeData theme) {
    final cs = theme.colorScheme;
    return MarkdownStyleSheet(
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.primary,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
      listBullet: theme.textTheme.bodyMedium,
      tableHead: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      tableBody: theme.textTheme.bodyMedium,
      tableBorder: TableBorder.all(
        color: theme.dividerColor,
        width: 0.5,
      ),
      tableHeadAlign: TextAlign.center,
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: cs.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
    );
  }
}
