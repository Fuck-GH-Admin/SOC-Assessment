import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';
import 'package:soc_app/presentation/providers/history_provider.dart';
import 'package:soc_app/presentation/widgets/charts/comparison_radar_chart.dart';

class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key});

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  final List<int> _selectedIds = [];

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(historyListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('记录对比')),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('暂无历史记录'));
          }
          final recordsById = {
            for (final record in records) record['id'] as int: record,
          };
          final selected = _selectedIds
              .map((id) => recordsById[id])
              .whereType<Map<String, dynamic>>()
              .toList();

          return Column(
            children: [
              Expanded(
                flex: selected.length >= 2 ? 2 : 1,
                child: _buildRecordList(records),
              ),
              if (selected.length >= 2)
                Expanded(flex: 3, child: _buildComparisonView(selected)),
            ],
          );
        },
      ),
    );
  }

  static const _paramLabels = {
    'fert': '施肥',
    'erosion': '侵蚀(cm)',
    'depth': '土层',
    'bd': '容重(g/cm^3)',
    'ph': 'pH（辅助）',
    'wc': '含水（辅助，%）',
    'clay': '黏粉粒（辅助，%）',
    'tn': '全氮（辅助，g/kg）',
    'cropBiomass': '秸秆生物量(kg/ha)',
    'strawCarbonRatio': '秸秆碳比例',
    'litterCarbonInput': '基础凋落物(kg C/m^2)',
  };

  static const _resultLabels = {
    'soc': 'SOC(g/kg)',
    'carbonStorage': '当前土层碳储量(kg/m^2)',
    'carbonDensity': '当前土层碳密度(kg/m^3)',
    'netChange': '当前土层相对CK碳库差(kg/m^2)',
    'recoveryRate': '当前土层差值/20年折算代理(kg/m^2/yr)',
    'lossRate': '当前土层相对CK损失率(%)',
  };

  Widget _buildRecordList(List<Map<String, dynamic>> records) {
    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final id = record['id'] as int;
        final result = record['result'] as CalculationResult;
        final label = record['label'] as String?;
        final createdAt = record['createdAt'] as DateTime;
        final checked = _selectedIds.contains(id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: CheckboxListTile(
            value: checked,
            title: Text(label ?? 'SOC 计算 #$id'),
            subtitle: Text(
              '${createdAt.toString().substring(0, 16)} | '
              'SOC: ${result.soc.toStringAsFixed(2)} g/kg',
              style: const TextStyle(fontSize: 12),
            ),
            onChanged: (v) {
              if (v == true && _selectedIds.length >= 5) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('最多同时选择 5 条记录')));
                return;
              }
              setState(() {
                if (v == true) {
                  _selectedIds.add(id);
                } else {
                  _selectedIds.remove(id);
                }
              });
            },
            secondary: CircleAvatar(
              backgroundColor: _colorForIndex(_selectedIds.indexOf(id)),
              radius: 14,
              child: checked
                  ? Text(
                      '${_selectedIds.indexOf(id) + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonView(List<Map<String, dynamic>> records) {
    final algorithmVersions = records
        .map((r) => r['algorithmVersion'] as int)
        .toSet();
    final mixedAlgorithms = algorithmVersions.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mixedAlgorithms)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('所选记录使用了不同算法版本。数值可供追溯，但不应直接作横向结论。'),
              ),
            ),
          Text('参数对比', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildParamTable(records),
          const SizedBox(height: 16),
          Text('结果对比', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildResultTable(records),
          const SizedBox(height: 16),
          Text('雷达图对比', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (records.length > 2)
            const Text(
              '提示：当前雷达图仅展示前两条记录，完整数值请以表格为准。',
              style: TextStyle(fontSize: 12),
            ),
          if (mixedAlgorithms)
            const Text('算法版本不一致，已隐藏雷达图。')
          else
            SizedBox(
              height: 320,
              child: ComparisonRadarChart(
                result1: records[0]['result'] as CalculationResult,
                result2: records[1]['result'] as CalculationResult,
                label1: records[0]['label'] as String? ?? '#1',
                label2: records[1]['label'] as String? ?? '#2',
              ),
            ),
          if (records.length >= 2 &&
              records.any((r) => r['resilience'] != null)) ...[
            const SizedBox(height: 16),
            Text(
              'CK参考剖面差与情景对比',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildResilienceTable(records),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildParamTable(List<Map<String, dynamic>> records) {
    final headers = [
      '参数',
      ...records.map((r) => r['label'] as String? ?? '#${r['id']}'),
    ];
    final rows = <List<String>>[];
    rows.add(['算法版本', ...records.map((r) => 'v${r['algorithmVersion']}')]);
    for (final entry in _paramLabels.entries) {
      final row = [entry.value];
      for (final r in records) {
        final params = r['params'] as CalculationParams;
        final v = _paramValue(params, entry.key);
        row.add(v);
      }
      rows.add(row);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: headers
            .map(
              (h) => DataColumn(
                label: Text(
                  h,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (cells) => DataRow(
                cells: cells
                    .map(
                      (c) => DataCell(
                        Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildResultTable(List<Map<String, dynamic>> records) {
    final headers = [
      '指标',
      ...records.map((r) => r['label'] as String? ?? '#${r['id']}'),
    ];
    final rows = <List<String>>[];
    for (final entry in _resultLabels.entries) {
      final row = [entry.value];
      for (final r in records) {
        final result = r['result'] as CalculationResult;
        final v = _resultValue(result, entry.key);
        row.add(v);
      }
      rows.add(row);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: headers
            .map(
              (h) => DataColumn(
                label: Text(
                  h,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (cells) => DataRow(
                cells: cells
                    .map(
                      (c) => DataCell(
                        Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildResilienceTable(List<Map<String, dynamic>> records) {
    final resilienceLabels = {
      'carbonPool_0_20': '碳库0-20(kg/m^2)',
      'carbonPool_0_60': '剖面碳库(kg/m^2)',
      'netChange_20yr': '0-60相对CK差·源文档20年口径(kg/m^2)',
      'netChange_100yr': '0-20相对CK差·源文档100年口径(kg/m^2)',
      'recoveryRate_annual': '0-60差值/20年折算代理(kg/m^2/yr)',
      'status': '相对CK状态',
    };

    final headers = [
      '指标',
      ...records.map((r) => r['label'] as String? ?? '#${r['id']}'),
    ];
    final rows = <List<String>>[];
    for (final entry in resilienceLabels.entries) {
      final row = [entry.value];
      for (final r in records) {
        final res = r['resilience'] as ResilienceResult?;
        if (res == null) {
          row.add('--');
        } else {
          final v = _resilienceValue(res, entry.key);
          row.add(v);
        }
      }
      rows.add(row);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: headers
            .map(
              (h) => DataColumn(
                label: Text(
                  h,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (cells) => DataRow(
                cells: cells
                    .map(
                      (c) => DataCell(
                        Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  String _paramValue(CalculationParams p, String key) {
    switch (key) {
      case 'fert':
        return p.fert == 'F' ? '施肥' : '不施肥';
      case 'erosion':
        return p.erosion.toString();
      case 'depth':
        try {
          return depthDefinitionFor(p.depth).label;
        } on ArgumentError {
          return '未知土层键(${p.depth})';
        }
      case 'bd':
        return p.bd.toStringAsFixed(2);
      case 'ph':
        return p.ph.toStringAsFixed(1);
      case 'wc':
        return '${p.wc.toStringAsFixed(1)}%';
      case 'clay':
        return '${p.clay.toStringAsFixed(1)}%';
      case 'tn':
        return p.tn.toStringAsFixed(2);
      case 'cropBiomass':
        return p.cropBiomass.toStringAsFixed(0);
      case 'strawCarbonRatio':
        return p.strawCarbonRatio.toStringAsFixed(3);
      case 'litterCarbonInput':
        return p.litterCarbonInput.toStringAsFixed(3);
      default:
        return '--';
    }
  }

  String _resultValue(CalculationResult r, String key) {
    switch (key) {
      case 'soc':
        return r.soc.toStringAsFixed(2);
      case 'carbonStorage':
        return r.carbonStorage.toStringAsFixed(2);
      case 'carbonDensity':
        return r.carbonDensity.toStringAsFixed(2);
      case 'netChange':
        return r.netChange.toStringAsFixed(2);
      case 'recoveryRate':
        return r.recoveryRate.toStringAsFixed(3);
      case 'lossRate':
        return '${r.lossRate.toStringAsFixed(1)}%';
      default:
        return '--';
    }
  }

  String _resilienceValue(ResilienceResult r, String key) {
    switch (key) {
      case 'carbonPool_0_20':
        return r.carbonPool020.toStringAsFixed(2);
      case 'carbonPool_0_60':
        return r.carbonPool060.toStringAsFixed(2);
      case 'netChange_20yr':
        return r.netChange20yr.toStringAsFixed(2);
      case 'netChange_100yr':
        return r.netChange100yr.toStringAsFixed(2);
      case 'recoveryRate_annual':
        return r.recoveryRateAnnual.toStringAsFixed(3);
      case 'status':
        return r.status;
      default:
        return '--';
    }
  }

  Color _colorForIndex(int index) {
    const colors = [
      Color(0xFF4A9EFF),
      Color(0xFFFF6B6B),
      Color(0xFF50C878),
      Color(0xFFFFD700),
      Color(0xFF9B59B6),
    ];
    return index >= 0 && index < colors.length ? colors[index] : Colors.grey;
  }
}
