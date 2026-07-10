import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soc_app/data/app_database.dart';
import 'package:soc_app/data/record_dao.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('schema v1 migrates to v3 without losing history records', () async {
    final tempDir = await Directory.systemTemp.createTemp('soc-db-migration-');
    final dbFile = File(p.join(tempDir.path, 'soc_app.db'));
    final rawDb = sqlite.sqlite3.open(dbFile.path);

    rawDb.execute('''
      CREATE TABLE history_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        params TEXT NOT NULL,
        result TEXT NOT NULL,
        resilience TEXT,
        label TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    rawDb.execute('''
      CREATE TABLE drafts (
        id INTEGER NOT NULL PRIMARY KEY,
        params TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    rawDb.execute(
      '''
        INSERT INTO history_records
          (params, result, resilience, label, created_at)
        VALUES (?, ?, NULL, ?, ?);
      ''',
      [
        jsonEncode(const CalculationParams(bd: 1.3).toJson()),
        jsonEncode(const CalculationResult(soc: 12.5).toJson()),
        '迁移前记录',
        1700000000000,
      ],
    );
    rawDb.execute('PRAGMA user_version = 1;');
    rawDb.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    try {
      final dao = RecordDao(db);
      final records = await dao.getAll();

      expect(records, hasLength(1));
      expect(records.single['label'], '迁移前记录');
      expect(records.single['pdfPath'], isNull);
      expect(records.single['algorithmVersion'], 1);

      final id = records.single['id'] as int;
      await dao.updatePdfPath(id, p.join(tempDir.path, 'report.pdf'));
      final migrated = await dao.getById(id);
      expect(migrated!['pdfPath'], endsWith('report.pdf'));
    } finally {
      await db.close();
      await tempDir.delete(recursive: true);
    }
  });

  test('schema v2 migrates to v3 and marks legacy algorithm version', () async {
    final tempDir = await Directory.systemTemp.createTemp('soc-db-migration-');
    final dbFile = File(p.join(tempDir.path, 'soc_app.db'));
    final rawDb = sqlite.sqlite3.open(dbFile.path);

    rawDb.execute('''
      CREATE TABLE history_records (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        params TEXT NOT NULL,
        result TEXT NOT NULL,
        resilience TEXT,
        label TEXT,
        pdf_path TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    rawDb.execute('''
      CREATE TABLE drafts (
        id INTEGER NOT NULL PRIMARY KEY,
        params TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    rawDb.execute(
      '''
        INSERT INTO history_records
          (params, result, resilience, label, pdf_path, created_at)
        VALUES (?, ?, NULL, ?, ?, ?);
      ''',
      [
        jsonEncode(const CalculationParams(bd: 1.4).toJson()),
        jsonEncode(const CalculationResult(soc: 11.5).toJson()),
        'v2记录',
        p.join(tempDir.path, 'legacy.pdf'),
        1700000000000,
      ],
    );
    rawDb.execute('PRAGMA user_version = 2;');
    rawDb.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    try {
      final records = await RecordDao(db).getAll();
      expect(records, hasLength(1));
      expect(records.single['label'], 'v2记录');
      expect(records.single['pdfPath'], endsWith('legacy.pdf'));
      expect(records.single['algorithmVersion'], 1);
    } finally {
      await db.close();
      await tempDir.delete(recursive: true);
    }
  });
}
