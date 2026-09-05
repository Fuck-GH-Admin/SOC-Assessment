import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soc_app/data/json_io.dart';
import 'package:soc_app/data/pdf_report_storage.dart';
import 'package:soc_app/domain/engine/soc_calculator.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';
import 'package:soc_app/presentation/pages/compare/compare_page.dart';
import 'package:soc_app/presentation/providers/history_provider.dart';
import 'package:soc_app/presentation/providers/record_dao_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final PdfReportStorage _pdfReportStorage = PdfReportStorage();
  bool _exporting = false;
  bool _importing = false;
  final Set<int> _deletingIds = {};
  int? _selectedRecordId;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<File?> _resolvePdfFile(int recordId, String path) async {
    final file = File(path);
    if (await file.exists()) return file;

    try {
      final dao = await ref.read(recordDaoProvider.future);
      await dao.updatePdfPath(recordId, null);
      ref.invalidate(historyListProvider);
      _showMessage('PDF 文件已不存在，已清理这条失效关联。');
    } catch (e) {
      _showMessage('PDF 文件已不存在，但失效关联清理失败：$e');
    }
    return null;
  }

  Future<void> _openOrSharePdf(int recordId, String path) async {
    final file = await _resolvePdfFile(recordId, path);
    if (file == null) return;

    try {
      if (Platform.isAndroid) {
        await Share.shareXFiles([XFile(file.path)], text: 'SOC 评估报告');
        return;
      }

      final opened = await launchUrl(
        Uri.file(file.path, windows: Platform.isWindows),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showMessage('无法调用系统程序打开 PDF，可复制路径后手动打开。');
      }
    } catch (e) {
      _showMessage('打开 PDF 失败：$e');
    }
  }

  Future<void> _openPdfFolder(int recordId, String path) async {
    final file = await _resolvePdfFile(recordId, path);
    if (file == null) return;

    try {
      final opened = await launchUrl(
        Uri.directory(file.parent.path, windows: Platform.isWindows),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showMessage('无法打开报告目录：${file.parent.path}');
      }
    } catch (e) {
      _showMessage('打开报告目录失败：$e');
    }
  }

  Future<void> _copyPdfPath(int recordId, String path) async {
    final file = await _resolvePdfFile(recordId, path);
    if (file == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: file.path));
      _showMessage('PDF 路径已复制');
    } catch (e) {
      _showMessage('复制 PDF 路径失败：$e');
    }
  }

  Future<void> _deleteRecord(int recordId, String? pdfPath) async {
    if (_deletingIds.contains(recordId)) return;
    setState(() => _deletingIds.add(recordId));
    var pdfDeleted = false;
    var unmanagedPdfSkipped = false;
    try {
      if (pdfPath != null && pdfPath.isNotEmpty) {
        try {
          await _pdfReportStorage.deleteIfExists(pdfPath);
          pdfDeleted = true;
        } on ArgumentError {
          unmanagedPdfSkipped = true;
        } catch (e) {
          _showMessage('关联 PDF 删除失败，历史记录已保留。请关闭占用该文件的程序后重试：$e');
          return;
        }
      }

      final dao = await ref.read(recordDaoProvider.future);
      try {
        await dao.delete(recordId);
      } catch (e) {
        if (pdfDeleted) {
          try {
            await dao.updatePdfPath(recordId, null);
          } catch (_) {}
        }
        _showMessage('历史记录删除失败：$e');
        return;
      }

      ref.invalidate(historyListProvider);
      _showMessage(
        unmanagedPdfSkipped ? '历史记录已删除；检测到非应用管理路径，原文件未删除。' : '历史记录已删除',
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(recordId));
    }
  }

  Future<void> _renameRecord(int recordId, String? currentLabel) async {
    final controller = TextEditingController(text: currentLabel ?? '');
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('重命名历史记录'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: '记录名称',
              hintText: '留空则恢复默认名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (value == null) return;

      final normalized = value.trim();
      final dao = await ref.read(recordDaoProvider.future);
      await dao.updateLabel(recordId, normalized.isEmpty ? null : normalized);
      ref.invalidate(historyListProvider);
      _showMessage('记录名称已更新');
    } catch (e) {
      _showMessage('记录重命名失败：$e');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showRecordDetails(Map<String, dynamic> record) async {
    final params = record['params'] as CalculationParams;
    final result = record['result'] as CalculationResult;
    final resilience = record['resilience'] as ResilienceResult?;
    final algorithmVersion = record['algorithmVersion'] as int;
    final createdAt = record['createdAt'] as DateTime;
    final pdfPath = record['pdfPath'] as String?;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(record['label'] as String? ?? 'SOC 计算 #${record['id']}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailHeading('记录信息'),
                  _detailRow('创建时间', createdAt.toString().substring(0, 19)),
                  _detailRow('算法版本', 'v$algorithmVersion'),
                  _detailRow('PDF', pdfPath ?? '未生成或未关联'),
                  _detailHeading('输入参数'),
                  _detailRow('施肥处理', params.fert == 'F' ? '施肥' : '不施肥'),
                  _detailRow('侵蚀深度', '${params.erosion} cm'),
                  _detailRow('当前土层', _safeDepthLabel(params.depth)),
                  _detailRow('统一容重', '${params.bd} g/cm³'),
                  _detailRow('pH（辅助）', '${params.ph}'),
                  _detailRow('含水量（辅助）', '${params.wc}%'),
                  _detailRow('黏粉粒（辅助）', '${params.clay}%'),
                  _detailRow('全氮（辅助）', '${params.tn} g/kg'),
                  _detailRow('秸秆生物量', '${params.cropBiomass} kg/ha'),
                  _detailRow('秸秆碳比例', '${params.strawCarbonRatio}'),
                  _detailRow('基础凋落物输入', '${params.litterCarbonInput} kg C/m²'),
                  _detailHeading('当前土层结果'),
                  _detailRow('SOC', '${result.soc} g/kg'),
                  _detailRow('碳库储量', '${result.carbonStorage} kg C/m²'),
                  _detailRow('碳密度', '${result.carbonDensity} kg C/m³'),
                  _detailRow('相对CK碳库差', '${result.netChange} kg C/m²'),
                  _detailRow('相对CK损失率', '${result.lossRate}%'),
                  if (resilience != null) ...[
                    _detailHeading('CK参考剖面差'),
                    _detailRow(
                      '0-20cm碳库',
                      '${resilience.carbonPool020} kg C/m²',
                    ),
                    _detailRow(
                      '0-60cm碳库',
                      '${resilience.carbonPool060} kg C/m²',
                    ),
                    _detailRow(
                      '0-60cm相对CK差',
                      '${resilience.netChange20yr} kg C/m²',
                    ),
                    _detailRow(
                      '0-20cm相对CK差',
                      '${resilience.netChange100yr} kg C/m²',
                    ),
                    _detailRow('状态', resilience.status),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'rename'),
            child: const Text('重命名'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'load'),
            icon: const Icon(Icons.input, size: 18),
            label: const Text('载入参数'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'rename') {
      await _renameRecord(record['id'] as int, record['label'] as String?);
      return;
    }
    if (action != 'load') return;

    final inputErrors = validateInput(params);
    if (inputErrors.isNotEmpty) {
      _showMessage('该历史记录包含无效输入，不能载入：${inputErrors.join('；')}');
      return;
    }

    if (algorithmVersion != kSocAlgorithmVersion) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('旧算法记录'),
          content: Text(
            '此记录使用算法 v$algorithmVersion。载入后只恢复输入参数，'
            '重新计算将使用当前算法 v$kSocAlgorithmVersion，结果可能不同。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续载入'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    Navigator.pop(context, params);
  }

  String _safeDepthLabel(int depthKey) {
    try {
      return depthDefinitionFor(depthKey).label;
    } on ArgumentError {
      return '未知土层键（$depthKey）';
    }
  }

  Widget _detailHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Future<void> _showPdfActions(int recordId, String path) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(Platform.isAndroid ? '分享 PDF' : '打开 PDF'),
              subtitle: Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('打开所在文件夹'),
                onTap: () => Navigator.pop(ctx, 'folder'),
              ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制文件路径'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'open':
        await _openOrSharePdf(recordId, path);
        break;
      case 'folder':
        await _openPdfFolder(recordId, path);
        break;
      case 'copy':
        await _copyPdfPath(recordId, path);
        break;
    }
  }

  Future<void> _exportRecords() async {
    setState(() => _exporting = true);
    try {
      final records = await ref.read(historyListProvider.future);
      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('暂无记录可导出')));
        }
        return;
      }
      final exportList = records
          .map(
            (r) => ExportRecord(
              params: r['params'] as CalculationParams,
              result: r['result'] as CalculationResult,
              resilience: r['resilience'] as ResilienceResult?,
              label: r['label'] as String?,
              createdAt: (r['createdAt'] as DateTime).millisecondsSinceEpoch,
              algorithmVersion: r['algorithmVersion'] as int,
            ),
          )
          .toList();
      final path = await JsonIo.exportToFile(exportList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path != null ? '已导出: $path' : '导出已取消')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未选择文件或无记录')));
        }
        return;
      }
      final dao = await ref.read(recordDaoProvider.future);
      await dao.transaction(() async {
        for (final r in records) {
          await dao.insert(
            params: r.params,
            result: r.result,
            resilience: r.resilience,
            label: r.label,
            createdAt: r.createdAt > 0 ? r.createdAt : null,
            algorithmVersion: r.algorithmVersion,
          );
        }
      });
      ref.invalidate(historyListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功导入 ${records.length} 条记录')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
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
        title: const Text('评估记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: '对比',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparePage()),
            ),
          ),
          IconButton(
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open),
            tooltip: '导入',
            onPressed: _importing || _exporting ? null : _importRecords,
          ),
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            tooltip: '导出',
            onPressed: _exporting || _importing ? null : _exportRecords,
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('暂无评估记录；完成一次计算后自动保存'));
          }
          final wide = MediaQuery.of(context).size.width >= 900;
          if (wide) return _buildWideLayout(records);
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final result = record['result'] as CalculationResult;
              final label = record['label'] as String?;
              final createdAt = record['createdAt'] as DateTime;
              final pdfPath = record['pdfPath'] as String?;
              final recordId = record['id'] as int;
              final algorithmVersion = record['algorithmVersion'] as int;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  onTap: () => _showRecordDetails(record),
                  title: Text(label ?? 'SOC 计算 #$recordId'),
                  subtitle: Text(
                    '${createdAt.toString().substring(0, 16)} | '
                    'SOC: ${result.soc.toStringAsFixed(2)} g/kg | '
                    '算法 v$algorithmVersion'
                    '${pdfPath == null ? '' : '\nPDF 报告已保存'}',
                  ),
                  isThreeLine: pdfPath != null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pdfPath != null && pdfPath.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          tooltip: '查看 PDF 报告',
                          onPressed: () => _showPdfActions(recordId, pdfPath),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除记录',
                        onPressed: _deletingIds.contains(recordId)
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('删除记录'),
                                    content: Text(
                                      pdfPath == null
                                          ? '确定删除这条历史记录吗？此操作不可撤销。'
                                          : '确定删除这条历史记录吗？关联的应用本地 PDF 也会一并删除。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                await _deleteRecord(recordId, pdfPath);
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 桌面端（≥900px）：左侧记录表格 + 右侧详情面板（方案 §评估记录）。
  Widget _buildWideLayout(List<Map<String, dynamic>> records) {
    final theme = Theme.of(context);
    final selected = _selectedRecordId == null
        ? null
        : records.where((r) => r['id'] == _selectedRecordId).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildRecordTable(records, theme)),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: selected == null
              ? Center(
                  child: Text(
                    '选择一条记录查看详情',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : _RecordDetailPanel(
                  record: selected,
                  onDelete: () async {
                    final pdfPath = selected['pdfPath'] as String?;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除记录'),
                        content: Text(
                          pdfPath == null
                              ? '确定删除这条历史记录吗？此操作不可撤销。'
                              : '确定删除这条历史记录吗？关联的应用本地 PDF 也会一并删除。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    await _deleteRecord(
                      selected['id'] as int,
                      pdfPath,
                    );
                    if (mounted) setState(() => _selectedRecordId = null);
                  },
                  onLoad: () async {
                    final params = await _loadRecordParams(selected);
                    if (params != null && mounted) {
                      Navigator.pop(context, params);
                    }
                  },
                  onRename: () => _renameRecord(
                    selected['id'] as int,
                    selected['label'] as String?,
                  ),
                  onPdfActions: () => _showPdfActions(
                    selected['id'] as int,
                    selected['pdfPath'] as String,
                  ),
                ),
        ),
      ],
    );
  }

  /// 从记录提取参数并做与详情弹窗一致的载入校验；供桌面详情面板复用。
  Future<CalculationParams?> _loadRecordParams(
    Map<String, dynamic> record,
  ) async {
    final params = record['params'] as CalculationParams;
    final inputErrors = validateInput(params);
    if (inputErrors.isNotEmpty) {
      _showMessage('该记录包含无效输入，不能载入：${inputErrors.join('；')}');
      return null;
    }
    final algorithmVersion = record['algorithmVersion'] as int;
    if (algorithmVersion != kSocAlgorithmVersion) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('旧算法记录'),
          content: Text(
            '此记录使用算法 v$algorithmVersion。载入后只恢复输入参数，'
            '重新计算将使用当前算法 v$kSocAlgorithmVersion，结果可能不同。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续载入'),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;
    }
    return params;
  }

  Widget _buildRecordTable(
    List<Map<String, dynamic>> records,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: DataTable(
          columnSpacing: 24,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 44,
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('名称')),
            DataColumn(label: Text('施肥')),
            DataColumn(label: Text('侵蚀')),
            DataColumn(label: Text('土层')),
            DataColumn(label: Text('SOC (g/kg)'), numeric: true),
            DataColumn(label: Text('相对CK (kg C/m²)'), numeric: true),
            DataColumn(label: Text('创建时间')),
            DataColumn(label: Text('报告')),
          ],
          rows: [
            for (final record in records)
              DataRow(
                selected: record['id'] == _selectedRecordId,
                onSelectChanged: (_) =>
                    setState(() => _selectedRecordId = record['id'] as int),
                cells: [
                  DataCell(Text(
                    (record['label'] as String?) ??
                        'SOC 计算 #${record['id']}',
                  )),
                  DataCell(Text(
                    (record['params'] as CalculationParams).fert == 'F'
                        ? '施肥'
                        : '未施肥',
                  )),
                  DataCell(Text(
                    '${(record['params'] as CalculationParams).erosion}cm',
                  )),
                  DataCell(Text(
                    _safeDepthLabel(
                      (record['params'] as CalculationParams).depth,
                    ),
                  )),
                  DataCell(Text(
                    (record['result'] as CalculationResult)
                        .soc
                        .toStringAsFixed(2),
                  )),
                  DataCell(Text(
                    (record['result'] as CalculationResult)
                        .netChange
                        .toStringAsFixed(2),
                  )),
                  DataCell(Text(
                    (record['createdAt'] as DateTime)
                        .toString()
                        .substring(0, 16),
                  )),
                  DataCell(
                    (record['pdfPath'] as String?) != null
                        ? const Icon(Icons.picture_as_pdf, size: 18)
                        : const Text('—'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 桌面端右侧详情面板：记录摘要 + 载入/重命名/PDF/删除动作。
class _RecordDetailPanel extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onDelete;
  final VoidCallback onLoad;
  final VoidCallback onRename;
  final VoidCallback onPdfActions;

  const _RecordDetailPanel({
    required this.record,
    required this.onDelete,
    required this.onLoad,
    required this.onRename,
    required this.onPdfActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = record['params'] as CalculationParams;
    final result = record['result'] as CalculationResult;
    final resilience = record['resilience'] as ResilienceResult?;
    final pdfPath = record['pdfPath'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          record['label'] as String? ?? 'SOC 计算 #${record['id']}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '创建于 ${(record['createdAt'] as DateTime).toString().substring(0, 19)}'
          ' · 算法 v${record['algorithmVersion']}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _row(theme, '施肥', params.fert == 'F' ? '施肥' : '未施肥'),
        _row(theme, '侵蚀深度', '${params.erosion} cm'),
        _row(theme, 'SOC', '${result.soc} g/kg'),
        _row(theme, '碳库', '${result.carbonStorage} kg C/m²'),
        _row(theme, '相对CK碳库差', '${result.netChange} kg C/m²'),
        _row(theme, '损失率', '${result.lossRate}%'),
        if (resilience != null) ...[
          _row(theme, '剖面(0-60cm)差', '${resilience.netChange20yr} kg C/m²'),
          _row(theme, '状态', resilience.status),
        ],
        _row(theme, 'PDF', pdfPath ?? '—'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onLoad,
              icon: const Icon(Icons.input, size: 18),
              label: const Text('载入参数'),
            ),
            OutlinedButton.icon(
              onPressed: onRename,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('重命名'),
            ),
            if (pdfPath != null && pdfPath.isNotEmpty)
              OutlinedButton.icon(
                onPressed: onPdfActions,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF'),
              ),
            TextButton.icon(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              label: Text(
                '删除',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '载入只恢复输入参数，重新计算使用当前算法；'
          '完整参数与剖面结果可在记录详情弹窗查看。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
