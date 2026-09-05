import 'package:flutter/foundation.dart';

/// 评估记录的生命周期状态（方案 §桌面端/参数修改后状态处理）。
///
/// 状态推进：draft → calculated → saved；
/// 参数在 calculated/saved 之后被修改则进入 stale（旧结果保留但置灰）。
enum AssessmentPhase {
  /// 尚未计算（或参数被重置）。
  draft,

  /// 已完成计算但用户尚未主动保存为评估记录。
  calculated,

  /// 计算结果已保存为正式评估记录。
  saved,

  /// 计算完成后参数又被修改：旧结果仅作参考展示，
  /// 导出/保存/生成报告被禁用，需要重新评估。
  stale,
}

/// 当前计算会话的状态机视图，由 CalculatorState 派生。
@immutable
class AssessmentPhaseView {
  final AssessmentPhase phase;

  /// stale 状态下保留展示的旧结果快照描述，用于“参数已修改”提示。
  final String? staleHint;

  const AssessmentPhaseView({required this.phase, this.staleHint});

  bool get canExport => phase == AssessmentPhase.calculated ||
      phase == AssessmentPhase.saved;

  bool get resultsDimmed => phase == AssessmentPhase.stale;

  String get label => switch (phase) {
        AssessmentPhase.draft => '未计算',
        AssessmentPhase.calculated => '计算完成未保存',
        AssessmentPhase.saved => '已保存',
        AssessmentPhase.stale => '参数已修改，当前结果已失效',
      };
}
