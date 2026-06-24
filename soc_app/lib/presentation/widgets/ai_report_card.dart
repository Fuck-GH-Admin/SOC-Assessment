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

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('AI 评估报告',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                if (state.isGenerating)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  ),
              ],
            ),
            if (state.isGenerating && state.streamContent.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('正在生成报告...',
                    style: TextStyle(color: Colors.grey)),
              ),
            if (state.reasoningContent != null)
              ExpansionTile(
                title: const Text('思考过程',
                    style: TextStyle(fontSize: 13)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      state.reasoningContent!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            if (state.streamContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: state.isGenerating
                    ? Text(state.streamContent,
                        style: const TextStyle(fontSize: 14))
                    : MarkdownBody(
                        data: state.streamContent,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 14),
                          h1: const TextStyle(fontSize: 18),
                          h2: const TextStyle(fontSize: 16),
                        ),
                      ),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(state.error!,
                    style: TextStyle(
                        color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
