// Agent tab widget — tab-compatible version of AgentScreen.
//
// Strips the Scaffold wrapper and the built-in input bar so the
// shared workspace BottomBar (Step 3) can be used instead.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_providers.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_session.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/bottom_bar_providers.dart';

/// Agent tab widget — replaces the standalone [AgentScreen].
///
/// Designed as a tab-compatible widget (no Scaffold, no built-in
/// input bar). Registers a send handler with the workspace
/// [BottomBar] via [sendMessageHandlerProvider].
class AgentTab extends ConsumerStatefulWidget {
  const AgentTab({super.key});

  @override
  ConsumerState<AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends ConsumerState<AgentTab> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sendMessageHandlerProvider.notifier).state = _handleSend;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    try {
      final current = ref.read(sendMessageHandlerProvider);
      if (current == _handleSend) {
        ref.read(sendMessageHandlerProvider.notifier).state = null;
      }
    } catch (_) {
      // Widget is being torn down, provider mutation is non-critical
    }
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

  Future<void> _handleSend(String text) async {
    ref.read(agentSessionProvider.notifier).startTask(text);
    _scrollToBottom();
  }

  void _handleCancel() {
    ref.read(agentSessionProvider.notifier).cancel();
  }

  void _handleReset() {
    ref.read(agentSessionProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(agentSessionProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header bar (replaces AppBar)
        _HeaderBar(
          session: session,
          theme: theme,
          colorScheme: colorScheme,
          onCancel: _handleCancel,
          onReset: _handleReset,
        ),
        // Event log
        Expanded(
          child: _buildEventLog(session, theme, colorScheme),
        ),
      ],
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
            _SuggestionChip(
              text: 'Find all TODOs in the project',
              onTap: () => _handleSend('Find all TODOs in the project'),
            ),
            const SizedBox(height: 8),
            _SuggestionChip(
              text: 'Refactor the main app widget',
              onTap: () => _handleSend('Refactor the main app widget'),
            ),
            const SizedBox(height: 8),
            _SuggestionChip(
              text: 'List all Dart files in lib/',
              onTap: () => _handleSend('List all Dart files in lib/'),
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
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.build_outlined, size: 18,
                  color: colorScheme.onSurfaceVariant),
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
              if (session.finalResponse != null &&
                  session.finalResponse!.isNotEmpty &&
                  session.status == AgentStatus.finished)
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

  String _formatArgs(Map<String, dynamic> args) {
    final parts = <String>[];
    for (final entry in args.entries) {
      final value = entry.value is String ? "'${entry.value}'" : '${entry.value}';
      parts.add('${entry.key}: $value');
    }
    return parts.join(', ');
  }
}

/// Header bar replacing the AppBar.
class _HeaderBar extends StatelessWidget {
  final AgentSession session;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  const _HeaderBar({
    required this.session,
    required this.theme,
    required this.colorScheme,
    required this.onCancel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Title
          Text(
            'Agent',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          // Status indicator
          _StatusIndicator(status: session.status),
          const Spacer(),
          // Cancel / Reset buttons
          if (session.status == AgentStatus.streaming ||
              session.status == AgentStatus.executingTools ||
              session.status == AgentStatus.waitingForPermission)
            IconButton(
              icon: const Icon(Icons.stop_rounded, size: 20),
              tooltip: 'Cancel',
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
            ),
          if (session.isTerminal)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'New task',
              onPressed: onReset,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
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
      width: 8,
      height: 8,
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

/// A suggestion chip for the welcome screen.
class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline,
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
