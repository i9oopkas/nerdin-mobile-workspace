import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/database/app_database.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Provides the single AppDatabase instance used for local persistence
/// (currently just the agent permission rules).
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  DebugLogger.info('appDatabaseProvider instantiated', scope: 'database/provider');
  // Using a default server ID since server auth is removed.
  // The AppDatabase is created once and kept alive.
  return AppDatabase.forServer('default');
});
