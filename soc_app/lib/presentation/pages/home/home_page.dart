import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soc_app/data/pdf_exporter.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/presentation/providers/ai_config_provider.dart';
import 'package:soc_app/presentation/providers/ai_report_provider.dart';
import 'package:soc_app/presentation/providers/calculator_provider.dart';
import 'package:soc_app/presentation/providers/draft_dao_provider.dart';
import 'package:soc_app/presentation/widgets/ai_report_card.dart';
import 'package:soc_app/presentation/widgets/charts/assessment_radar_chart.dart';
import 'package:soc_app/presentation/widgets/charts/comparison_fill_chart.dart';
import 'package:soc_app/presentation/widgets/charts/correlation_scatter_chart.dart';
import 'package:soc_app/presentation/widgets/charts/depth_line_chart.dart';
import 'package:soc_app/presentation/widgets/charts/erosion_bar_chart.dart';
import 'package:soc_app/presentation/widgets/charts/heatmap_chart.dart';
import 'package:soc_app/presentation/widgets/charts/pool_pie_chart.dart';
import 'package:soc_app/presentation/widgets/charts/time_line_chart.dart';
import 'package:soc_app/presentation/pages/history/history_page.dart';
import 'package:soc_app/presentation/pages/settings/settings_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final Map<String, TextEditingController> _ctrls;
  bool _pdfExporting = false;
  int _chartTabIndex = 0;
  final _chartKeys = List.generate(8, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _ctrls = {
      'bd': TextEditingController(),
      'ph': TextEditingController(),
      'wc': TextEditingController(),
      'clay': TextEditingController(),
      'tn': TextEditingController(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCtrlsFromParams(ref.read(calculatorProvider).params);
      _checkDraft();
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  void _syncCtrlsFromParams(CalculationParams params) {
    _ctrls['bd']!.text = params.bd > 0 ? params.bd.toString() : '';
    _ctrls['ph']!.text = params.ph > 0 ? params.ph.toString() : '';
    _ctrls['wc']!.text = params.wc > 0 ? params.wc.toString() : '';
    _ctrls['clay']!.text = params.clay > 0 ? params.clay.toString() : '';
    _ctrls['tn']!.text = params.tn > 0 ? params.tn.toString() : '';
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
    final aiState = ref.watch(aiReportProvider);
    final theme = Theme.of(context);

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
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              tooltip: '导出 PDF',
              onPressed: _pdfExporting ? null : () => _exportPdf(),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('参数输入', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 500;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '土壤容重 (g/cm³)',
                            hint: '0.5-2.5',
                            controller: _ctrls['bd']!,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateBd(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: 'pH值',
                            hint: '3-11',
                            controller: _ctrls['ph']!,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updatePh(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '含水量 (%)',
                            hint: '0-100',
                            controller: _ctrls['wc']!,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateWc(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '黏粉粒含量 (%)',
                            hint: '0-100',
                            controller: _ctrls['clay']!,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateClay(v),
                          ),
                        ),
                        SizedBox(
                          width: wide ? 220 : double.infinity,
                          child: _buildTextField(
                            label: '全氮含量 (g/kg)',
                            hint: '0-10',
                            controller: _ctrls['tn']!,
                            onChanged: (v) => ref
                                .read(calculatorProvider.notifier)
                                .updateTn(v),
                          ),
                        ),
                      ],
                    );
                  }),
                  DropdownButtonFormField<String>(
                    key: ValueKey(state.params.fert),
                    initialValue: state.params.fert,
                    decoration:
                        const InputDecoration(labelText: '施肥方式'),
                    items: const [
                      DropdownMenuItem(value: 'F', child: Text('施肥')),
                      DropdownMenuItem(
                          value: 'UNF', child: Text('未施肥')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(calculatorProvider.notifier)
                            .updateFert(v);
                      }
                    },
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey(state.params.erosion),
                    initialValue: state.params.erosion,
                    decoration:
                        const InputDecoration(labelText: '侵蚀程度 (cm)'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('无')),
                      DropdownMenuItem(
                          value: 10, child: Text('轻度 (10cm)')),
                      DropdownMenuItem(value: 20, child: Text('20cm')),
                      DropdownMenuItem(value: 30, child: Text('30cm')),
                      DropdownMenuItem(value: 40, child: Text('40cm')),
                      DropdownMenuItem(value: 50, child: Text('50cm')),
                      DropdownMenuItem(value: 60, child: Text('60cm')),
                      DropdownMenuItem(
                          value: 70, child: Text('重度 (70cm)')),
                    ],
                    onChanged: (v) {
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
                    decoration:
                        const InputDecoration(labelText: '取样深度 (cm)'),
                    items: const [
                      DropdownMenuItem(
                          value: 10, child: Text('表层 (10cm)')),
                      DropdownMenuItem(value: 25, child: Text('25cm')),
                      DropdownMenuItem(
                          value: 35, child: Text('中层 (35cm)')),
                      DropdownMenuItem(value: 45, child: Text('45cm')),
                      DropdownMenuItem(
                          value: 55, child: Text('深层 (55cm)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(calculatorProvider.notifier)
                            .updateDepth(v);
                      }
                    },
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
                    Text('输入错误',
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer)),
                    ...state.errors.map((e) => Text(e)),
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
                    state.isCalculated
                        ? '${state.result!.soc} g/kg'
                        : '--',
                  ),
                  _buildResultRow(
                    '碳储量',
                    state.isCalculated
                        ? '${state.result!.carbonStorage} kg C/m²'
                        : '--',
                  ),
                  _buildResultRow(
                    '碳密度',
                    state.isCalculated
                        ? '${state.result!.carbonDensity} kg C/m³'
                        : '--',
                  ),
                  _buildResultRow(
                    '净变化量',
                    state.isCalculated
                        ? '${state.result!.netChange} kg C/m²'
                        : '--',
                  ),
                  _buildResultRow(
                    '恢复速率',
                    state.isCalculated
                        ? '${state.result!.recoveryRate} kg C/m²/yr'
                        : '--',
                  ),
                  _buildResultRow(
                    '损失率',
                    state.isCalculated
                        ? '${state.result!.lossRate} %'
                        : '--',
                  ),
                ],
              ),
            ),
          ),
          if (state.isCalculated) ...[
            const SizedBox(height: 16),
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
                      onTabChanged: (i) =>
                          setState(() => _chartTabIndex = i),
                      fert: state.params.fert,
                      erosion: state.params.erosion,
                      depth: state.params.depth,
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
                    Text('AI 评估报告',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: aiState.isGenerating
                              ? null
                              : () => _generateReport(),
                          icon: const Icon(Icons.auto_awesome,
                              size: 18),
                          label: const Text('生成报告'),
                        ),
                        if (aiState.isGenerating) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(aiReportProvider.notifier)
                                .cancel(),
                            child: const Text('取消'),
                          ),
                        ],
                        if (aiState.streamContent.isNotEmpty &&
                            !aiState.isGenerating) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(aiReportProvider.notifier)
                                .reset(),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            ref.read(calculatorProvider.notifier).calculate(),
        icon: const Icon(Icons.calculate),
        label: const Text('计算'),
      ),
    );
  }

  void _checkDraft() async {
    final dao = await ref.read(draftDaoProvider.future);
    final age = await dao.getAgeMillis();
    if (age == null || !mounted) return;
    if (age > 300000) {
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
  }

  Future<void> _generateReport() async {
    final service = ref.read(aiConfigProvider);
    final apiKey = await service.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      final configured = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      if (configured != true || !mounted) return;
    }
    if (!mounted) return;
    final srv = ref.read(aiConfigProvider);
    final baseUrl = await srv.readBaseUrl();
    final model = await srv.readModel();
    final enableThinking = await srv.readEnableThinking();
    final reasoningEffort = await srv.readReasoningEffort();
    final preset = await srv.readPreset();
    ref.read(aiReportProvider.notifier).generateReport(
          baseUrl: baseUrl,
          apiKey: await srv.readApiKey() ?? '',
          model: model,
          enableThinking: enableThinking,
          reasoningEffort: reasoningEffort,
          extraThinkingBody: enableThinking ? preset.extraBody : null,
        );
  }

  Future<void> _exportPdf() async {
    final calcState = ref.read(calculatorProvider);
    if (!calcState.isCalculated || calcState.result == null) return;

    setState(() => _pdfExporting = true);
    try {
      final chartImages = await PdfExporter.captureCharts(_chartKeys);
      final bytes = await PdfExporter.generate(
        params: calcState.params,
        result: calcState.result!,
        resilience: calcState.resilience,
        chartImages: chartImages,
        aiReport: ref.read(aiReportProvider).streamContent,
      );

      final fileName =
          'soc-report-${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'SOC 评估报告');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件已准备分享')),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF 已保存: $path')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfExporting = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required void Function(double) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        controller: controller,
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Widget _buildResultRow(String label, String display) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(display,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
  final dynamic result;

  const _ChartCarousel({
    required this.chartKeys,
    required this.tabIndex,
    required this.onTabChanged,
    required this.fert,
    required this.erosion,
    required this.depth,
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
          child: SingleChildScrollView(
              child: ErosionBarChart(fert: widget.fert))),
      RepaintBoundary(
          key: widget.chartKeys[1],
          child: SingleChildScrollView(
              child: DepthLineChart(fert: widget.fert, erosion: widget.erosion))),
      RepaintBoundary(
          key: widget.chartKeys[2],
          child: SingleChildScrollView(
              child: TimeLineChart(fert: widget.fert))),
      RepaintBoundary(
          key: widget.chartKeys[3],
          child: SingleChildScrollView(
              child: AssessmentRadarChart(result: widget.result))),
      RepaintBoundary(
          key: widget.chartKeys[4],
          child: SingleChildScrollView(
              child: PoolPieChart(fert: widget.fert, erosion: widget.erosion))),
      RepaintBoundary(
          key: widget.chartKeys[5],
          child: SingleChildScrollView(
              child: CorrelationScatterChart(fert: widget.fert))),
      RepaintBoundary(
          key: widget.chartKeys[6],
          child: SingleChildScrollView(
              child: ComparisonFillChart(
                  fert: widget.fert, erosion: widget.erosion))),
      RepaintBoundary(
          key: widget.chartKeys[7],
          child: SingleChildScrollView(
              child: HeatmapChart(fert: widget.fert))),
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
              Tab(text: '时间'),
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
          child: IndexedStack(
            index: widget.tabIndex,
            children: charts,
          ),
        ),
      ],
    );
  }
}
