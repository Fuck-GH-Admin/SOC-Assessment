import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../domain/models/calculation_params.dart';
import '../domain/models/calculation_result.dart';
import '../domain/models/resilience_result.dart';

class ExportRecord {
  final CalculationParams params;
  final CalculationResult result;
  final ResilienceResult? resilience;
  final String? label;
  final int createdAt;
  final int algorithmVersion;

  const ExportRecord({
    required this.params,
    required this.result,
    this.resilience,
    this.label,
    required this.createdAt,
    this.algorithmVersion = 1,
  });

  Map<String, dynamic> toJson() => {
    'params': params.toJson(),
    'result': result.toJson(),
    if (resilience != null) 'resilience': resilience!.toJson(),
    if (label != null) 'label': label,
    'createdAt': createdAt,
    'algorithmVersion': algorithmVersion,
  };

  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    final rawParams = json['params'];
    final rawResult = json['result'];
    final rawResilience = json['resilience'];
    final rawLabel = json['label'];
    if (rawParams is! Map<String, dynamic>) {
      throw const FormatException('记录缺少有效的 params 对象');
    }
    if (rawResult is! Map<String, dynamic>) {
      throw const FormatException('记录缺少有效的 result 对象');
    }
    if (rawResilience != null && rawResilience is! Map<String, dynamic>) {
      throw const FormatException('记录的 resilience 必须为对象');
    }
    if (rawLabel != null && rawLabel is! String) {
      throw const FormatException('记录的 label 必须为字符串');
    }

    final rawCreatedAt = json['createdAt'];
    final rawAlgorithmVersion = json['algorithmVersion'];
    if (rawCreatedAt != null && rawCreatedAt is! num) {
      throw const FormatException('记录的 createdAt 必须为数字');
    }
    if (rawAlgorithmVersion != null && rawAlgorithmVersion is! num) {
      throw const FormatException('记录的 algorithmVersion 必须为数字');
    }
    final createdAt = (rawCreatedAt as num?)?.toInt() ?? 0;
    final algorithmVersion = (rawAlgorithmVersion as num?)?.toInt() ?? 1;
    if (createdAt < 0 || createdAt > 8640000000000000) {
      throw const FormatException('记录的 createdAt 超出支持范围');
    }
    if (algorithmVersion < 1) {
      throw const FormatException('记录的 algorithmVersion 必须大于0');
    }

    return ExportRecord(
      params: CalculationParams.fromJson(rawParams),
      result: CalculationResult.fromJson(rawResult),
      resilience: rawResilience != null
          ? ResilienceResult.fromJson(rawResilience)
          : null,
      label: rawLabel as String?,
      createdAt: createdAt,
      algorithmVersion: algorithmVersion,
    );
  }
}

class JsonIo {
  static const int exportVersion = 2;
  static const int maxImportRecords = 10000;
  static const int maxImportBytes = 20 * 1024 * 1024;

  static Map<String, dynamic> buildExportData(List<ExportRecord> records) => {
    'version': exportVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'records': records.map((r) => r.toJson()).toList(),
  };

  static List<ExportRecord> parseExportData(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > exportVersion) {
      throw const FormatException('不支持的历史记录文件版本');
    }
    final rawRecords = json['records'];
    if (rawRecords is! List<dynamic>) {
      throw const FormatException('历史记录文件缺少 records 数组');
    }
    if (rawRecords.length > maxImportRecords) {
      throw const FormatException('历史记录数量超过导入上限');
    }

    final records = <ExportRecord>[];
    for (var i = 0; i < rawRecords.length; i++) {
      final rawRecord = rawRecords[i];
      if (rawRecord is! Map<String, dynamic>) {
        throw FormatException('第${i + 1}条历史记录不是有效对象');
      }
      try {
        records.add(ExportRecord.fromJson(rawRecord));
      } catch (e) {
        final detail = e is FormatException ? e.message : e.toString();
        throw FormatException('第${i + 1}条历史记录无效：$detail');
      }
    }
    return records;
  }

  static Future<String?> exportToFile(List<ExportRecord> records) async {
    final path = await FilePicker.platform.saveFile(
      fileName: 'soc-export-${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return null;

    final data = buildExportData(records);
    await File(
      path,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return path;
  }

  static Future<List<ExportRecord>?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.single.path!);
    if (await file.length() > maxImportBytes) {
      throw const FormatException('历史记录文件超过20MB导入上限');
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return parseExportData(json);
  }
}
