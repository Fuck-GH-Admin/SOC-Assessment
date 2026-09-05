import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/engine/resilience_report_engine.dart';
import '../../../domain/models/resilience_report.dart';
import '../../providers/calculator_provider.dart';
import '../../widgets/candidate_card.dart';

/// 恢复力评估页：第五章 5.1 口径的分层证据、侵蚀亏缺矩阵与
/// 秸秆情景覆盖对照。全部数值来自三维查表，不引入新模型。
class ResiliencePage extends ConsumerWidget {
  const ResiliencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final theme = Theme.of(context);

    if (!state.isCalculated || state.result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restore, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('请先在“计算”页面完成计算', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    final params = state.params;
    final report = assessResilienceReport(
      params.fert,
      params.erosion,
      params.bd,
      cropBiomass: params.cropBiomass,
      strawCarbonRatio: params.strawCarbonRatio,
      litterCarbonInput: params.litterCarbonInput,
    );

    if (report == null) {
      return const Center(child: Text('剖面校验未通过，无法生成恢复力评估。'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pageHeader(theme, params, report),
        _sectionTitle(theme, '分层恢复力证据', '式 5-1 单层碳库 · 同层 CK 静态差'),
        _layerEvidencePanel(context, report),
        const SizedBox(height: 16),
        _sectionTitle(theme, '侵蚀亏缺矩阵', '式 5-2 剖面累加 · ÷20 折算代理'),
        _deficitMatrixPanel(context, report, params.erosion),
        const SizedBox(height: 16),
        _sectionTitle(theme, '秸秆情景覆盖对照', '式 5-5 情景碳输入 · 年化亏缺量级比较'),
        _coveragePanel(context, report),
        const SizedBox(height: 16),
        _conclusionPanel(context, report),
        const SizedBox(height: 8),
        Text(
          '口径说明：恢复力指标为当前侵蚀处理相对同施肥 CK 的静态差异与折算代理，'
          '不是逐年恢复趋势；情景覆盖仅比较管理碳输入与亏缺代理的量级，'
          '不代表 SOC 将等量增加。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _pageHeader(
    ThemeData theme,
    dynamic params,
    ResilienceReport report,
  ) {
    final cs = theme.colorScheme;
    final verdictColor = switch (report.conclusionLevel) {
      'covering' => cs.primary,
      'partial' => Colors.orange,
      _ => cs.error,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('恢复力评估', style: theme.textTheme.titleLarge),
            Text(
              '分层证据 · 亏缺矩阵 · 情景覆盖',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: verdictColor, width: 3)),
              ),
              child: Text(report.conclusionText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(title, style: theme.textTheme.titleMedium),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerEvidencePanel(BuildContext context, ResilienceReport report) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final layer in report.layers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 86,
                      child: Text(
                        layer.layerId,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '碳库差 ${layer.poolDifference.toStringAsFixed(3)} kg C/m²',
                        style: TextStyle(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: layer.poolDifference < 0
                              ? cs.error
                              : cs.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Text(
                        '损失率 ${layer.lossRate.toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (layer.layerId == report.weakestLayerId) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('薄弱层'),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: cs.onErrorContainer,
                        ),
                        backgroundColor: cs.errorContainer,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deficitMatrixPanel(
    BuildContext context,
    ResilienceReport report,
    int currentErosion,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 36,
          columns: const [
            DataColumn(label: Text('侵蚀程度')),
            DataColumn(label: Text('剖面亏缺'), numeric: true),
            DataColumn(label: Text('年化代理'), numeric: true),
          ],
          rows: [
            for (final d in report.erosionDeficits)
              DataRow(
                color: d.erosionCm == currentErosion
                    ? WidgetStateProperty.all(cs.surfaceContainerHighest)
                    : null,
                cells: [
                  DataCell(
                    Text(
                      d.erosionCm == 0 ? '0cm（CK）' : '${d.erosionCm}cm',
                      style: TextStyle(
                        fontWeight: d.erosionCm == currentErosion
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${d.deficit.toStringAsFixed(3)} kg C/m²',
                      style: TextStyle(
                        color: d.deficit < 0 ? cs.error : cs.onSurface,
                      ),
                    ),
                  ),
                  DataCell(
                    Text('${d.annualizedDeficit.toStringAsFixed(4)} kg C/m²/yr'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _coveragePanel(BuildContext context, ResilienceReport report) {
    final ordered = [...report.scenarioCoverages];
    ordered.sort((a, b) => b.strawInput.compareTo(a.strawInput));

    return Column(
      children: [
        for (var i = 0; i < ordered.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CandidateCard(
              rank: i + 1,
              title: ordered[i].label,
              subtitle: '还田比例 ${(ordered[i].returnRatio * 100).round()}%',
              metrics: [
                (
                  value: ordered[i].strawInput.toStringAsFixed(3),
                  unit: 'kg C/m²',
                  label: '秸秆碳输入',
                ),
                (
                  value: ordered[i].coverageMargin >= 0
                      ? '+${ordered[i].coverageMargin.toStringAsFixed(3)}'
                      : ordered[i].coverageMargin.toStringAsFixed(3),
                  unit: 'kg C/m²/yr',
                  label: '覆盖余量',
                ),
              ],
              progress: ordered[i].coverageRatio,
              verdict: switch (report.conclusionLevel) {
                'covering' when ordered[i].coverageMargin >= 0 =>
                  CandidateVerdict.recommended,
                'partial' when ordered[i].coverageMargin >= 0 =>
                  CandidateVerdict.recommended,
                'deficit' => CandidateVerdict.limited,
                _ =>
                  report.conclusionLevel == 'partial'
                      ? CandidateVerdict.limited
                      : CandidateVerdict.ok,
              },
              verdictText: switch (report.conclusionLevel) {
                'covering' when ordered[i].coverageMargin >= 0 =>
                  '覆盖年化亏缺 · 推荐方案',
                'partial' when ordered[i].coverageMargin >= 0 =>
                  '部分覆盖 · 相对最优',
                'deficit' => '未填写秸秆参数 · 无法评估',
                _ => '不足以覆盖亏缺',
              },
            ),
          ),
      ],
    );
  }

  Widget _conclusionPanel(BuildContext context, ResilienceReport report) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('结论与排查建议', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('1. 薄弱层为 ${report.weakestLayerId}，优先核查该层采样与侵蚀状况。'),
            Text(
              '2. 当前剖面年化亏缺代理为 ${report.annualizedDeficit.toStringAsFixed(4)} kg C/m²/yr，'
              '与秸秆情景对照见上表。',
            ),
            const Text(
              '3. 若亏缺未被覆盖，可评估秸秆全量还田之外的其他有机物料投入。',
            ),
          ],
        ),
      ),
    );
  }
}
