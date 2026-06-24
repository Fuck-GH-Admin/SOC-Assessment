import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/app_database.dart';
import 'package:soc_app/data/record_dao.dart';
import 'package:soc_app/domain/models/calculation_params.dart';
import 'package:soc_app/domain/models/calculation_result.dart';
import 'package:soc_app/presentation/providers/record_dao_provider.dart';
import 'package:soc_app/presentation/providers/history_provider.dart';

void main() {
  group('historyListProvider with corrupted records', () {
    late AppDatabase db;
    late RecordDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = RecordDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getAll skips corrupted records instead of failing', () async {
      await dao.insert(
        params: CalculationParams(bd: 1.0),
        result: CalculationResult(soc: 10.0),
      );
      await dao.insert(
        params: CalculationParams(bd: 2.0),
        result: CalculationResult(soc: 20.0),
      );

      // Inject a corrupted record directly into the database
      await db.into(db.historyRecords).insert(HistoryRecordsCompanion.insert(
        params: '{invalid json',
        result: '{also invalid}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      final records = await dao.getAll();
      // Should return the 2 valid records, skip the corrupted one
      expect(records.length, 2);
    });

    test('getByIds skips corrupted records', () async {
      final id1 = await dao.insert(
        params: CalculationParams(bd: 1.0),
        result: CalculationResult(soc: 10.0),
      );

      // Inject corrupted record
      final id2 = await db.into(db.historyRecords).insert(
        HistoryRecordsCompanion.insert(
          params: '{bad json',
          result: '{bad}',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final records = await dao.getByIds([id1, id2]);
      expect(records.length, 1);
      expect(
        (records.first['params'] as CalculationParams).bd,
        1.0,
      );
    });

    test('provider container invalidates after delete', () async {
      // This tests the historyDeleteProvider pattern
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
        ],
      );
      addTearDown(() => container.dispose());

      final id = await dao.insert(
        params: CalculationParams(bd: 1.0),
        result: CalculationResult(soc: 10.0),
      );

      // Initially one record
      final list1 = await container.read(historyListProvider.future);
      expect(list1.length, 1);

      // Delete and verify invalidation
      await container.read(historyDeleteProvider(id));
      final list2 = await container.read(historyListProvider.future);
      expect(list2.length, 0);
    });
  });
}
