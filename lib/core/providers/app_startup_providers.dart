import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal startup flow provider.
/// The full OWUI startup (server connection, conversation warmup, socket, etc.)
/// has been removed. This provider exists as a no-op placeholder so existing
/// call sites in main.dart still compile.
class AppStartupFlow {
  void start() {
    // No-op: server-side startup logic removed.
  }
}

final appStartupFlowProvider = Provider<AppStartupFlow>((ref) {
  return AppStartupFlow();
});

/// Cleanup provider stub. The original OWUI implementation invalidated
/// user-scoped providers on sign-out. Since auth is removed, this is a no-op.
final userScopedProviderCleanupProvider = Provider<void>((ref) {
  // No-op: auth cleanup removed.
});
