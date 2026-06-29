import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';

/// A function that handles sending a message from the bottom bar.
typedef SendMessageHandler = Future<void> Function(String text);

/// Holds the current send-message handler.
class SendMessageHandlerNotifier extends Notifier<SendMessageHandler?> {
  @override
  SendMessageHandler? build() => null;
}

final sendMessageHandlerProvider =
    NotifierProvider<SendMessageHandlerNotifier, SendMessageHandler?>(
  SendMessageHandlerNotifier.new,
);

/// Whether the bottom bar should be visible.
final bottomBarVisibleProvider = Provider<bool>((ref) {
  final activeTabId = ref.watch(activeTabIdProvider);
  return activeTabId == 'chat' || activeTabId == 'agent';
});
