// Minimal Agent UI — Phase 1e.
//
// Renders the ReAct loop output in a terminal-style scrollable log
// with a persistent input bar at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_providers.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_session.dart';

/// Main agent screen with streaming log and input bar.
class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    DebugLogger.info('AgentScreen mounted', scope: 'agent/ui');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_autoScroll) return;
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

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    DebugLogger.info('Agent send: ${text.length} chars', scope: 'agent/ui');
    ref.read(agentSessionProvider.notifier).startTask(text);
    _scrollToBottom();
  }

  void _handleCancel() {
    DebugLogger.info('Agent cancelled', scope: 'agent/ui');
    ref.read(agentSessionProvider.notifier).cancel();
  }

  void _handleReset() {
    ref.read(agentSessionProvider.notifier).reset();
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(agentSessionProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Agent'),
        centerTitle: false,
        actions: [
          _StatusIndicator(status: session.status),
          const SizedBox(width: 8),
          if (session.status == AgentStatus.streaming ||
              session.status == AgentStatus.executingTools ||
              session.status == AgentStatus.waitingForPermission)
            IconButton(
              icon: const Icon(Icons.stop_rounded),
              tooltip: 'Cancel',
              onPressed: _handleCancel,
            ),
          if (session.isTerminal)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'New task',
              onPressed: _handleReset,
            ),
        ],
      ),
      body: Column(
        children: [
          // Agent event log
          Expanded(
            child: _buildEventLog(session, theme, colorScheme),
          ),
          // Input bar
          _buildInputBar(session, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildEventLog(
    AgentSession session,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (session.status == AgentStatus.idle && session.events.isEmpty) {
      return _buildWelcome(theme, colorScheme);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.position.pixels;
          _autoScroll = (currentScroll >= maxScroll - 50);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: session.events.length + 1, // +1 for summary at end
        itemBuilder: (context, index) {
          if (index == session.events.length) {
            // Terminal summary
            if (session.isTerminal) {
              return _buildTerminalSummary(session, theme, colorScheme);
            }
            return const SizedBox.shrink();
          }

          final event = session.events[index];
          return _buildEventWidget(event, theme, colorScheme);
        },
      ),
    );
  }

  Widget _buildWelcome(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Nerdin Agent',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe a task and the agent will help you\n'
              'read, write, and search files in your project.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _buildSuggestionChip(
              'Find all TODOs in the project',
              theme,
              colorScheme,
            ),
            const SizedBox(height: 8),
            _buildSuggestionChip(
              'Refactor the main app widget',
              theme,
              colorScheme,
            ),
            const SizedBox(height: 8),
            _buildSuggestionChip(
              'List all Dart files in lib/',
              theme,
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(
    String text,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () {
        _inputController.text = text;
        _handleSend();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventWidget(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    switch (event.type) {
      case 'text_delta':
        return _buildTextDelta(event, theme, colorScheme);
      case 'tool_call':
        return _buildToolCall(event, theme, colorScheme);
      case 'tool_result':
        return _buildToolResult(event, theme, colorScheme);
      case 'error':
        return _buildError(event, theme, colorScheme);
      case 'finished':
        return _buildFinished(event, theme, colorScheme);
      case 'status':
        return _buildStatus(event, theme, colorScheme);
      case 'cancelled':
        return _buildCancelled(theme, colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextDelta(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (event.text == null || event.text!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        event.text!,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildToolCall(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.build_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Running: ${event.toolName}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (event.toolArgs != null && event.toolArgs!.isNotEmpty)
                      const SizedBox(height: 4),
                    if (event.toolArgs != null && event.toolArgs!.isNotEmpty)
                      Text(
                        _formatArgs(event.toolArgs!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolResult(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final result = event.toolResult ?? '';
    final isError = result.startsWith('Error:');
    final isLong = result.length > 200;

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 6, top: 2),
      child: Card(
        elevation: 0,
        color: isError
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isError
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.green.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    size: 14,
                    color: isError ? Colors.red.shade400 : Colors.green.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${event.toolName} → '
                    '${isLong ? '${result.substring(0, 200)}...' : result}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isError ? Colors.red.shade400 : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 0,
        color: Colors.red.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.error, size: 18, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event.error ?? 'Unknown error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinished(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Text(
            'Task complete',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.green.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(
    AgentEvent event,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (event.status == null) return const SizedBox.shrink();

    String label;
    IconData icon;
    Color color;

    switch (event.status!) {
      case AgentStatus.streaming:
        label = 'Thinking...';
        icon = Icons.psychology_outlined;
        color = colorScheme.onSurfaceVariant;
      case AgentStatus.executingTools:
        label = 'Executing tools...';
        icon = Icons.build_outlined;
        color = Colors.orange.shade400;
      case AgentStatus.waitingForPermission:
        label = 'Waiting for permission...';
        icon = Icons.shield_outlined;
        color = Colors.amber.shade600;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelled(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cancel_outlined, size: 18, color: Colors.orange.shade400),
          const SizedBox(width: 8),
          Text(
            'Cancelled',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.orange.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalSummary(
    AgentSession session,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final summary = session.finalResponse ?? session.accumulatedText;
    if (summary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Card(
        elevation: 0,
        color: Colors.green.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.status == AgentStatus.cancelled
                    ? 'Cancelled'
                    : session.status == AgentStatus.error
                        ? 'Error'
                        : 'Summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_hasExplicitFinalMessage(session))
                Text(
                  session.finalResponse!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              const SizedBox(height: 8),
              Text(
                '${session.events.length} events · '
                '${session.iteration} iteration(s) · '
                '${session.status.name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasExplicitFinalMessage(AgentSession session) {
    return session.finalResponse != null &&
        session.finalResponse!.isNotEmpty &&
        session.status == AgentStatus.finished;
  }

  Widget _buildInputBar(
    AgentSession session,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isRunning = session.status == AgentStatus.streaming ||
        session.status == AgentStatus.executingTools;
    final isIdle = session.status == AgentStatus.idle;
    final isTerminal = session.isTerminal;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !isRunning,
                  textInputAction: TextInputAction.send,
                  onSubmitted: isRunning ? null : (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: isIdle
                        ? 'Describe a task...'
                        : isRunning
                            ? 'Agent is running...'
                            : 'Enter a new task...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              if (isRunning)
                IconButton.filled(
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.stop_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Cancel',
                )
              else if (isTerminal)
                IconButton.filled(
                  onPressed: _handleReset,
                  icon: const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'New task',
                )
              else
                IconButton.filled(
                  onPressed: _handleSend,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Send',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatArgs(Map<String, dynamic> args) {
    final parts = <String>[];
    for (final entry in args.entries) {
      final value = entry.value is String ? "'${entry.value}'" : '${entry.value}';
      parts.add('${entry.key}: $value');
    }
    return parts.join(', ');
  }
}

/// Small colored dot indicating the agent's current status.
class _StatusIndicator extends StatelessWidget {
  final AgentStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case AgentStatus.idle:
        color = Colors.grey;
      case AgentStatus.streaming:
      case AgentStatus.executingTools:
        color = Colors.blue;
      case AgentStatus.waitingForPermission:
        color = Colors.amber;
      case AgentStatus.finished:
        color = Colors.green;
      case AgentStatus.error:
        color = Colors.red;
      case AgentStatus.cancelled:
        color = Colors.orange;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          if (status == AgentStatus.streaming)
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }
}
