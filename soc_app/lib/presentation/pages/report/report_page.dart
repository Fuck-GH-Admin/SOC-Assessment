import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/ai_report_prompt.dart';
import '../../../domain/engine/chart_narrative.dart';
import '../../../domain/engine/soc_calculator.dart';
import '../../providers/ai_config_provider.dart';
import '../../providers/ai_report_provider.dart';
import '../../providers/calculator_provider.dart';
import '../../widgets/ai_report_card.dart';

/// 报告页：本地确定性摘要（默认，完全离线）+ AI 辅助解读（可选）。
///
/// 方案 §2：AI 定位降为可选辅助——默认展示由 ChartNarrative 与计算
/// 结果直接拼装的本地摘要；AI 生成放在次级操作区，未配置时只给
/// 引导提示，不阻塞任何主流程。
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  Future<void> _generateReport() async {
    try {
      final service = ref.read(aiConfigProvider);
      var preset = await service.readPreset();
      var apiKey = await service.readApiKey();
      if (preset.apiKeyRequired && (apiKey == null || apiKey.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('使用 AI 解读前请先在设置中配置服务商与 API Key')),
        );
        return;
      }
      if (!mounted) return;
      final baseUrl = await service.readBaseUrl();
      final model = await service.readModel();
      final enableThinking = await service.readEnableThinking();
      final reasoningEffort = await service.readReasoningEffort();
      ref.read(aiReportProvider.notifier).generateReport(
            baseUrl: baseUrl,
            apiKey: apiKey ?? '',
            model: model,
            systemPrompt: systemPrompt,
            enableThinking: enableThinking,
            reasoningEffort: reasoningEffort,
            extraThinkingBody: enableThinking ? preset.extraBody : null,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 配置读取失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final aiState = ref.watch(aiReportProvider);
    final theme = Theme.of(context);

    if (!state.isCalculated || state.result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64,
                color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('完成一次评估后即可生成报告', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    final params = state.params;
    final result = state.result!;
    final layerLabel = depthDefinitionFor(params.depth).label;
    final summary = ChartNarrative.oneLineSummary(
      fertLabel: params.fert == 'F' ? '施肥' : '不施肥',
      erosion: params.erosion,
      layerLabel: layerLabel,
      result: result,
      resilience: state.resilience,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 本地摘要（默认、离线、确定性）──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('评估摘要',
                          style: theme.textTheme.titleLarge),
                    ),
                    Chip(
                      label: const Text('本地生成 · 离线可用'),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    summary,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  theme,
                  'SOC 含量',
                  '${result.soc} g/kg',
                ),
                _summaryRow(
                  theme,
                  '当前土层碳库',
                  '${result.carbonStorage} kg C/m²',
                ),
                _summaryRow(
                  theme,
                  '相对同层 CK',
                  '${result.netChange >= 0 ? '+' : ''}${result.netChange} kg C/m²'
                  '（损失率 ${result.lossRate}%）',
                ),
                if (state.resilience != null) ...[
                  _summaryRow(
                    theme,
                    '剖面（0-60cm）相对 CK',
                    '${state.resilience!.netChange20yr >= 0 ? '+' : ''}'
                    '${state.resilience!.netChange20yr} kg C/m²',
                  ),
                  _summaryRow(
                    theme,
                    '相对 CK 状态',
                    state.resilience!.status,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '口径：静态差异与折算代理，非逐年预测；摘要由计算结果直接生成，'
                  '不经过任何模型。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── AI 辅助解读（可选、次级）──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('辅助解读（可选）',
                          style: theme.textTheme.titleMedium),
                    ),
                    if (aiState.sourceFingerprint != null &&
                        aiState.sourceFingerprint ==
                            buildCalculationFingerprint(
                              params,
                              result,
                              state.resilience,
                            ) &&
                        !aiState.isGenerating &&
                        aiState.streamContent.isNotEmpty)
                      Chip(
                        label: const Text('与当前评估一致'),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '将当前参数与结果发送到你配置的 AI 服务生成解读文字；'
                  '生成内容仅供参考，不参与任何计算。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: aiState.isGenerating
                          ? null
                          : () => _generateReport(),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('生成 AI 解读'),
                    ),
                    if (aiState.isGenerating) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(aiReportProvider.notifier).cancel(),
                        child: const Text('取消'),
                      ),
                    ],
                    if (aiState.streamContent.isNotEmpty &&
                        !aiState.isGenerating) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(aiReportProvider.notifier).reset(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('重新生成'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                const AiReportCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
