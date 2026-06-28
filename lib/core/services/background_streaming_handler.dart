import 'dart:async';

import '../utils/debug_logger.dart';

enum BackgroundStreamKind {
  chat('chat'),
  voice('voice');

  const BackgroundStreamKind(this.platformValue);

  final String platformValue;
}

class BackgroundStreamLease {
  const BackgroundStreamLease({
    required this.id,
    required this.kind,
    required this.requiresMicrophone,
    required this.startedAt,
  });

  final String id;
  final BackgroundStreamKind kind;
  final bool requiresMicrophone;
  final DateTime startedAt;

  Map<String, dynamic> toPlatformMap() => {
    'id': id,
    'kind': kind.platformValue,
    'requiresMicrophone': requiresMicrophone,
    'startedAt': startedAt.millisecondsSinceEpoch,
  };
}

List<BackgroundStreamLease> _buildBackgroundStreamLeases(
  List<String> streamIds, {
  required bool requiresMicrophone,
  required BackgroundStreamKind kind,
  required DateTime startedAt,
}) {
  return <BackgroundStreamLease>[
    for (final streamId in streamIds)
      if (streamId != BackgroundStreamingHandler.socketKeepaliveId)
        BackgroundStreamLease(
          id: streamId,
          kind: kind,
          requiresMicrophone: requiresMicrophone,
          startedAt: startedAt,
        ),
  ];
}

/// Handles background streaming continuation for iOS and Android.
///
/// NOTE: Native platform APIs have been removed; this handler only maintains
/// in-memory lease state without native-side background execution.
// TODO: Restore native platform calls when iOS platform APIs are re-added.
class BackgroundStreamingHandler {
  static const String socketKeepaliveId = 'socket-keepalive';

  static BackgroundStreamingHandler? _instance;
  static BackgroundStreamingHandler get instance =>
      _instance ??= BackgroundStreamingHandler._();

  BackgroundStreamingHandler._();

  final Map<String, BackgroundStreamLease> _activeLeases =
      <String, BackgroundStreamLease>{};
  bool _initialized = false;

  Future<void> initialize({
    void Function(String error, String errorType, List<String> streamIds)?
    serviceFailedCallback,
    void Function(int remainingMinutes)? timeLimitApproachingCallback,
    void Function()? microphonePermissionFallbackCallback,
    void Function(List<String> streamIds)? streamsSuspendingCallback,
    void Function()? backgroundTaskExpiringCallback,
    void Function(List<String> streamIds, int estimatedSeconds)?
    backgroundTaskExtendedCallback,
    void Function()? backgroundKeepAliveCallback,
  }) async {
    if (_initialized) return;
    _initialized = true;
    onServiceFailed = serviceFailedCallback;
    onBackgroundTimeLimitApproaching = timeLimitApproachingCallback;
    onMicrophonePermissionFallback = microphonePermissionFallbackCallback;
    onStreamsSuspending = streamsSuspendingCallback;
    onBackgroundTaskExpiring = backgroundTaskExpiringCallback;
    onBackgroundTaskExtended = backgroundTaskExtendedCallback;
    onBackgroundKeepAlive = backgroundKeepAliveCallback;
  }

  void Function(List<String> streamIds)? onStreamsSuspending;
  void Function()? onBackgroundTaskExpiring;
  void Function(List<String> streamIds, int estimatedSeconds)?
  onBackgroundTaskExtended;
  void Function()? onBackgroundKeepAlive;
  bool Function()? shouldContinueInBackground;
  void Function(String error, String errorType, List<String> streamIds)?
  onServiceFailed;
  void Function(int remainingMinutes)? onBackgroundTimeLimitApproaching;
  void Function()? onMicrophonePermissionFallback;

  /// Start background execution for given stream IDs
  Future<void> startBackgroundExecution(
    List<String> streamIds, {
    bool requiresMicrophone = false,
    BackgroundStreamKind kind = BackgroundStreamKind.chat,
  }) async {
    final startedAt = DateTime.now();
    final newLeases = _buildBackgroundStreamLeases(
      streamIds,
      requiresMicrophone: requiresMicrophone,
      kind: kind,
      startedAt: startedAt,
    );
    if (newLeases.isEmpty) return;
    for (final lease in newLeases) {
      _activeLeases[lease.id] = lease;
    }
    DebugLogger.stream(
      'start',
      scope: 'background',
      data: {
        'count': streamIds.length,
        'mic': requiresMicrophone,
        'kind': kind.platformValue,
      },
    );
  }

  /// Stop background execution for given stream IDs
  Future<void> stopBackgroundExecution(List<String> streamIds) async {
    for (final streamId in streamIds) {
      _activeLeases.remove(streamId);
    }
    DebugLogger.stream(
      'stop',
      scope: 'background',
      data: {'count': streamIds.length},
    );
  }

  /// Keep alive the background task
  Future<bool> keepAlive() async {
    if (_activeLeases.isEmpty) return true;
    return true;
  }

  /// Check if background app refresh is enabled (iOS only).
  Future<bool> checkBackgroundRefreshStatus() async {
    return true;
  }

  /// Check if notification permission is granted (Android 13+ only).
  Future<bool> checkNotificationPermission() async {
    return true;
  }

  bool get hasActiveStreams => _activeLeases.isNotEmpty;

  List<String> get activeStreamIds => _activeLeases.keys.toList();

  /// Notify the native layer that local speech recognition is managing the
  /// audio session.
  Future<void> setExternalAudioSessionOwner(bool isExternal) async {
    // no-op without native platform APIs
  }

  void clearAll() {
    _activeLeases.clear();
  }

  /// Reconcile Flutter state with native platform state.
  Future<bool> reconcileState() async {
    return false;
  }
}
