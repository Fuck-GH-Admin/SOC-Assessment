import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:soc_app/data/app_database.dart';
import 'package:soc_app/data/draft_dao.dart';
import 'package:soc_app/domain/models/calculation_params.dart';

void main() {
  late AppDatabase db;
  late DraftDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = DraftDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DraftDao', () {
    test('save and load', () async {
      final params = CalculationParams(bd: 1.3, ph: 6.5, wc: 22.0);
      await dao.save(params);

      final loaded = await dao.load();
      expect(loaded, isNotNull);
      expect(loaded!.bd, 1.3);
      expect(loaded.ph, 6.5);
      expect(loaded.wc, 22.0);
    });

    test('overwrite existing draft', () async {
      await dao.save(CalculationParams(bd: 1.0));
      await dao.save(CalculationParams(bd: 2.0));

      final loaded = await dao.load();
      expect(loaded!.bd, 2.0);
    });

    test('load returns null when no draft exists', () async {
      final loaded = await dao.load();
      expect(loaded, isNull);
    });

    test('getAgeMillis returns age after save', () async {
      await dao.save(CalculationParams(bd: 1.3));
      final age = await dao.getAgeMillis();
      expect(age, isNonNegative);
      expect(age, lessThan(5000)); // just saved, <5s
    });

    test('getAgeMillis returns null when no draft', () async {
      final age = await dao.getAgeMillis();
      expect(age, isNull);
    });

    test('delete removes draft', () async {
      await dao.save(CalculationParams(bd: 1.3));
      await dao.delete();
      final loaded = await dao.load();
      expect(loaded, isNull);
    });
  });
}
