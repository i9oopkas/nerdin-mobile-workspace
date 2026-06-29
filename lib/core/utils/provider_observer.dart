import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Custom [ProviderObserver] that logs every provider state change
/// with a partial stack trace, to help debug "Tried to modify a provider
/// while the widget tree was building" errors.
///
/// In debug mode, captures the stack trace at the point of update and
/// logs a compact one-line summary per change. In release mode, no-ops.
base class NerdinProviderObserver extends ProviderObserver {
  const NerdinProviderObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (!kDebugMode) return;

    final provider = context.provider;

    // Build a compact description
    final providerName = provider.name ?? provider.runtimeType.toString();
    final prev = _summarize(previousValue);
    final next = _summarize(newValue);

    // Capture stack to identify caller — skip Riverpod internals
    final stack = StackTrace.current;
    final frames = stack.toString().split('\n');
    // Find the first frame that's NOT from package:flutter_riverpod/
    String? callerFrame;
    for (final f in frames) {
      if (!f.contains('flutter_riverpod') &&
          !f.contains('package:riverpod') &&
          f.contains('package:nerdin_mobile_workspace')) {
        callerFrame = f.trim();
        break;
      }
    }

    final callerInfo = callerFrame ?? 'unknown';
    debugPrint(
      '[ProviderObserver] $providerName: $prev -> $next  (via: $callerInfo)',
    );
  }

  /// Produce a short string summary of a value.
  String _summarize(Object? value) {
    if (value == null) return 'null';
    if (value is AsyncValue) {
      return value.when(
        data: (d) => 'AsyncData(${_truncate(d.toString())})',
        loading: () => 'AsyncLoading',
        error: (e, _) => 'AsyncError(${e.runtimeType})',
      );
    }
    if (value is List) return 'List(${value.length})';
    if (value is Map) return 'Map(${value.length})';
    if (value is String) {
      if (value.isEmpty) return '""';
      return '"${value.length > 40 ? '${value.substring(0, 40)}...' : value}"';
    }
    return _truncate(value.toString());
  }

  String _truncate(String s) {
    if (s.length <= 60) return s;
    return '${s.substring(0, 57)}...';
  }
}
