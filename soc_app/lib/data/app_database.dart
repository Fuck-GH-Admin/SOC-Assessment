import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class HistoryRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get params => text()();
  TextColumn get result => text()();
  TextColumn get resilience => text().nullable()();
  TextColumn get label => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Drafts extends Table {
  IntColumn get id => integer()();
  TextColumn get params => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [HistoryRecords, Drafts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'soc_app.db');
    return AppDatabase(NativeDatabase(File(dbPath)));
  }
}
