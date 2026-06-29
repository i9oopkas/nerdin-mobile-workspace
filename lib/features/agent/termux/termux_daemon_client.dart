import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// Possible response types from the daemon.
sealed class DaemonResponse {
  final String type;
  final String? id;
  DaemonResponse(this.type, this.id);
}

class StdoutResponse extends DaemonResponse {
  final String data;
  final int seq;
  StdoutResponse({required String id, required this.data, required this.seq})
      : super('stdout', id);
}

class StderrResponse extends DaemonResponse {
  final String data;
  final int seq;
  StderrResponse({required String id, required this.data, required this.seq})
      : super('stderr', id);
}

class ExitResponse extends DaemonResponse {
  final int code;
  final String? signal;
  ExitResponse({required String id, required this.code, this.signal})
      : super('exit', id);
}

class ReadResultResponse extends DaemonResponse {
  final String data;
  final int size;
  final bool truncated;
  ReadResultResponse({
    required String id,
    required this.data,
    required this.size,
    required this.truncated,
  }) : super('read_result', id);
}

class WriteResultResponse extends DaemonResponse {
  final bool success;
  final String? error;
  WriteResultResponse({required String id, required this.success, this.error})
      : super('write_result', id);
}

class StatResultResponse extends DaemonResponse {
  final DaemonFileEntry entry;
  StatResultResponse({required String id, required this.entry})
      : super('stat_result', id);
}

class DirListResponse extends DaemonResponse {
  final List<DaemonFileEntry> entries;
  DirListResponse({required String id, required this.entries})
      : super('dir_list', id);
}

class SessionCreatedResponse extends DaemonResponse {
  final String sessionId;
  SessionCreatedResponse({required String id, required this.sessionId})
      : super('session_created', id);
}

class SessionListResponse extends DaemonResponse {
  final List<DaemonSessionInfo> sessions;
  SessionListResponse({required String id, required this.sessions})
      : super('session_list', id);
}

class PongResponse extends DaemonResponse {
  final String version;
  final String uptime;
  PongResponse({required this.version, required this.uptime})
      : super('pong', null);
}

class ErrorResponse extends DaemonResponse {
  final String message;
  final String code;
  ErrorResponse({required String id, required this.message, required this.code})
      : super('error', id);
}

class DaemonFileEntry {
  final String name;
  final int size;
  final String mode;
  final bool isDir;
  final String modTime;

  DaemonFileEntry({
    required this.name,
    required this.size,
    required this.mode,
    required this.isDir,
    required this.modTime,
  });

  factory DaemonFileEntry.fromJson(Map<String, dynamic> json) =>
      DaemonFileEntry(
        name: json['name'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        mode: json['mode'] as String? ?? '',
        isDir: json['is_dir'] as bool? ?? false,
        modTime: json['mod_time'] as String? ?? '',
      );
}

class DaemonSessionInfo {
  final String id;
  final String cmd;
  final String status;
  final String startedAt;

  DaemonSessionInfo({
    required this.id,
    required this.cmd,
    required this.status,
    required this.startedAt,
  });

  factory DaemonSessionInfo.fromJson(Map<String, dynamic> json) =>
      DaemonSessionInfo(
        id: json['id'] as String? ?? '',
        cmd: json['cmd'] as String? ?? '',
        status: json['status'] as String? ?? '',
        startedAt: json['started_at'] as String? ?? '',
      );
}

/// Exception thrown when the daemon returns an error response.
class DaemonException implements Exception {
  final String message;
  final String code;
  DaemonException(this.message, this.code);
  @override
  String toString() => 'DaemonException($code): $message';
}

/// Low-level TCP client for the Termux Go daemon.
class TermuxDaemonClient {
  final String host;
  final int port;
  Socket? _socket;
  StreamController<DaemonResponse>? _responseController;
  bool _connected = false;
  int _requestId = 0;
  Completer<void>? _connectCompleter;

  TermuxDaemonClient({this.host = '127.0.0.1', this.port = 64735});

  bool get isConnected => _connected;

