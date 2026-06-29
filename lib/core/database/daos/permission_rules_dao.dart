import 'package:drift/drift.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

import '../app_database.dart';
import '../tables/permission_rules.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_rules.dart' as domain;

part 'permission_rules_dao.g.dart';

/// DAO for persisted "always forever" permission rules.
///
/// Converts between Drift [PermissionRuleRow] and domain [PermissionRule].
@DriftAccessor(tables: [PermissionRules])
class PermissionRulesDao extends DatabaseAccessor<AppDatabase>
    with _$PermissionRulesDaoMixin {
  PermissionRulesDao(super.db);

  /// Load all persisted rules.
  Future<List<domain.PermissionRule>> loadAll() async {
    DebugLogger.storage('getAllAsync', scope: 'database/dao');
    final rows = await select(permissionRules).get();
    return rows.map(_toDomain).toList();
  }

  /// Load all persisted rules for a specific action.
  Future<List<domain.PermissionRule>> loadByAction(String action) async {
    final rows = await (select(permissionRules)
          ..where((t) => t.action.equals(action)))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Save a new "always forever" rule.
  ///
  /// If a rule with the same (action, resource) already exists, it's
  /// silently ignored (ON CONFLICT DO NOTHING behavior).
  Future<void> save(domain.PermissionRule rule) async {
    DebugLogger.storage('insertAsync: ${rule.action} ${rule.resource}', scope: 'database/dao');
    DebugLogger.storage('updateAsync', scope: 'database/dao');
    await into(permissionRules).insertOnConflictUpdate(
      PermissionRulesCompanion.insert(
        action: rule.action,
        resource: rule.resource,
        effect: rule.effect.name,
        agentId: Value(rule.agentId),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Save multiple rules at once in a transaction.
  Future<void> saveAll(List<domain.PermissionRule> rules) async {
    await transaction(() async {
      for (final rule in rules) {
        await save(rule);
      }
    });
  }

  /// Remove a rule by its (action, resource) pair.
  Future<void> remove(String action, String resource) async {
    DebugLogger.storage('deleteAsync', scope: 'database/dao');
    await (delete(permissionRules)
          ..where((t) => t.action.equals(action))
          ..where((t) => t.resource.equals(resource)))
        .go();
  }

  /// Remove all rules for a specific action.
  Future<void> removeByAction(String action) async {
    await (delete(permissionRules)
          ..where((t) => t.action.equals(action)))
        .go();
  }

  /// Remove all persisted rules.
  Future<void> clearAll() async {
    await delete(permissionRules).go();
  }

  /// Convert a Drift [PermissionRuleRow] to a domain [PermissionRule].
  domain.PermissionRule _toDomain(PermissionRuleRow row) {
    return domain.PermissionRule(
      action: row.action,
      resource: row.resource,
      effect: domain.PermissionEffect.values.firstWhere(
        (e) => e.name == row.effect,
        orElse: () => domain.PermissionEffect.ask,
      ),
      agentId: row.agentId,
    );
  }
}
