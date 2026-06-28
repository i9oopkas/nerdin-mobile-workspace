import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/database/app_database.dart';

/// Provides the single AppDatabase instance used for local persistence
/// (currently just the agent permission rules).
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  // Using a default server ID since server auth is removed.
  // The AppDatabase is created once and kept alive.
  return AppDatabase.forServer('default');
});
