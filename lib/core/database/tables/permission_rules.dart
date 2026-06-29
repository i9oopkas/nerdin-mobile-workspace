import 'package:drift/drift.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Stores persisted "always forever" permission rules.
///
/// These rules survive app restarts and are loaded into the permission
/// manager on startup. They have higher priority than default rules
/// (last-match-wins ordering: defaults < drift rules < session rules).
@DataClassName('PermissionRuleRow')
class PermissionRules extends Table {
  static final bool _logged = _initLogging();

  static bool _initLogging() {
    DebugLogger.info('PermissionRules table definition loaded', scope: 'database/table');
    return true;
  }
  TextColumn get action => text()();
  TextColumn get resource => text()();
  TextColumn get effect => text()(); // "allow" | "deny" | "ask"
  TextColumn get agentId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {action, resource};

  @override
  String? get tableName => 'permission_rules';
}
