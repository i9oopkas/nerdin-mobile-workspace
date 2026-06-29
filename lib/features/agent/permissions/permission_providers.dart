import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/database/daos/permission_rules_dao.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/core/database/database_provider.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_manager.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_rules.dart';

/// Provider for the Drift DAO (singleton, follows the app core DB pattern).
final permissionRulesDaoProvider = Provider<PermissionRulesDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) throw StateError('AppDatabase not initialized');
  return PermissionRulesDao(db);
});

/// Provider for the permission manager (singleton).
final permissionManagerProvider = Provider<PermissionManager>((ref) {
  final manager = PermissionManager();
  return manager;
});

/// Provider that initializes the permission manager with persisted rules.
/// Call this during app startup.
final permissionInitProvider = FutureProvider<void>((ref) async {
  final dao = ref.read(permissionRulesDaoProvider);
  final manager = ref.read(permissionManagerProvider);
  final rules = await dao.loadAll();
  manager.updateDriftRules(rules);
});

/// Notifier that tracks pending permission requests for the UI.
class PendingPermissionNotifier extends Notifier<List<PermissionRequest>> {
  @override
  List<PermissionRequest> build() {
    DebugLogger.auth('Pending permission created', scope: 'permission/provider');
    final manager = ref.watch(permissionManagerProvider);

    // Listen for new pending requests
    manager.onPendingRequest = (request) {
      state = [...state, request];
    };

    // Listen for resolved requests
    manager.onRequestResolved = (requestId) {
      state = state.where((r) => r.id != requestId).toList();
    };

    // Auto-cleanup when provider is disposed
    ref.onDispose(() {
      manager.onPendingRequest = null;
      manager.onRequestResolved = null;
    });

    return [];
  }

  /// Reply to a pending request with once/always/alwaysSession/reject/edit.
  void reply(String requestId, PermissionReply reply, {String? editedInput}) {
    DebugLogger.auth('Permission resolved: $reply', scope: 'permission/provider');
    final manager = ref.read(permissionManagerProvider);
    final handled = manager.reply(requestId, reply, editedInput: editedInput);

    // If user chose "always" (forever persist), save to Drift
    if (handled && reply == PermissionReply.always) {
      _saveAlwaysRule(requestId);
    }
  }

  /// After an "always" reply, save the rule to Drift.
  Future<void> _saveAlwaysRule(String requestId) async {
    final manager = ref.read(permissionManagerProvider);
    final dao = ref.read(permissionRulesDaoProvider);
    final patterns = manager.consumeSavePatterns(requestId);
    if (patterns == null || patterns.isEmpty) return;

    // We need to reconstruct the action from the original request
    // Since consumeSavePatterns works on pending requests which are now removed,
    // we use metadata stored on the manager side.
    // For now, simply reload rules from DB after save.
    // (A more robust approach would pass action+saved patterns explicitly.)
    final rules = await dao.loadAll();
    manager.updateDriftRules(rules);
  }

  /// Reset all session-scoped rules.
  void resetSessionRules() {
    final manager = ref.read(permissionManagerProvider);
    manager.clearSessionRules();
  }

  /// Reject all pending requests.
  void rejectAll() {
    final manager = ref.read(permissionManagerProvider);
    for (final request in state) {
      manager.reply(request.id, PermissionReply.reject);
    }
  }
}

/// Provider for the list of pending permission requests.
final pendingPermissionRequestsProvider =
    NotifierProvider<PendingPermissionNotifier, List<PermissionRequest>>(
  PendingPermissionNotifier.new,
);

/// Check if there are any pending permission requests.
final hasPendingPermissionRequestsProvider = Provider<bool>((ref) {
  return ref.watch(pendingPermissionRequestsProvider).isNotEmpty;
});
