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

  const ExportRecord({
    required this.params,
    required this.result,
    this.resilience,
    this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'params': params.toJson(),
    'result': result.toJson(),
    if (resilience != null) 'resilience': resilience!.toJson(),
    if (label != null) 'label': label,
    'createdAt': createdAt,
  };

  factory ExportRecord.fromJson(Map<String, dynamic> json) =>
      ExportRecord(
        params: CalculationParams.fromJson(
            json['params'] as Map<String, dynamic>),
        result: CalculationResult.fromJson(
            json['result'] as Map<String, dynamic>),
        resilience: json['resilience'] != null
            ? ResilienceResult.fromJson(
                json['resilience'] as Map<String, dynamic>)
            : null,
        label: json['label'] as String?,
        createdAt: json['createdAt'] as int? ?? 0,
      );
}

class JsonIo {
  static Future<String?> exportToFile(
      List<ExportRecord> records) async {
    final path = await FilePicker.platform.saveFile(
      fileName:
          'soc-export-${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return null;

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'records': records.map((r) => r.toJson()).toList(),
    };
    await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(data));
    return path;
  }

  static Future<List<ExportRecord>?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final records = (json['records'] as List<dynamic>)
        .map((e) =>
            ExportRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return records;
  }
}
