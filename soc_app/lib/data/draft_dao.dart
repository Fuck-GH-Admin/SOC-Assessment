import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/calculation_params.dart';
import 'app_database.dart';

class DraftDao {
  final AppDatabase _db;

  DraftDao(this._db);

  Future<void> save(CalculationParams params) async {
    await _db.into(_db.drafts).insertOnConflictUpdate(DraftsCompanion.insert(
      id: Value(1),
      params: jsonEncode(params.toJson()),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<CalculationParams?> load() async {
    final row = await _getRow();
    if (row == null) return null;
    return CalculationParams.fromJson(
        jsonDecode(row.params) as Map<String, dynamic>);
  }

  Future<int?> getAgeMillis() async {
    final row = await _getRow();
    if (row == null) return null;
    return DateTime.now().millisecondsSinceEpoch - row.createdAt;
  }

  Future<Draft?> _getRow() async {
    return (_db.select(_db.drafts)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
  }

  Future<void> delete() async {
    await (_db.delete(_db.drafts)
          ..where((t) => t.id.equals(1)))
        .go();
  }
}
