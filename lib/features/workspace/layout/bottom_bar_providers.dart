import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';

/// A function that handles sending a message from the bottom bar.
///
/// Set by [ChatV2] or [AgentTab] when they become active, so the
/// bottom bar can dispatch the user's input to the correct target.
typedef SendMessageHandler = Future<void> Function(String text);

/// Holds the current send-message handler.
///
/// The active chat or agent tab sets this when mounted. The bottom
/// bar reads it when the user taps Send.
final sendMessageHandlerProvider =
    StateProvider<SendMessageHandler?>((ref) => null);

/// Whether the bottom bar should be visible.
///
/// Derived from the active tab — shown when the active tab is
/// "chat" or "agent".
final bottomBarVisibleProvider = Provider<bool>((ref) {
  final activeTabId = ref.watch(activeTabIdProvider);
  return activeTabId == 'chat' || activeTabId == 'agent';
});
