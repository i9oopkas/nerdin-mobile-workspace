import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_daemon_client.dart';

/// Status of the Termux daemon bootstrap process.
enum DaemonBootstrapStatus {
  /// Termux is not installed.
  termuxNotInstalled,

  /// Daemon is already running.
  alreadyRunning,

  /// Bootstrap is in progress (installing/starting daemon).
  installing,

  /// Daemon is now ready.
  ready,

  /// Bootstrap failed.
  failed,
}

/// Result of the bootstrap process.
class BootstrapResult {
  final DaemonBootstrapStatus status;
  final String? message;

  BootstrapResult({required this.status, this.message});

  bool get isSuccess =>
      status == DaemonBootstrapStatus.alreadyRunning ||
      status == DaemonBootstrapStatus.ready;
}

/// Manages the lifecycle of the Termux daemon.
///
/// Uses the Kotlin plugin (MethodChannel) to:
/// 1. Check if Termux is installed
/// 2. Send RUN_COMMAND Intent to install/start the daemon
/// 3. Ping the daemon TCP socket to verify it's running
class TermuxBootstrap {
  static const _channel = MethodChannel('nerdin.mobile/termux');
  static const _daemonPort = 64735;

  /// The daemon client to check connectivity.
  final TermuxDaemonClient daemonClient;

  TermuxBootstrap(this.daemonClient);

  /// Check if Termux is installed on the device.
  Future<bool> isTermuxInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isTermuxInstalled') ?? false;
    } on MissingPluginException {
      // Running on non-Android (e.g., test)
      return false;
    }
  }

  /// Check if the daemon TCP socket is responding.
  Future<bool> isDaemonRunning() async {
    try {
      return await daemonClient.ping();
    } catch (_) {
      return false;
    }
  }

  /// Run the full bootstrap: check → install → start → verify.
  ///
  /// Returns a [BootstrapResult] indicating the final status.
  Future<BootstrapResult> bootstrap() async {
    // Step 1: Check if Termux is installed
    final termuxInstalled = await isTermuxInstalled();
    if (!termuxInstalled) {
      return BootstrapResult(
        status: DaemonBootstrapStatus.termuxNotInstalled,
        message: 'Termux is not installed. Install it from F-Droid: '
            'https://f-droid.org/packages/com.termux/',
      );
    }

    // Step 2: Check if daemon is already running
    final running = await isDaemonRunning();
    if (running) {
      return BootstrapResult(
        status: DaemonBootstrapStatus.alreadyRunning,
        message: 'Termux daemon is already running.',
      );
    }

    // Step 3: Install and start the daemon via RUN_COMMAND
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'runCommand',
        {
          'cmd': _installAndStartScript(),
          'arguments': <String>[],
          'workdir': '',
          'stdin': '',
        },
      );

      if (result != null) {
        final exitCode = result['exitCode'] as int? ?? -1;
        final stdout = result['stdout'] as String? ?? '';
        final stderr = result['stderr'] as String? ?? '';

        if (exitCode != 0) {
          return BootstrapResult(
            status: DaemonBootstrapStatus.failed,
            message: 'Daemon installation failed (exit $exitCode):\n'
                'stdout: $stdout\nstderr: $stderr',
          );
        }
      }
    } catch (e) {
      return BootstrapResult(
        status: DaemonBootstrapStatus.failed,
        message: 'Failed to send RUN_COMMAND: $e',
      );
    }

    // Step 4: Wait for daemon to start and verify
    for (var attempt = 0; attempt < 15; attempt++) {
      await Future.delayed(const Duration(seconds: 1));
      final ready = await isDaemonRunning();
      if (ready) {
        return BootstrapResult(
          status: DaemonBootstrapStatus.ready,
          message: 'Termux daemon started successfully.',
        );
      }
    }

    return BootstrapResult(
      status: DaemonBootstrapStatus.failed,
      message: 'Daemon did not become ready within 15 seconds.',
    );
  }

  /// Build the shell script that installs and starts the Termux daemon.
  ///
  /// This script is passed as a single RUN_COMMAND command.
  /// It:
  /// 1. Ensures the daemon directory exists
  /// 2. Downloads or writes the daemon binary
  /// 3. Makes it executable
  /// 4. Starts it in the background
  ///
  /// For now, this is a placeholder that just starts a simple listener
  /// to verify the pipeline works. The actual binary distribution will
  /// be implemented separately.
  String _installAndStartScript() {
    // We use a here-doc script that:
    // 1. Checks if the daemon binary exists at ~/.nerdin/termux-daemon
    // 2. If not, creates the directory and notifies the user
    // 3. Starts the daemon if present
    
    return '''
# Termux Daemon Bootstrap
NERDIN_DIR="\$HOME/.nerdin"
DAEMON_PATH="\$NERDIN_DIR/termux-daemon"
mkdir -p "\$NERDIN_DIR"

if [ ! -f "\$DAEMON_PATH" ]; then
    echo "NERDIN_BOOTSTRAP: Daemon binary not found at \$DAEMON_PATH"
    echo "NERDIN_BOOTSTRAP: Please copy the termux-daemon binary to \$DAEMON_PATH"
    echo "NERDIN_BOOTSTRAP: You can build it with: cd scripts/termux-daemon && GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -o termux-daemon ."
    exit 1
fi

chmod +x "\$DAEMON_PATH"

# Kill any existing instance
pkill -f termux-daemon 2>/dev/null || true
sleep 0.5

# Start daemon
nohup "\$DAEMON_PATH" -port 64735 > "\$NERDIN_DIR/daemon.log" 2>&1 &
echo "NERDIN_BOOTSTRAP: Daemon started with PID \$!"
sleep 1

# Verify it's running
if kill -0 \$! 2>/dev/null; then
    echo "NERDIN_BOOTSTRAP: Daemon is running"
    exit 0
else
    echo "NERDIN_BOOTSTRAP: Daemon failed to start"
    cat "\$NERDIN_DIR/daemon.log" 2>/dev/null || true
    exit 1
fi
'''.trim();
  }

  /// Try to connect to the daemon.
  /// Returns a connected [TermuxDaemonClient] if successful.
  Future<TermuxDaemonClient> connect() async {
    final stream = daemonClient.connect();
    // Wait briefly for connection to establish
    await Future.delayed(const Duration(milliseconds: 500));
    if (!daemonClient.isConnected) {
      throw DaemonException(
        'Failed to connect to Termux daemon on 127.0.0.1:$_daemonPort',
        'CONNECTION_REFUSED',
      );
    }
    return daemonClient;
  }

  /// Reconnect the daemon client.
  Future<void> reconnect() async {
    await daemonClient.disconnect();
    daemonClient.connect();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!daemonClient.isConnected) {
      throw DaemonException(
        'Failed to reconnect to Termux daemon',
        'RECONNECT_FAILED',
      );
    }
  }
}
