import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

final _logger = Logger('AppStartup');

/// No-op startup flow. Converted to Notifier so `ref.read(...).notifier.start()` works.
class AppStartupFlow extends Notifier<int> {
  @override
  int build() {
    _init();
    return 0;
  }

  Future<void> _init() async {
    DebugLogger.info('AppStartup: init', scope: 'app/init');
    _logger.info('AppStartupFlow: started');
  }

  /// Called from main.dart after the ProviderScope is ready.
  void start() {
    DebugLogger.info('AppStartup: start', scope: 'app/startup');
    _logger.info('AppStartupFlow: start() called — no-op');
  }
}

final appStartupFlowProvider =
    NotifierProvider<AppStartupFlow, int>(AppStartupFlow.new);

/// Cleans up user-scoped providers (no-op after OWUI removal).
final userScopedProviderCleanupProvider = Provider<void>((ref) {
  // no-op
});
