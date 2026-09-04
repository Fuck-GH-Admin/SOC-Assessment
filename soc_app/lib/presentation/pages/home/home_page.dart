import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:soc_app/core/theme/app_theme.dart';
import 'package:soc_app/core/theme/theme_provider.dart';
import 'package:soc_app/data/pdf_exporter.dart';
import 'package:soc_app/data/ai_report_prompt.dart';
import 'package:soc_app/data/pdf_report_storage.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/presentation/providers/ai_config_provider.dart';
import 'package:soc_app/presentation/providers/ai_report_provider.dart';
import 'package:soc_app/presentation/providers/calculator_provider.dart';
import 'package:soc_app/presentation/providers/draft_dao_provider.dart';
import 'package:soc_app/presentation/providers/history_provider.dart';
import 'package:soc_app/presentation/providers/record_dao_provider.dart';
import 'package:soc_app/presentation/widgets/ai_report_card.dart';
import 'package:soc_app/presentation/widgets/charts/assessment_radar_chart.dart';
import 'package:soc_app/presentation/widgets/charts/comparison_fill_chart.dart';
import 'package:soc_app/presentation/widgets/charts/correlation_scatter_chart.dart';
import 'package:soc_app/presentation/widgets/charts/depth_line_chart.dart';
import 'package:soc_app/presentation/widgets/charts/erosion_bar_chart.dart';
import 'package:soc_app/presentation/widgets/charts/heatmap_chart.dart';
import 'package:soc_app/presentation/widgets/charts/pool_pie_chart.dart';
import 'package:soc_app/presentation/widgets/charts/straw_scenario_chart.dart';
import 'package:soc_app/presentation/pages/history/history_page.dart';
import 'package:soc_app/presentation/pages/resilience/resilience_page.dart';
import 'package:soc_app/presentation/pages/settings/settings_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _maxDraftAge = Duration(days: 7);

  late final Map<String, TextEditingController> _ctrls;
  final PdfReportStorage _pdfReportStorage = PdfReportStorage();
  bool _pdfExporting = false;
  int _tabIndex = 0;
  int _chartTabIndex = 0;

  /// Keys for the visible chart carousel (used for on-screen display).
  final _chartKeys = List.generate(8, (_) => GlobalKey());

  /// Separate keys used exclusively for PDF capture.
  /// The hidden render layer is mounted only while exporting and painted
  /// offscreen under the light theme.
  final _pdfChartKeys = List.generate(8, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _ctrls = {
      'bd': TextEditingController(),
      'ph': TextEditingController(),
      'wc': TextEditingController(),
      'clay': TextEditingController(),
      'tn': TextEditingController(),
      'cropBiomass': TextEditingController(),
      'strawCarbonRatio': TextEditingController(),
      'litterCarbonInput': TextEditingController(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCtrlsFromParams(ref.read(calculatorProvider).params);
      _checkDraft();
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncCtrlsFromParams(CalculationParams params) {
    _ctrls['bd']!.text = params.bd.toString();
    _ctrls['ph']!.text = params.ph.toString();
    _ctrls['wc']!.text = params.wc.toString();
    _ctrls['clay']!.text = params.clay.toString();
    _ctrls['tn']!.text = params.tn.toString();
    _ctrls['cropBiomass']!.text = params.cropBiomass.toStringAsFixed(0);
    _ctrls['strawCarbonRatio']!.text = params.strawCarbonRatio.toString();
    _ctrls['litterCarbonInput']!.text = params.litterCarbonInput.toString();
    for (final c in _ctrls.values) {
      if (c.text.isNotEmpty) {
        c.selection = TextSelection.fromPosition(
          TextPosition(offset: c.text.length),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final theme = Theme.of(context);

    // Read the current seed colour so the hidden layer can use lightTheme.
    final seedColor = ref.watch(seedColorProvider);

    ref.listen<CalculatorState>(calculatorProvider, (previous, next) {
      if (previous == null) return;
      final paramsChanged =
          previous.params.toJson().toString() !=
          next.params.toJson().toString();
      final resultChanged = previous.result != next.result;
      if (paramsChanged || resultChanged) {
        ref.read(aiReportProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOC 土壤碳评估'),
        actions: [
          if (state.isCalculated)
            IconButton(
              icon: _pdfExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: '导出 PDF',
              onPressed: _pdfExporting ? null : () => _exportPdf(),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
            onPressed: _pdfExporting
                ? null
                : () async {
                    final params = await Navigator.push<CalculationParams>(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryPage()),
                    );
                    if (params == null || !mounted) return;
                    ref.read(calculatorProvider.notifier).loadParams(params);
                    _syncCtrlsFromParams(params);
                    setState(() => _tabIndex = 0);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: _pdfExporting
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
          ),
        ],
      ),
      // Render 8 chart offscreen (x=5000) so they are always painted
      // and toImage() works.  Stack is Clip.none so offscreen content is
      // not clipped.  IgnorePointer prevents accidental taps on the
      // invisible offscreen region.
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          IndexedStack(
            index: _tabIndex,
            children: [
              _buildCalcTab(state, theme),
              _buildChartTab(state, theme),
              const ResiliencePage(),
            ],
          ),
          if (state.isCalculated && _pdfExporting)
            Positioned(
              left: 5000,
              top: 0,
              child: IgnorePointer(
                child: Theme(
                  data: AppTheme.lightTheme(seedColor),
                  child: _buildPdfChartWidgets(state),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: '计算'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '图表'),
          NavigationDestination(icon: Icon(Icons.restore), label: '恢复力'),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: state.isCalculating || _pdfExporting
                  ? null
                  : () => ref.read(calculatorProvider.notifier).calculate(),
              icon: state.isCalculating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate),
              label: Text(state.isCalculating ? '计算中' : '计算'),
            )
          : null,
    );
  }

  // All 8 charts rendered in a Column at a fixed 600 × 300 size each.
  // These are wrapped in RepaintBoundary with _pdfChartKeys so that
  // PdfExporter.captureCharts() can call toImage() on each.
  Widget _buildPdfChartWidgets(CalculatorState state) {
    const w = 600.0;
    const h = 300.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          key: _pdfChartKeys[0],
          child: SizedBox(
            width: w,
            height: h,
            child: ErosionBarChart(fert: state.params.fert),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[1],
          child: SizedBox(
            width: w,
            height: h,
            child: DepthLineChart(
              fert: state.params.fert,
              erosion: state.params.erosion,
            ),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[2],
          child: SizedBox(
            width: w,
            height: h,
            child: StrawScenarioChart(
              cropBiomass: state.params.cropBiomass,
              strawCarbonRatio: state.params.strawCarbonRatio,
              litterCarbonInput: state.params.litterCarbonInput,
            ),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[3],
          child: SizedBox(
            width: w,
            height: h,
            child: AssessmentRadarChart(result: state.result!),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[4],
          child: SizedBox(
            width: w,
            height: h,
            child: PoolPieChart(
              fert: state.params.fert,
              erosion: state.params.erosion,
              bd: state.params.bd,
            ),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[5],
          child: SizedBox(
            width: w,
            height: h,
            child: CorrelationScatterChart(fert: state.params.fert),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[6],
          child: SizedBox(
            width: w,
            height: h,
            child: ComparisonFillChart(
              fert: state.params.fert,
              erosion: state.params.erosion,
            ),
          ),
        ),
        RepaintBoundary(
          key: _pdfChartKeys[7],
          child: SizedBox(
            width: w,
            height: h,
            child: HeatmapChart(fert: state.params.fert),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcTab(CalculatorState state, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('参数输入', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'SOC 含量来自施肥 × 侵蚀 × 土层实测数据表；容重用于碳库换算。'
                  'pH、含水量、黏粉粒和全氮仅作为辅助观测信息，不参与当前核心公式。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 500;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '统一土壤容重 (g/cm^3)',
                            hint: '0.5-2.5',
                            controller: _ctrls['bd']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateBd(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: 'pH值（辅助）',
                            hint: '3-11',
                            controller: _ctrls['ph']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updatePh(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '含水量（辅助，%）',
                            hint: '0-100',
                            controller: _ctrls['wc']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateWc(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '黏粉粒含量（辅助，%）',
                            hint: '0-100',
                            controller: _ctrls['clay']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateClay(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '全氮含量（辅助，g/kg）',
                            hint: '0-10',
                            controller: _ctrls['tn']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateTn(v),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(state.params.fert),
                  initialValue: state.params.fert,
                  decoration: const InputDecoration(labelText: '施肥方式'),
                  items: const [
                    DropdownMenuItem(value: 'F', child: Text('施肥')),
                    DropdownMenuItem(value: 'UNF', child: Text('未施肥')),
                  ],
                  onChanged: state.isCalculating || _pdfExporting
                      ? null
                      : (v) {
                          if (v != null) {
                            ref.read(calculatorProvider.notifier).updateFert(v);
                          }
                        },
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey(state.params.erosion),
                  initialValue: state.params.erosion,
                  decoration: const InputDecoration(labelText: '侵蚀程度 (cm)'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('无')),
                    DropdownMenuItem(value: 10, child: Text('轻度 (10cm)')),
                    DropdownMenuItem(value: 20, child: Text('20cm')),
                    DropdownMenuItem(value: 30, child: Text('30cm')),
                    DropdownMenuItem(value: 40, child: Text('40cm')),
                    DropdownMenuItem(value: 50, child: Text('50cm')),
                    DropdownMenuItem(value: 60, child: Text('60cm')),
                    DropdownMenuItem(value: 70, child: Text('重度 (70cm)')),
                  ],
                  onChanged: state.isCalculating || _pdfExporting
                      ? null
                      : (v) {
                          if (v != null) {
                            ref
                                .read(calculatorProvider.notifier)
                                .updateErosion(v);
                          }
                        },
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey(state.params.depth),
                  initialValue: state.params.depth,
                  decoration: const InputDecoration(labelText: '土层范围'),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('0-20cm（表层）')),
                    DropdownMenuItem(value: 25, child: Text('20-30cm（亚表层）')),
                    DropdownMenuItem(value: 35, child: Text('30-40cm（中层）')),
                    DropdownMenuItem(value: 45, child: Text('40-50cm（深层）')),
                    DropdownMenuItem(value: 55, child: Text('50-60cm（底层）')),
                  ],
                  onChanged: state.isCalculating || _pdfExporting
                      ? null
                      : (v) {
                          if (v != null) {
                            ref
                                .read(calculatorProvider.notifier)
                                .updateDepth(v);
                          }
                        },
                ),
                const SizedBox(height: 20),
                Text('秸秆还田情景参数', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '以下参数只用于30%、50%和100%秸秆还田碳输入情景，不会反向改写当前实测 SOC。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 500;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '秸秆生物量 (kg/ha)',
                            hint: '例如 8500',
                            controller: _ctrls['cropBiomass']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateCropBiomass(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '秸秆碳含量比例 (0-1)',
                            hint: '例如 0.45',
                            controller: _ctrls['strawCarbonRatio']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateStrawCarbonRatio(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '基础凋落物碳输入 (kg C/m²)',
                            hint: '例如 0.15',
                            controller: _ctrls['litterCarbonInput']!,
                            enabled: !state.isCalculating && !_pdfExporting,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateLitterCarbonInput(v),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: state.isCalculating || _pdfExporting
                        ? null
                        : () async {
                            await ref
                                .read(calculatorProvider.notifier)
                                .resetParams();
                            _syncCtrlsFromParams(const CalculationParams());
                          },
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('恢复默认参数'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.errors.isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '输入错误',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  ...state.errors.map((e) => Text(e)),
                ],
              ),
            ),
          ),
        if (state.warnings.isNotEmpty)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '运行提示',
                    style: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  ...state.warnings.map((e) => Text(e)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('计算结果', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildResultRow(
                  'SOC含量',
                  state.isCalculated ? '${state.result!.soc} g/kg' : '--',
                ),
                _buildResultRow(
                  '当前土层碳储量',
                  state.isCalculated
                      ? '${state.result!.carbonStorage} kg C/m^2'
                      : '--',
                ),
                _buildResultRow(
                  '碳密度',
                  state.isCalculated
                      ? '${state.result!.carbonDensity} kg C/m^3'
                      : '--',
                ),
                _buildResultRow(
                  '当前土层相对CK碳库差',
                  state.isCalculated
                      ? '${state.result!.netChange} kg C/m^2'
                      : '--',
                ),
                _buildResultRow(
                  '当前土层差值/20年（折算代理）',
                  state.isCalculated
                      ? '${state.result!.recoveryRate} kg C/m^2/yr'
                      : '--',
                ),
                _buildResultRow(
                  '0-60cm 相对CK碳库差（源文档20年口径）',
                  state.isCalculated && state.resilience != null
                      ? '${state.resilience!.netChange20yr} kg C/m^2'
                      : '--',
                ),
                _buildResultRow(
                  '0-20cm 相对CK碳库差（源文档100年口径）',
                  state.isCalculated && state.resilience != null
                      ? '${state.resilience!.netChange100yr} kg C/m^2'
                      : '--',
                ),
                _buildResultRow(
                  '0-60cm 差值/20年（折算代理）',
                  state.isCalculated && state.resilience != null
                      ? '${state.resilience!.recoveryRateAnnual} kg C/m^2/yr'
                      : '--',
                ),
                _buildResultRow(
                  '当前土层相对CK损失率',
                  state.isCalculated ? '${state.result!.lossRate} %' : '--',
                ),
                const SizedBox(height: 8),
                Text(
                  '说明：当前没有逐年模拟末期数据。上述“20年/100年”指标以同施肥、'
                  '侵蚀0cm（CK）为参考作口径代理，不应解释为真实时间序列预测。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartTab(CalculatorState state, ThemeData theme) {
    if (!state.isCalculated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('请先在"计算"页面完成计算', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    final aiState = ref.watch(aiReportProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('图表分析', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _ChartCarousel(
                  chartKeys: _chartKeys,
                  tabIndex: _chartTabIndex,
                  onTabChanged: (i) => setState(() => _chartTabIndex = i),
                  fert: state.params.fert,
                  erosion: state.params.erosion,
                  depth: state.params.depth,
                  bd: state.params.bd,
                  cropBiomass: state.params.cropBiomass,
                  strawCarbonRatio: state.params.strawCarbonRatio,
                  litterCarbonInput: state.params.litterCarbonInput,
                  result: state.result!,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 评估报告', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: aiState.isGenerating
                          ? null
                          : () => _generateReport(),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('生成报告'),
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

  Future<void> _checkDraft() async {
    try {
      final dao = await ref.read(draftDaoProvider.future);
      final age = await dao.getAgeMillis();
      if (age == null || !mounted) return;
      if (age < 0 || age > _maxDraftAge.inMilliseconds) {
        await dao.delete();
        return;
      }
      final draft = await dao.load();
      if (draft == null || !mounted) return;
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('恢复草稿'),
          content: const Text('检测到未完成的草稿，是否恢复？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('忽略'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );
      if (restore == true && mounted) {
        ref.read(calculatorProvider.notifier).loadDraft(draft);
        _syncCtrlsFromParams(draft);
      }
      // “忽略”按用户手册口径保留草稿：草稿仅在恢复、成功计算、
      // 手动重置或超过 7 天后被清理，因此关闭提示时不删除。
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('草稿读取失败：$e')));
    }
  }

  Future<void> _generateReport() async {
    try {
      final service = ref.read(aiConfigProvider);
      var preset = await service.readPreset();
      var apiKey = await service.readApiKey();
      if (preset.apiKeyRequired && (apiKey == null || apiKey.isEmpty)) {
        if (!mounted) return;
        final configured = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
        if (configured != true || !mounted) return;
        preset = await service.readPreset();
        apiKey = await service.readApiKey();
      }
      if (preset.apiKeyRequired && (apiKey == null || apiKey.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未检测到 API Key，请先完成配置')));
        return;
      }
      if (!mounted) return;
      final baseUrl = await service.readBaseUrl();
      final model = await service.readModel();
      final enableThinking = await service.readEnableThinking();
      final reasoningEffort = await service.readReasoningEffort();
      ref
          .read(aiReportProvider.notifier)
          .generateReport(
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

  Future<void> _exportPdf() async {
    final calcState = ref.read(calculatorProvider);
    if (!calcState.isCalculated || calcState.result == null) return;

    setState(() => _pdfExporting = true);
    try {
      // Use _pdfChartKeys (from the temporary offscreen render layer) instead
      // of _chartKeys (from the IndexedStack carousel).  The carousel only
      // paints the currently visible chart tab, so toImage() on the others
      // would throw "Null check operator used on a null value".
      final chartImages = await PdfExporter.captureCharts(_pdfChartKeys);
      if (chartImages.length != _pdfChartKeys.length) {
        throw StateError(
          '图表截图不完整：${chartImages.length}/${_pdfChartKeys.length}',
        );
      }
      final aiState = ref.read(aiReportProvider);
      final currentFingerprint = buildCalculationFingerprint(
        calcState.params,
        calcState.result!,
        calcState.resilience,
      );
      final bytes = await PdfExporter.generate(
        params: calcState.params,
        result: calcState.result!,
        resilience: calcState.resilience,
        chartImages: chartImages,
        aiReport:
            !aiState.isGenerating &&
                aiState.error == null &&
                aiState.streamContent.isNotEmpty &&
                aiState.sourceFingerprint == currentFingerprint
            ? aiState.streamContent
            : null,
      );

      final persistentFile = await _pdfReportStorage.save(
        bytes,
        recordId: calcState.recordId,
      );
      final fileName = p.basename(persistentFile.path);
      final linkedToHistory = await _tryLinkPdfToHistory(
        calcState.recordId,
        persistentFile.path,
      );

      if (Platform.isAndroid) {
        await Share.shareXFiles([XFile(persistentFile.path)], text: 'SOC 评估报告');
        if (mounted) {
          _showPdfSavedSnackBar(
            localPath: persistentFile.path,
            linkedToHistory: linkedToHistory,
          );
        }
      } else {
        final path = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (path != null) {
          await File(path).writeAsBytes(bytes);
        }
        if (mounted) {
          _showPdfSavedSnackBar(
            localPath: persistentFile.path,
            externalPath: path,
            linkedToHistory: linkedToHistory,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF 导出失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _pdfExporting = false);
    }
  }

  Future<bool> _tryLinkPdfToHistory(int? recordId, String path) async {
    if (recordId == null) return false;
    try {
      final dao = await ref.read(recordDaoProvider.future);
      await dao.updatePdfPath(recordId, path);
      ref.invalidate(historyListProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showPdfSavedSnackBar({
    required String localPath,
    required bool linkedToHistory,
    String? externalPath,
  }) {
    final externalText = externalPath == null ? '' : '\n另存副本: $externalPath';
    final historyText = linkedToHistory ? '' : '\n提示：本次报告未能关联到历史记录。';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('PDF 已保存到应用本地: $localPath$externalText$historyText'),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required void Function(double) onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            final valid = RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text);
            return valid ? newValue : oldValue;
          }),
        ],
        controller: controller,
        onChanged: (v) {
          if (v.trim().isEmpty) {
            onChanged(0);
            return;
          }
          final parsed = double.tryParse(v);
          onChanged(parsed ?? 0);
        },
      ),
    );
  }

  Widget _buildResultRow(String label, String display) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCarousel extends StatefulWidget {
  final List<GlobalKey> chartKeys;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final String fert;
  final int erosion;
  final int depth;
  final double bd;
  final double cropBiomass;
  final double strawCarbonRatio;
  final double litterCarbonInput;
  final CalculationResult result;

  const _ChartCarousel({
    required this.chartKeys,
    required this.tabIndex,
    required this.onTabChanged,
    required this.fert,
    required this.erosion,
    required this.depth,
    required this.bd,
    required this.cropBiomass,
    required this.strawCarbonRatio,
    required this.litterCarbonInput,
    required this.result,
  });

  @override
  State<_ChartCarousel> createState() => _ChartCarouselState();
}

class _ChartCarouselState extends State<_ChartCarousel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _tabSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.tabIndex,
    );
    _tabController.addListener(() {
      if (!_tabSyncing && !_tabController.indexIsChanging) {
        widget.onTabChanged(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ChartCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabIndex != _tabController.index) {
      _tabSyncing = true;
      _tabController.index = widget.tabIndex;
      _tabSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final charts = <Widget>[
      RepaintBoundary(
        key: widget.chartKeys[0],
        child: SingleChildScrollView(child: ErosionBarChart(fert: widget.fert)),
      ),
      RepaintBoundary(
        key: widget.chartKeys[1],
        child: SingleChildScrollView(
          child: DepthLineChart(fert: widget.fert, erosion: widget.erosion),
        ),
      ),
      RepaintBoundary(
        key: widget.chartKeys[2],
        child: SingleChildScrollView(
          child: StrawScenarioChart(
            cropBiomass: widget.cropBiomass,
            strawCarbonRatio: widget.strawCarbonRatio,
            litterCarbonInput: widget.litterCarbonInput,
          ),
        ),
      ),
      RepaintBoundary(
        key: widget.chartKeys[3],
        child: SingleChildScrollView(
          child: AssessmentRadarChart(result: widget.result),
        ),
      ),
      RepaintBoundary(
        key: widget.chartKeys[4],
        child: SingleChildScrollView(
          child: PoolPieChart(
            fert: widget.fert,
            erosion: widget.erosion,
            bd: widget.bd,
          ),
        ),
      ),
      RepaintBoundary(
        key: widget.chartKeys[5],
        child: SingleChildScrollView(
          child: CorrelationScatterChart(fert: widget.fert),
        ),
      ),
      RepaintBoundary(
        key: widget.chartKeys[6],
        child: SingleChildScrollView(
          child: ComparisonFillChart(
            fert: widget.fert,
            erosion: widget.erosion,
          ),
        ),
      ),
      RepaintBoundary(
        key: widget.chartKeys[7],
        child: SingleChildScrollView(child: HeatmapChart(fert: widget.fert)),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(text: '侵蚀'),
              Tab(text: '深度'),
              Tab(text: '秸秆'),
              Tab(text: '评估'),
              Tab(text: '组成'),
              Tab(text: '关联'),
              Tab(text: '对比'),
              Tab(text: '热力'),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: IndexedStack(index: widget.tabIndex, children: charts),
        ),
      ],
    );
  }
}
