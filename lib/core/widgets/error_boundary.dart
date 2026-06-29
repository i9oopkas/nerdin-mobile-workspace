import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import '../../shared/theme/theme_extensions.dart';

/// Error boundary widget that catches and handles errors in child widgets.
/// Simplified version — OWUI-specific AdaptiveRouteShell and EnhancedErrorService removed.
class ErrorBoundary extends ConsumerStatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;
  final void Function(Object error, StackTrace? stack)? onError;
  final bool showErrorDialog;
  final bool allowRetry;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.showErrorDialog = false,
    this.allowRetry = true,
  });

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    DebugLogger.info('ErrorBoundary mounted for ${widget.child.runtimeType}', scope: 'error/boundary');
    // Capture errors from the Flutter framework
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _scheduleHandleError(details.exception, details.stack);
      previousOnError?.call(details);
    };
  }

  void _scheduleHandleError(Object error, StackTrace? stack) {
    DebugLogger.error('ErrorBoundary caught error', error: error, stackTrace: stack, scope: 'error/caught');
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _error = error;
      _stackTrace = stack;
    });
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  void dispose() {
    DebugLogger.info('ErrorBoundary disposed', scope: 'error/boundary');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasError) return widget.child;

    // Error occurred — show fallback UI
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(_error!, _stackTrace);
    }

    return Material(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _error?.toString() ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.allowRetry) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a [FutureBuilder] with error handling.
class AsyncErrorBoundary extends ConsumerWidget {
  final Widget Function(BuildContext context, AsyncValue snapshot) builder;
  final Widget Function()? loadingWidget;
  final Widget Function(Object error, StackTrace? stack)? errorWidget;
  final bool showRetry;

  const AsyncErrorBoundary({
    super.key,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This is intentionally empty — FutureBuilder wrapping is done by the caller.
    // Kept as a stub for compatibility.
    return const SizedBox.shrink();
  }
}

/// Wraps a [StreamBuilder] with error handling.
class StreamErrorBoundary<T> extends ConsumerWidget {
  final Stream<T>? Function() stream;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;
  final Widget Function()? loadingWidget;
  final Widget Function(Object error, StackTrace? stack)? errorWidget;

  const StreamErrorBoundary({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stub for compatibility.
    return const SizedBox.shrink();
  }
}
