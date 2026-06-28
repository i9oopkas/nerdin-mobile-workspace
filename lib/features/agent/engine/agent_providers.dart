// Riverpod providers for the Nerdin Mobile Agent Engine.
//
// Phase 1c — Agent Engine.
//
// Provides:
// - [toolRegistryProvider] — singleton ToolRegistry with built-in tools
// - [agentSessionProvider] — current agent session state (Notifier)
// - [agentLoopProvider] — factory for creating AgentLoop instances
//
// Integrates with Phase 1b (permission_providers) and Phase 1d (llm_providers).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_loop.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_session.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_registry.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_providers.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_providers.dart';

/// Provider for the singleton [ToolRegistry] with built-in tools.
///
/// Tools available:
/// - read_file, write_file, edit_file, grep, glob, search
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return ToolRegistry.withBuiltins();
});

/// Notifier for the current [AgentSession] state.
///
/// Manages session lifecycle: create, update events, reset.
class AgentSessionNotifier extends Notifier<AgentSession> {
  StreamSubscription<AgentEvent>? _currentRunSubscription;

  @override
  AgentSession build() {
    // Start with an empty idle session
    return AgentSession.create(task: '');
  }

  /// Start a new agent session with the given task.
  ///
  /// Creates a fresh session and immediately begins the ReAct loop.
  /// Returns a [Future] that completes when the session finishes.
  Future<void> startTask(String task) async {
    // Reset to a new session
    state = AgentSession.create(task: task);

    // Get dependencies
    final llmClient = ref.read(llmClientProvider);
    final toolRegistry = ref.read(toolRegistryProvider);
    final permissionManager = ref.read(permissionManagerProvider);

    // Create the agent loop
    final loop = AgentLoop(
      llmClient: llmClient,
      toolRegistry: toolRegistry,
      permissionManager: permissionManager,
    );

    // Listen to stream events and update state
    await _currentRunSubscription?.cancel();
    final stream = loop.run(task: task);

    await for (final event in stream) {
      state = state.withEvent(event);
    }
  }

  /// Cancel the current running session.
  void cancel() {
    _currentRunSubscription?.cancel();
    _currentRunSubscription = null;
    if (!state.isTerminal) {
      state = state.copyWith(
        status: AgentStatus.cancelled,
        finishedAt: DateTime.now(),
      );
    }
  }

  /// Reset the session to idle.
  void reset() {
    _currentRunSubscription?.cancel();
    _currentRunSubscription = null;
    state = AgentSession.create(task: '');
  }
}

/// Provider for the current agent session state.
final agentSessionProvider =
    NotifierProvider<AgentSessionNotifier, AgentSession>(
  AgentSessionNotifier.new,
);

/// Provider that creates [AgentLoop] instances.
///
/// This is a factory provider — it creates a new [AgentLoop] each time
/// you read it, wired up with the current providers.
final agentLoopProvider = Provider<AgentLoop Function({
  required String task,
  int maxIterations,
  String? model,
})>((ref) {
  final llmClient = ref.read(llmClientProvider);
  final toolRegistry = ref.read(toolRegistryProvider);
  final permissionManager = ref.read(permissionManagerProvider);

  return ({
    required String task,
    int maxIterations = 10,
    String? model,
  }) {
    final loop = AgentLoop(
      llmClient: llmClient,
      toolRegistry: toolRegistry,
      permissionManager: permissionManager,
    );
    return loop;
  };
});
