import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/json_io.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';
import 'package:soc_app/presentation/pages/compare/compare_page.dart';
import 'package:soc_app/presentation/providers/history_provider.dart';
import 'package:soc_app/presentation/providers/record_dao_provider.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _exportRecords() async {
    setState(() => _exporting = true);
    try {
      final records = ref.read(historyListProvider).valueOrNull ?? [];
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无记录可导出')),
          );
        }
        return;
      }
      final exportList = records.map((r) => ExportRecord(
        params: r['params'] as CalculationParams,
        result: r['result'] as CalculationResult,
        resilience: r['resilience'] as ResilienceResult?,
        label: r['label'] as String?,
        createdAt: (r['createdAt'] as DateTime).millisecondsSinceEpoch,
      )).toList();
      final path = await JsonIo.exportToFile(exportList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path != null ? '已导出: $path' : '导出已取消')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importRecords() async {
    setState(() => _importing = true);
    try {
      final records = await JsonIo.importFromFile();
      if (records == null || records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未选择文件或无记录')),
          );
        }
        return;
      }
      final dao = await ref.read(recordDaoProvider.future);
      for (final r in records) {
        await dao.insert(
          params: r.params,
          result: r.result,
          resilience: r.resilience,
          label: r.label,
        );
      }
      ref.invalidate(historyListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${records.length} 条记录')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(historyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: '对比',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ComparePage())),
          ),
          IconButton(
            icon: _importing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_open),
            tooltip: '导入',
            onPressed: _importing ? null : _importRecords,
          ),
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download),
            tooltip: '导出',
            onPressed: _exporting ? null : _exportRecords,
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('暂无历史记录'));
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final result = record['result'] as CalculationResult;
              final label = record['label'] as String?;
              final createdAt = record['createdAt'] as DateTime;

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(label ?? 'SOC 计算 #${record['id']}'),
                  subtitle: Text(
                    '${createdAt.toString().substring(0, 16)} | '
                    'SOC: ${result.soc.toStringAsFixed(2)} g/kg',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref
                          .read(recordDaoProvider.future)
                          .then((dao) =>
                              dao.delete(record['id'] as int));
                      ref.invalidate(historyListProvider);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
