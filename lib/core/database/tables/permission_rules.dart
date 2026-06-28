import 'package:drift/drift.dart';

/// Stores persisted "always forever" permission rules.
///
/// These rules survive app restarts and are loaded into the permission
/// manager on startup. They have higher priority than default rules
/// (last-match-wins ordering: defaults < drift rules < session rules).
@DataClassName('PermissionRuleRow')
class PermissionRules extends Table {
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
