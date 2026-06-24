import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/draft_dao.dart';

import 'database_provider.dart';

final draftDaoProvider = FutureProvider<DraftDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return DraftDao(db);
});
