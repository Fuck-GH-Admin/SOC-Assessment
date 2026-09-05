import 'package:flutter/material.dart';

/// 三态结论：推荐 / 成立 / 受限。
enum CandidateVerdict { recommended, ok, limited }

/// FZP 式候选方案卡片：排名徽章 + 标题副题 + 2×2 指标网格 +
/// 覆盖度条 + 三态验证条。
///
/// [metrics] 按行优先填充 2×2 网格；值与单位分开传入以统一排版。
/// [progress] 为 0-1 的覆盖度；空进度传 null 隐藏进度条。
class CandidateCard extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final List<({String value, String? unit, String label})> metrics;
  final double? progress;
  final CandidateVerdict verdict;
  final String verdictText;

  const CandidateCard({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.verdict,
    required this.verdictText,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isRecommended = verdict == CandidateVerdict.recommended;
    final accent = switch (verdict) {
      CandidateVerdict.recommended => cs.primary,
      CandidateVerdict.ok => cs.onSurfaceVariant,
      CandidateVerdict.limited => cs.error,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecommended ? cs.primary : cs.outlineVariant,
          width: isRecommended ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: isRecommended
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                foregroundColor: isRecommended ? cs.onPrimary : cs.primary,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (metrics.isNotEmpty) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
              childAspectRatio: 5.2,
              children: [
                for (final m in metrics)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: m.value,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          children: [
                            if (m.unit != null)
                              TextSpan(
                                text: ' ${m.unit}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        m.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verdictText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
