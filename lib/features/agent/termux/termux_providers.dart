import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_bootstrap.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_command_service.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_daemon_client.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_file_service.dart';

/// The shared daemon client instance.
final termuxDaemonClientProvider = Provider<TermuxDaemonClient>((ref) {
  final client = TermuxDaemonClient();
  ref.onDispose(() => client.disconnect());
  return client;
});

/// Bootstrap service for installing/starting the daemon.
final termuxBootstrapProvider = Provider<TermuxBootstrap>((ref) {
  final client = ref.watch(termuxDaemonClientProvider);
  return TermuxBootstrap(client);
});

/// Command execution service.
final termuxCommandServiceProvider = Provider<TermuxCommandService>((ref) {
  final client = ref.watch(termuxDaemonClientProvider);
  return TermuxCommandService(client);
});

/// File operations service.
final termuxFileServiceProvider = Provider<TermuxFileService>((ref) {
  final client = ref.watch(termuxDaemonClientProvider);
  return TermuxFileService(client);
});

/// Tracks the daemon bootstrap status.
enum DaemonConnectionState {
  unknown,
  checking,
  connected,
  failed,
}

final daemonConnectionStateProvider =
    StateNotifierProvider<DaemonConnectionStateNotifier, DaemonConnectionState>(
  (ref) => DaemonConnectionStateNotifier(ref),
);

class DaemonConnectionStateNotifier extends StateNotifier<DaemonConnectionState> {
  final Ref _ref;

  DaemonConnectionStateNotifier(this._ref) : super(DaemonConnectionState.unknown);

  /// Run bootstrap and update state accordingly.
  Future<DaemonConnectionState> bootstrap() async {
    state = DaemonConnectionState.checking;

    final bootstrap = _ref.read(termuxBootstrapProvider);
    final client = _ref.read(termuxDaemonClientProvider);

    try {
      // Connect to daemon first (whether running or not, this prepares the socket)
      final stream = client.connect();
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await bootstrap.bootstrap();

      if (result.isSuccess) {
        state = DaemonConnectionState.connected;
      } else {
        state = DaemonConnectionState.failed;
      }
    } catch (e) {
      state = DaemonConnectionState.failed;
    }

    return state;
  }

  /// Retry connection.
  Future<void> reconnect() async {
    state = DaemonConnectionState.checking;
    try {
      final bootstrap = _ref.read(termuxBootstrapProvider);
      await bootstrap.reconnect();
      state = DaemonConnectionState.connected;
    } catch (_) {
      state = DaemonConnectionState.failed;
    }
  }
}
