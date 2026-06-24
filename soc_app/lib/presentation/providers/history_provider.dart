import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'record_dao_provider.dart';

class HistoryListState {
  final List<Map<String, dynamic>> records;
  final bool isLoading;

  const HistoryListState({
    this.records = const [],
    this.isLoading = false,
  });
}

final historyListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dao = await ref.watch(recordDaoProvider.future);
  return dao.getAll();
});

final historyDeleteProvider = FutureProvider.family<void, int>((ref, id) async {
  final dao = await ref.watch(recordDaoProvider.future);
  await dao.delete(id);
  ref.invalidate(historyListProvider);
});
