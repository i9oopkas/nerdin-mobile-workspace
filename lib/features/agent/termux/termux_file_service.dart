import 'dart:async';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_definitions.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_daemon_client.dart';

/// File information returned from the daemon.
class TermuxFileInfo {
  final String name;
  final int size;
  final String mode;
  final bool isDir;
  final String modTime;

  TermuxFileInfo({
    required this.name,
    required this.size,
    required this.mode,
    required this.isDir,
    required this.modTime,
  });
}

/// Result of a read operation.
class TermuxReadResult {
  final String data;
  final int fileSize;
  final bool truncated;

  TermuxReadResult({
    required this.data,
    required this.fileSize,
    required this.truncated,
  });
}

/// High-level file operations via the Termux daemon.
class TermuxFileService implements TermuxFileBackend {
  final TermuxDaemonClient _client;
  final Duration _defaultTimeout;

  TermuxFileService(
    this._client, {
    Duration? defaultTimeout,
  }) : _defaultTimeout = defaultTimeout ?? const Duration(seconds: 10);

  @override
  Future<String> readFile(String path, {int? maxBytes}) async {
    final requestId = 'read_${path.hashCode}';
    final completer = Completer<TermuxReadResult>();
    StreamSubscription<DaemonResponse>? sub;

    sub = _client.send(type: 'read_file', id: requestId, path: path, maxBytes: maxBytes).listen(
      (response) {
        if (response.id != requestId) return;
        if (response is ReadResultResponse) {
          completer.complete(TermuxReadResult(
            data: response.data,
            fileSize: response.size,
            truncated: response.truncated,
          ));
        } else if (response is ErrorResponse) {
          completer.completeError(
            DaemonException(response.message, response.code),
          );
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(DaemonException(e.toString(), 'STREAM_ERROR'));
        }
      },
    );

    try {
      final result = await completer.future.timeout(_defaultTimeout);
      await sub.cancel();
      return result.data;
    } on TimeoutException {
      await sub.cancel();
      throw DaemonException('Read file timed out', 'TIMEOUT');
    }
  }

  @override
  Future<void> writeFile(String path, String data, {String? mode, bool append = false}) async {
    final requestId = 'write_${path.hashCode}';
    final completer = Completer<void>();
    StreamSubscription<DaemonResponse>? sub;

    sub = _client.send(
      type: 'write_file',
      id: requestId,
      path: path,
      data: data,
      mode: mode,
      append: append,
    ).listen(
      (response) {
        if (response.id != requestId) return;
        if (response is WriteResultResponse) {
          if (response.success) {
            completer.complete();
          } else {
            completer.completeError(
              DaemonException(response.error ?? 'Write failed', 'WRITE_ERROR'),
            );
          }
        } else if (response is ErrorResponse) {
          completer.completeError(
            DaemonException(response.message, response.code),
          );
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(DaemonException(e.toString(), 'STREAM_ERROR'));
        }
      },
    );

    try {
      await completer.future.timeout(_defaultTimeout);
      await sub.cancel();
    } on TimeoutException {
      await sub.cancel();
      throw DaemonException('Write file timed out', 'TIMEOUT');
    }
  }

  /// Get file metadata (size, permissions, modification time).
  Future<TermuxFileInfo> stat(String path) async {
    final requestId = 'stat_${path.hashCode}';
    final completer = Completer<TermuxFileInfo>();
    StreamSubscription<DaemonResponse>? sub;

    sub = _client.send(type: 'stat', id: requestId, path: path).listen(
      (response) {
        if (response.id != requestId) return;
        if (response is StatResultResponse) {
          completer.complete(TermuxFileInfo(
            name: response.entry.name,
            size: response.entry.size,
            mode: response.entry.mode,
            isDir: response.entry.isDir,
            modTime: response.entry.modTime,
          ));
        } else if (response is ErrorResponse) {
          completer.completeError(
            DaemonException(response.message, response.code),
          );
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(DaemonException(e.toString(), 'STREAM_ERROR'));
        }
      },
    );

    try {
      final info = await completer.future.timeout(_defaultTimeout);
      await sub.cancel();
      return info;
    } on TimeoutException {
      await sub.cancel();
      throw DaemonException('Stat timed out', 'TIMEOUT');
    }
  }

  /// List directory contents.
  Future<List<DaemonFileEntry>> listDir(String path) async {
    final requestId = 'list_${path.hashCode}';
    final completer = Completer<List<DaemonFileEntry>>();
    StreamSubscription<DaemonResponse>? sub;

    sub = _client.send(type: 'list_dir', id: requestId, path: path).listen(
      (response) {
        if (response.id != requestId) return;
        if (response is DirListResponse) {
          completer.complete(response.entries);
        } else if (response is ErrorResponse) {
          completer.completeError(
            DaemonException(response.message, response.code),
          );
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(DaemonException(e.toString(), 'STREAM_ERROR'));
        }
      },
    );

    try {
      final entries = await completer.future.timeout(_defaultTimeout);
      await sub.cancel();
      return entries;
    } on TimeoutException {
      await sub.cancel();
      throw DaemonException('List dir timed out', 'TIMEOUT');
    }
  }
}