  /// Connect to the daemon. Returns a stream of all responses.
  Stream<DaemonResponse> connect() {
    _responseController = StreamController<DaemonResponse>.broadcast();
    _connectCompleter = Completer<void>();

    DebugLogger.info('Daemon client connecting', scope: 'termux/daemon');
    Socket.connect(host, port).then((socket) {
      _socket = socket;
      _connected = true;
      DebugLogger.info('Daemon client connected', scope: 'termux/daemon');
      _connectCompleter?.complete();

      socket
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim().isEmpty) return;
          try {
            final json = jsonDecode(line.trim()) as Map<String, dynamic>;
            final response = _parseResponse(json);
            if (response != null) {
              _responseController?.add(response);
              DebugLogger.stream('Daemon recv: ${response.runtimeType}', scope: 'termux/daemon');
            }
          } catch (e) {
            // Skip malformed lines
          }
        },
        onError: (error) {
          _connected = false;
          DebugLogger.error('Daemon error', error: error, scope: 'termux/daemon');
          _responseController?.addError(error);
        },
        onDone: () {
          _connected = false;
          _responseController?.close();
        },
      );
    }).catchError((error) {
      _connected = false;
      DebugLogger.error('Daemon error', error: error, scope: 'termux/daemon');
      _connectCompleter?.completeError(error);
      _responseController?.addError(error);
    });

    return _responseController!.stream;
  }

  /// Send a JSON request to the daemon.
  void sendRequest(Map<String, dynamic> request) {
    if (!_connected || _socket == null) {
      throw DaemonException('Not connected to daemon', 'NOT_CONNECTED');
    }
    final line = jsonEncode(request) + '\n';
    _socket!.write(line);
    DebugLogger.stream('Daemon send: ${jsonEncode(request).length} bytes', scope: 'termux/daemon');
  }

  /// Send a typed request and return the response stream.
  Stream<DaemonResponse> send({
    required String type,
    String? id,
    String? cmd,
    String? path,
    String? data,
    String? workdir,
    Map<String, String>? env,
    int? timeout,
    bool? close,
    String? signal,
    int? maxBytes,
    String? mode,
    bool? append,
    String? action,
    String? sessionId,
  }) {
    final requestId = id ?? 'req_${++_requestId}';
    final request = <String, dynamic>{
      'type': type,
      'id': requestId,
    };
    if (cmd != null) request['cmd'] = cmd;
    if (path != null) request['path'] = path;
    if (data != null) request['data'] = data;
    if (workdir != null) request['workdir'] = workdir;
    if (env != null) request['env'] = env;
    if (timeout != null) request['timeout'] = timeout;
    if (close != null) request['close'] = close;
    if (signal != null) request['signal'] = signal;
    if (maxBytes != null) request['max_bytes'] = maxBytes;
    if (mode != null) request['mode'] = mode;
    if (append != null) request['append'] = append;
    if (action != null) request['action'] = action;
    if (sessionId != null) request['session_id'] = sessionId;

    sendRequest(request);
    return _responseController!.stream;
  }

  /// Send an exec command and get a Stream of its output chunks.
  Stream<ExecChunk> exec({
    required String cmd,
    String? workdir,
    Map<String, String>? env,
    int? timeout,
  }) {
    final requestId = 'exec_${++_requestId}';
    
    send(
      type: 'exec',
      id: requestId,
      cmd: cmd,
      workdir: workdir,
      env: env,
      timeout: timeout,
    );

    // Filter and transform the response stream for this request ID
    return _responseController!.stream
        .where((r) => r.id == requestId)
        .map((r) {
      if (r is StdoutResponse) {
        return ExecChunk(type: 'stdout', data: r.data, seq: r.seq);
      } else if (r is StderrResponse) {
        return ExecChunk(type: 'stderr', data: r.data, seq: r.seq);
      } else if (r is ExitResponse) {
        return ExecChunk(
          type: 'exit',
          exitCode: r.code,
          signal: r.signal,
        );
      } else if (r is ErrorResponse) {
        return ExecChunk(
          type: 'error',
          data: r.message,
          exitCode: -1,
        );
      }
      return ExecChunk(type: 'unknown', data: '');
    }).takeWhile((chunk) => chunk.type != 'exit' && chunk.type != 'error');
  }

  /// Check if daemon is running by sending a ping.
  Future<bool> ping() async {
    try {
      if (!_connected) return false;
      final completer = Completer<bool>();
      final sub = _responseController!.stream.where((r) => r is PongResponse).listen((_) {
        if (!completer.isCompleted) completer.complete(true);
      });
      sendRequest({'type': 'ping', 'id': 'ping_1'});
      final result = await completer.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Close the connection.
  Future<void> disconnect() async {
    DebugLogger.info('Daemon client disconnected', scope: 'termux/daemon');
    _connected = false;
    await _socket?.close();
    await _responseController?.close();
    _socket = null;
    _responseController = null;
  }

  DaemonResponse? _parseResponse(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final id = json['id'] as String?;

    switch (type) {
      case 'stdout':
        return StdoutResponse(
          id: id ?? '',
          data: json['data'] as String? ?? '',
          seq: (json['seq'] as num?)?.toInt() ?? 0,
        );
      case 'stderr':
        return StderrResponse(
          id: id ?? '',
          data: json['data'] as String? ?? '',
          seq: (json['seq'] as num?)?.toInt() ?? 0,
        );
      case 'exit':
        return ExitResponse(
          id: id ?? '',
          code: (json['code'] as num?)?.toInt() ?? -1,
          signal: json['signal'] as String?,
        );
      case 'read_result':
        return ReadResultResponse(
          id: id ?? '',
          data: json['data'] as String? ?? '',
          size: (json['size'] as num?)?.toInt() ?? 0,
          truncated: json['truncated'] as bool? ?? false,
        );
      case 'write_result':
        return WriteResultResponse(
          id: id ?? '',
          success: json['success'] as bool? ?? false,
          error: json['error'] as String?,
        );
      case 'stat_result':
        final entry = json['entry'] as Map<String, dynamic>?;
        return StatResultResponse(
          id: id ?? '',
          entry: DaemonFileEntry.fromJson(entry ?? {}),
        );
      case 'dir_list':
        final entries = (json['entries'] as List<dynamic>?)?.map((e) =>
            DaemonFileEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        return DirListResponse(id: id ?? '', entries: entries);
      case 'session_created':
        return SessionCreatedResponse(
          id: id ?? '',
          sessionId: json['session_id'] as String? ?? '',
        );
      case 'session_list':
        final sessions = (json['sessions'] as List<dynamic>?)?.map((s) =>
            DaemonSessionInfo.fromJson(s as Map<String, dynamic>)).toList() ?? [];
        return SessionListResponse(id: id ?? '', sessions: sessions);
      case 'pong':
        return PongResponse(
          version: json['version'] as String? ?? '',
          uptime: json['uptime'] as String? ?? '',
        );
      case 'error':
        return ErrorResponse(
          id: id ?? '',
          message: json['message'] as String? ?? '',
          code: json['code'] as String? ?? 'UNKNOWN',
        );
      default:
        return null;
    }
  }
}

/// A single chunk of output from a running command.
class ExecChunk {
  final String type; // stdout, stderr, exit, error
  final String data;
  final int seq;
  final int? exitCode;
  final String? signal;

  ExecChunk({
    required this.type,
    this.data = '',
    this.seq = 0,
    this.exitCode,
    this.signal,
  });
}
