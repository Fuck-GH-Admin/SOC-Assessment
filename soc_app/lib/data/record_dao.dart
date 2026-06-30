import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/calculation_params.dart';
import '../domain/models/calculation_result.dart';
import '../domain/models/resilience_result.dart';
import 'app_database.dart';

class RecordDao {
  final AppDatabase _db;

  RecordDao(this._db);

  Future<int> insert({
    required CalculationParams params,
    required CalculationResult result,
    ResilienceResult? resilience,
    String? label,
  }) =>
      _db.into(_db.historyRecords).insert(HistoryRecordsCompanion.insert(
        params: jsonEncode(params.toJson()),
        result: jsonEncode(result.toJson()),
        resilience: resilience != null
            ? Value(jsonEncode(resilience.toJson()))
            : const Value.absent(),
        label: label != null ? Value(label) : const Value.absent(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

  Future<void> delete(int id) async {
    await (_db.delete(_db.historyRecords)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> deleteByIds(List<int> ids) async {
    await (_db.delete(_db.historyRecords)
          ..where((t) => t.id.isIn(ids)))
        .go();
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final row = await (_db.select(_db.historyRecords)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return _decode(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getByIds(List<int> ids) async {
    final rows = await (_db.select(_db.historyRecords)
          ..where((t) => t.id.isIn(ids))
          ..orderBy(
              [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return _decodeAll(rows);
  }

  Future<List<Map<String, dynamic>>> getAll({
    String? search,
    int offset = 0,
    int? limit,
  }) async {
    var query = _db.select(_db.historyRecords)
      ..orderBy(
          [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

    if (search != null && search.isNotEmpty) {
      query.where((t) => t.label.contains(search));
    }

    // 分页下推到 SQL，避免全表加载到内存再切片
    if (limit != null) {
      query
        ..limit(limit, offset: offset);
    } else if (offset > 0) {
      query
        ..limit(-1, offset: offset);
    }

    final rows = await query.get();
    return _decodeAll(rows);
  }

  Future<Map<String, dynamic>?> getLatest() async {
    final rows = await (_db.select(_db.historyRecords)
          ..orderBy(
              [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    try {
      return _decode(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _db.delete(_db.historyRecords).go();
  }

  List<Map<String, dynamic>> _decodeAll(List<HistoryRecord> rows) {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        result.add(_decode(row));
      } catch (_) {
        // skip corrupted records
      }
    }
    return result;
  }

  Map<String, dynamic> _decode(HistoryRecord row) => {
    'id': row.id,
    'params': CalculationParams.fromJson(
        jsonDecode(row.params) as Map<String, dynamic>),
    'result': CalculationResult.fromJson(
        jsonDecode(row.result) as Map<String, dynamic>),
    'resilience': row.resilience != null
        ? ResilienceResult.fromJson(
            jsonDecode(row.resilience!) as Map<String, dynamic>)
        : null,
    'label': row.label,
    'createdAt': DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  };
}
