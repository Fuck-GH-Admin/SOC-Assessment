import 'package:flutter/material.dart';

/// 图表卡片的叙事化外壳：标题 + 一句话结论 + 图 + 口径脚注。
///
/// 方案 §5“每张图上方先给一句话结论”+ 反“廉价感”的核心组件：
/// 图不再是裸图，而是“回答一个明确问题”的证据卡。
/// [insight] 由调用方基于真实计算结果生成，禁止写死与数据无关的文案。
class ChartStoryCard extends StatelessWidget {
  final String title;

  /// 图表要回答的用户问题，例如“侵蚀越深，表层碳损失越多吗？”
  final String question;

  /// 一句话结论，通常包含关键数字（如“10cm 处表层 SOC 较 CK 低 26%”）。
  final String insight;

  /// 结论与数据口径的边界说明（一行）。
  final String? caveat;

  final Widget chart;
  final List<Widget>? actions;

  const ChartStoryCard({
    super.key,
    required this.title,
    required this.question,
    required this.insight,
    required this.chart,
    this.caveat,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...(actions ?? const <Widget>[]),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              question,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // 结论条：左边框强调 + 关键数字，先读结论再看图。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: cs.primary, width: 3),
                ),
              ),
              child: Text(
                insight,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            chart,
            if (caveat != null) ...[
              const SizedBox(height: 8),
              Text(
                caveat!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
