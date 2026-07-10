import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soc_app/data/app_database.dart';
import 'package:soc_app/data/record_dao.dart';
import 'package:soc_app/presentation/providers/calculator_provider.dart';
import 'package:soc_app/presentation/providers/database_provider.dart';
import 'package:soc_app/presentation/providers/history_provider.dart';
import 'package:soc_app/presentation/providers/record_dao_provider.dart';

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

  ProviderContainer createContainer({
    Future<RecordDao> Function()? recordDaoFactory,
  }) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        if (recordDaoFactory != null)
          recordDaoProvider.overrideWith((ref) => recordDaoFactory()),
      ],
    );
  }

  test(
    'rapid duplicate calculate calls create only one history record',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);

      final first = notifier.calculate();
      final second = notifier.calculate();
      await Future.wait([first, second]);

      expect(container.read(calculatorProvider).isCalculated, isTrue);
      expect(await dao.getAll(), hasLength(1));
    },
  );

  test(
    'recalculating unchanged completed parameters does not duplicate history',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);

      await notifier.calculate();
      await notifier.calculate();

      expect(await dao.getAll(), hasLength(1));
      expect(
        container.read(calculatorProvider).warnings,
        contains(contains('未重复写入历史记录')),
      );
    },
  );

  test(
    'editing parameters invalidates an in-flight stale calculation',
    () async {
      final gate = Completer<void>();
      final container = createContainer(
        recordDaoFactory: () async {
          await gate.future;
          return dao;
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);

      final pending = notifier.calculate();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(calculatorProvider).isCalculating, isTrue);

      notifier.updateBd(1.4);
      gate.complete();
      await pending;

      final state = container.read(calculatorProvider);
      expect(state.params.bd, 1.4);
      expect(state.isCalculated, isFalse);
      expect(state.result, isNull);
      expect(await dao.getAll(), isEmpty);
    },
  );

  test('successful calculation invalidates the cached history list', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    expect(await container.read(historyListProvider.future), isEmpty);
    await container.read(calculatorProvider.notifier).calculate();

    final records = await container.read(historyListProvider.future);
    expect(records, hasLength(1));
  });
}
