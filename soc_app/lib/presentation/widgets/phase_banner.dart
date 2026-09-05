import 'package:flutter/material.dart';

import '../models/assessment_phase.dart';

/// 方案 §细节交互：状态条采用顶部提示而非弹窗阻断。
/// 展示当前评估生命周期（未计算 / 计算完成未保存 / 已保存 /
/// 参数已修改失效），并携带主行动按钮。
class PhaseBanner extends StatelessWidget {
  final AssessmentPhaseView view;
  final VoidCallback? onReassess;

  const PhaseBanner({super.key, required this.view, this.onReassess});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (color, fg, icon) = switch (view.phase) {
      AssessmentPhase.draft => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
        Icons.radio_button_unchecked,
      ),
      AssessmentPhase.calculated => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      AssessmentPhase.saved => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        Icons.bookmark_added_outlined,
      ),
      AssessmentPhase.stale => (
        cs.errorContainer,
        cs.onErrorContainer,
        Icons.warning_amber_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              view.label,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
          if (view.phase == AssessmentPhase.stale)
            TextButton(
              onPressed: onReassess,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('重新评估'),
            ),
        ],
      ),
    );
  }
}
