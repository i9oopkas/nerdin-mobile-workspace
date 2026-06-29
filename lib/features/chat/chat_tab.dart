import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_client.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_event.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_providers.dart';
import 'package:nerdin_mobile_workspace/features/chat/chat_tab_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/bottom_bar_providers.dart';

/// The new chat tab widget — minimal replacement for the OWUI ChatPage.
///
/// Designed as a tab-compatible widget (no Scaffold) that uses [LlmClient]
/// directly for streaming chat completions. Registers a send-message handler
/// with the workspace [BottomBar] via [sendMessageHandlerProvider].
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _scrollController = ScrollController();
  StreamSubscription<LlmEvent>? _streamSub;

  @override
  void initState() {
    super.initState();
    // Register send handler after build phase is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sendMessageHandlerProvider.notifier).state = _handleSend;
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _scrollController.dispose();
    // NOTE: Don't null sendMessageHandlerProvider here — Riverpod 3.x forbids
    // modifying providers in dispose(). The handler will be overridden when
    // a new ChatTab registers. The mounted guard in _handleSend prevents
    // stale handler execution.
    super.dispose();
  }

  /// The main send function: sends user message, streams assistant reply.
  Future<void> _handleSend(String text) async {
    if (!mounted) return;
    final notifier = ref.read(chatMessagesProvider.notifier);
    final client = ref.read(llmClientProvider);
    final model = ref.read(selectedModelProvider);

    // Add user message
    notifier.addUser(text);

    // Build message history from current state (excluding streaming message)
    final currentMessages = ref.read(chatMessagesProvider);
    final history = currentMessages
        .where((m) => !m.isStreaming)
        .map((m) => LlmMessage(role: m.role, content: m.content))
        .toList();

    // Start assistant placeholder
    notifier.startAssistant();

    // Stream the response
    final stream = client.sendStreaming(
      messages: history,
      model: model,
    );

    _streamSub?.cancel();
    _streamSub = stream.listen(
      (event) {
        switch (event) {
          case TextDelta(:final text):
            notifier.appendToAssistant(text);
            _scrollToBottom();
          case MessageFinished():
            notifier.finishAssistant();
            _scrollToBottom();
          case LlmErrorEvent(:final error):
            notifier.appendToAssistant(
              '\n\n⚠️ **Error:** $error',
            );
            notifier.finishAssistant();
          case ToolCallDelta():
          // Ignore tool calls in simple chat mode
          case LlmInfoEvent():
          // Ignore info events
        }
      },
      onError: (error) {
        notifier.appendToAssistant(
          '\n\n⚠️ **Connection error:** $error',
        );
        notifier.finishAssistant();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final messages = ref.watch(chatMessagesProvider);

    if (messages.isEmpty) {
      return _buildWelcome(colorScheme);
    }

    return _buildMessageList(messages, colorScheme);
  }

  Widget _buildWelcome(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a message to start a conversation.\n'
              'Messages are sent to the selected model.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages, ColorScheme colorScheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(
          message: message,
          colorScheme: colorScheme,
        );
      },
    );
  }
}

/// A single message bubble in the chat.
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ColorScheme colorScheme;

  const _MessageBubble({
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isStreaming = message.isStreaming;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Role label
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              isUser ? 'You' : 'Assistant',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12).copyWith(
                bottomRight: isUser ? Radius.zero : null,
                bottomLeft: !isUser ? Radius.zero : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContent(message.content, isUser, colorScheme),
                if (isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _StreamingIndicator(colorScheme: colorScheme),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String content, bool isUser, ColorScheme colorScheme) {
    final textColor = isUser
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    // Detect code blocks and render them with monospace
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```');
    if (!codeBlockRegex.hasMatch(content)) {
      // No code blocks — simple text
      return Text(
        content,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          height: 1.4,
        ),
      );
    }

    // Has code blocks — split and render with mixed formatting
    final segments = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in codeBlockRegex.allMatches(content)) {
      // Text before code block
      if (match.start > lastEnd) {
        segments.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
        ));
      }

      // Code block
      final code = match.group(2) ?? '';
      segments.add(WidgetSpan(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isUser
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: textColor.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    // Remaining text after last code block
    if (lastEnd < content.length) {
      segments.add(TextSpan(
        text: content.substring(lastEnd),
        style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
      ));
    }

    return RichText(text: TextSpan(children: segments));
  }
}

/// Animated dots shown while the assistant is streaming.
class _StreamingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;
  const _StreamingIndicator({required this.colorScheme});

  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (1.0 - (t * 4).clamp(0.0, 1.0)) * 0.8;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
