import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/app_database.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.create();
  ref.onDispose(() => db.close());
  return db;
});
