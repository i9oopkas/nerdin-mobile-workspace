import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// A single message in the chat conversation.
class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  final bool isStreaming;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? role,
    String? content,
    bool? isStreaming,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

/// Notifier managing the list of chat messages for the active conversation.
class ChatMessagesNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  /// Add a user message.
  void addUser(String content) {
    DebugLogger.info('Chat user message: ${content.length} chars', scope: 'chat/provider');
    state = [
      ...state,
      ChatMessage(role: 'user', content: content),
    ];
  }

  /// Append an empty assistant message placeholder (streaming starts).
  void startAssistant() {
    DebugLogger.stream('Chat assistant started', scope: 'chat/provider');
    state = [
      ...state,
      ChatMessage(role: 'assistant', content: '', isStreaming: true),
    ];
  }

  /// Append a text delta to the last assistant message.
  void appendToAssistant(String delta) {
    if (state.isEmpty) return;
    DebugLogger.stream('Chat assistant delta: ${delta.length} chars', scope: 'chat/provider');
    final messages = [...state];
    final last = messages.last;
    if (last.role != 'assistant') return;
    messages[messages.length - 1] = last.copyWith(
      content: last.content + delta,
    );
    state = messages;
  }

  /// Mark the last assistant message as finished (streaming done).
  void finishAssistant() {
    if (state.isEmpty) return;
    DebugLogger.stream('Chat assistant finished', scope: 'chat/provider');
    final messages = [...state];
    final last = messages.last;
    if (last.role != 'assistant') return;
    messages[messages.length - 1] = last.copyWith(isStreaming: false);
    state = messages;
  }

  /// Clear all messages.
  void clear() => state = [];
}

/// Provider for the chat message list.
final chatMessagesProvider =
    NotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  ChatMessagesNotifier.new,
);

/// Whether the assistant is currently streaming a response.
final isChatStreamingProvider = Provider<bool>((ref) {
  final messages = ref.watch(chatMessagesProvider);
  return messages.isNotEmpty && messages.last.isStreaming;
});
