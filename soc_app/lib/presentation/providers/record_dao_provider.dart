import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/record_dao.dart';

import 'database_provider.dart';

final recordDaoProvider = FutureProvider<RecordDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return RecordDao(db);
});
