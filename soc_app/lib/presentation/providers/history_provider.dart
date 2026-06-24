import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'record_dao_provider.dart';

final historyListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dao = await ref.watch(recordDaoProvider.future);
  return dao.getAll();
});
