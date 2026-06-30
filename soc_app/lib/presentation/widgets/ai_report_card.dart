import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/presentation/providers/ai_report_provider.dart';

class AiReportCard extends ConsumerWidget {
  const AiReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiReportProvider);
    final theme = Theme.of(context);

    if (!state.isGenerating &&
        state.streamContent.isEmpty &&
        state.error == null) {
      return const SizedBox.shrink();
    }

    // 不再使用外层 Card：home_page 已提供 Card 容器与标题，这里只负责内容。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 生成中指示器（标题由外层 Card 提供，这里只放进度小图标）
        if (state.isGenerating)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  state.streamContent.isEmpty ? '正在生成报告...' : '生成中...',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                ),
              ],
            ),
          ),

        // 思考过程（可折叠）——仅当 reasoningContent 有内容时渲染
        if (state.reasoningContent != null &&
            state.reasoningContent!.isNotEmpty)
          _ReasoningTile(
            reasoning: state.reasoningContent!,
            theme: theme,
          ),

        // 报告正文：流式期间也用 MarkdownBody 渲染，避免裸露 Markdown 符号
        if (state.streamContent.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 520),
            margin: const EdgeInsets.only(top: 4),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: state.streamContent,
                selectable: true,
                styleSheet: _buildMarkdownStyle(theme),
              ),
            ),
          ),

        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: theme.textTheme.bodyMedium?.color,
      ),
      h1: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
        height: 1.4,
      ),
      h2: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
        height: 1.4,
      ),
      h3: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      listBullet: TextStyle(fontSize: 14, color: theme.colorScheme.primary),
      code: TextStyle(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 10),
      tableHead: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      tableBody: TextStyle(fontSize: 13, height: 1.4),
      tableBorder: TableBorder.all(color: theme.dividerColor, width: 0.5),
      tableColumnWidth: const FlexColumnWidth(),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      strong: const TextStyle(fontWeight: FontWeight.bold),
      em: const TextStyle(fontStyle: FontStyle.italic),
    );
  }
}

/// 思考过程折叠面板。默认收起，避免占屏。
class _ReasoningTile extends StatefulWidget {
  final String reasoning;
  final ThemeData theme;

  const _ReasoningTile({required this.reasoning, required this.theme});

  @override
  State<_ReasoningTile> createState() => _ReasoningTileState();
}

class _ReasoningTileState extends State<_ReasoningTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
                    size: 16,
                    color: widget.theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '思考过程',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: widget.theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Text(
                    widget.reasoning,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: widget.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
