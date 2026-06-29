import 'dart:async';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_definitions.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_daemon_client.dart';

/// Result of a completed command execution.
class CommandResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final String? signal;

  CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    this.signal,
  });

  bool get isSuccess => exitCode == 0;
}

/// A streaming chunk during command execution.
class CommandChunk {
  final String type; // stdout, stderr
  final String data;
  final int seq;

  CommandChunk({required this.type, required this.data, this.seq = 0});
}

/// High-level service for executing shell commands via the Termux daemon.
class TermuxCommandService implements TermuxCommandBackend {
  final TermuxDaemonClient _client;

  TermuxCommandService(this._client);

  /// Execute a shell command and stream its output in real time.
  ///
  /// Returns a [Stream] of [CommandChunk] objects as the command produces
  /// stdout/stderr output. The stream completes when the command exits.
  ///
  /// Throws [DaemonException] if not connected or if the daemon returns an error.
  Stream<CommandChunk> execute({
    required String cmd,
    String? workdir,
    Map<String, String>? env,
    int? timeout,
  }) {
    DebugLogger.info('Executing command: ${cmd.length > 80 ? "${cmd.substring(0, 80)}..." : cmd}', scope: 'termux/command');
    return _client.exec(
      cmd: cmd,
      workdir: workdir,
      env: env,
      timeout: timeout,
    ).map((chunk) {
      if (chunk.type == 'error') {
        throw DaemonException(chunk.data, 'EXEC_ERROR');
      }
      if (chunk.type == 'stdout') {
        DebugLogger.stream('Command stdout: ${chunk.data.length} bytes', scope: 'termux/command');
      } else if (chunk.type == 'stderr') {
        DebugLogger.stream('Command stderr: ${chunk.data.length} bytes', scope: 'termux/command');
      } else if (chunk.type == 'exit') {
        DebugLogger.info('Command exit: ${chunk.exitCode}', scope: 'termux/command', data: {'exitCode': chunk.exitCode});
      }
      return CommandChunk(
        type: chunk.type,
        data: chunk.data,
        seq: chunk.seq,
      );
    });
  }

  /// Execute a command and collect all output into a single result.
  ///
  /// Similar to [execute] but buffers stdout/stderr and returns a
  /// [CommandResult] when the command completes.
  Future<CommandResult> run({
    required String cmd,
    String? workdir,
    Map<String, String>? env,
    int? timeout,
  }) async {
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    int exitCode = -1;
    String? signal;

    try {
      await for (final chunk in execute(
        cmd: cmd,
        workdir: workdir,
        env: env,
        timeout: timeout,
      )) {
        switch (chunk.type) {
          case 'stdout':
            stdoutBuffer.write(chunk.data);
          case 'stderr':
            stderrBuffer.write(chunk.data);
        }
      }
    } on ExitResponse catch (e) {
      // Handle exit caught via the stream's takeWhile
      // Actually the stream should complete naturally on exit
      // This is a fallback
      exitCode = e.code;
      signal = e.signal;
    } catch (e) {
      if (e is DaemonException) rethrow;
      // If stream ends without exit info, it was successful
    }

    return CommandResult(
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      exitCode: exitCode,
      signal: signal,
    );
  }

  /// Send input to a running command's stdin.
  Future<void> sendInput(String requestId, String data, {bool close = false}) async {
    _client.send(
      type: 'exec_input',
      id: requestId,
      data: data,
      close: close,
    );
  }

  /// Send a signal to a running command.
  Future<void> sendSignal(String requestId, String signal) async {
    _client.send(
      type: 'exec_signal',
      id: requestId,
      signal: signal,
    );
  }

  /// Check if the daemon is responsive.
  Future<bool> isDaemonRunning() => _client.ping();

  @override
  Future<String> runCommand(String cmd, {String? workdir, int? timeout}) async {
    try {
      final result = await run(cmd: cmd, workdir: workdir, timeout: timeout);
      final output = StringBuffer();
      if (result.stdout.isNotEmpty) {
        output.writeln('STDOUT:');
        output.writeln(result.stdout.trim());
      }
      if (result.stderr.isNotEmpty) {
        output.writeln('STDERR:');
        output.writeln(result.stderr.trim());
      }
      if (result.signal != null) {
        output.writeln('Exit code: ${result.exitCode} (signal: ${result.signal})');
      } else {
        output.writeln('Exit code: ${result.exitCode}');
      }
      return output.toString().trim();
    } catch (e) {
      return 'Error: $e';
    }
  }
}
