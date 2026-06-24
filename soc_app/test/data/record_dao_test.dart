import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:soc_app/data/app_database.dart';
import 'package:soc_app/data/record_dao.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/domain/models/resilience_result.dart';

void main() {
  late AppDatabase db;
  late RecordDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = RecordDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('RecordDao', () {
    test('insert and getById', () async {
      final params = CalculationParams(bd: 1.3, ph: 6.5);
      final result = CalculationResult(soc: 12.5, carbonStorage: 45.0);
      final id = await dao.insert(params: params, result: result);
      expect(id, isNonNegative);

      final record = await dao.getById(id);
      expect(record, isNotNull);
      expect((record!['params'] as CalculationParams).bd, 1.3);
      expect((record['params'] as CalculationParams).ph, 6.5);
      expect((record['result'] as CalculationResult).soc, 12.5);
    });

    test('insert with resilience and label', () async {
      final params = CalculationParams(bd: 1.0);
      final result = CalculationResult(soc: 10.0);
      final resilience = ResilienceResult(status: 'stable');
      final id = await dao.insert(
        params: params,
        result: result,
        resilience: resilience,
        label: 'Test Label',
      );
      final record = await dao.getById(id);
      expect((record!['resilience'] as ResilienceResult).status, 'stable');
      expect(record['label'] as String, 'Test Label');
    });

    test('getAll returns all records ordered by createdAt desc', () async {
      for (var i = 0; i < 3; i++) {
        await dao.insert(
          params: CalculationParams(bd: i.toDouble()),
          result: CalculationResult(soc: i.toDouble()),
        );
      }
      final records = await dao.getAll();
      expect(records.length, 3);
    });

    test('delete removes record', () async {
      final id = await dao.insert(
        params: CalculationParams(),
        result: CalculationResult(),
      );
      await dao.delete(id);
      final record = await dao.getById(id);
      expect(record, isNull);
    });

    test('getByIds returns matching records', () async {
      final id1 = await dao.insert(
        params: CalculationParams(bd: 1.0),
        result: CalculationResult(),
      );
      final id2 = await dao.insert(
        params: CalculationParams(bd: 2.0),
        result: CalculationResult(),
      );
      await dao.insert(
        params: CalculationParams(bd: 3.0),
        result: CalculationResult(),
      );

      final records = await dao.getByIds([id1, id2]);
      expect(records.length, 2);
      expect(
        (records[0]['params'] as CalculationParams).bd,
        2.0, // desc order
      );
    });

    test('getLatest returns most recent record', () async {
      await dao.insert(
        params: CalculationParams(bd: 1.0),
        result: CalculationResult(),
      );
      await dao.insert(
        params: CalculationParams(bd: 2.0),
        result: CalculationResult(),
      );

      final latest = await dao.getLatest();
      expect(latest, isNotNull);
      expect((latest!['params'] as CalculationParams).bd, 2.0);
    });

    test('clearAll removes all records', () async {
      await dao.insert(
        params: CalculationParams(),
        result: CalculationResult(),
      );
      await dao.insert(
        params: CalculationParams(),
        result: CalculationResult(),
      );
      await dao.clearAll();
      final records = await dao.getAll();
      expect(records.isEmpty, true);
    });
  });
}
