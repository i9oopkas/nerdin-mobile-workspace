// Session state model for the Nerdin Mobile Agent Engine.
//
// Phase 1c — Agent Engine.
//
// Represents the current state of an agent session, including
// conversation history, iteration count, and status.
// Consumed by Riverpod providers and the Agent UI (Phase 1e).

import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';

/// The status of an agent session.
enum AgentStatus {
  /// Agent is idle, not processing any task.
  idle,

  /// Agent is streaming a response from the LLM.
  streaming,

  /// Agent is executing tool calls.
  executingTools,

  /// Agent is waiting for user permission to execute a tool.
  waitingForPermission,

  /// Agent has completed the task.
  finished,

  /// Agent encountered an error.
  error,

  /// Agent was cancelled by the user.
  cancelled,
}

/// An event emitted during agent execution for UI consumption.
///
/// Unlike [LlmEvent] which represents LLM stream events, [AgentEvent]
/// represents higher-level agent lifecycle events including tool execution.
class AgentEvent {
  final String type; // text_delta, tool_call, tool_result, permission, finished, error, status
  final String? text;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  final String? toolResult;
  final String? error;
  final AgentStatus? status;

  const AgentEvent._({
    required this.type,
    this.text,
    this.toolName,
    this.toolArgs,
    this.toolResult,
    this.error,
    this.status,
  });

  factory AgentEvent.textDelta(String text) =>
      AgentEvent._(type: 'text_delta', text: text);

  factory AgentEvent.toolCall(String name, Map<String, dynamic> args) =>
      AgentEvent._(type: 'tool_call', toolName: name, toolArgs: args);

  factory AgentEvent.toolResult(String name, String result) =>
      AgentEvent._(type: 'tool_result', toolName: name, toolResult: result);

  factory AgentEvent.permissionRequest() =>
      AgentEvent._(type: 'permission');

  factory AgentEvent.finished(String? finalMessage) =>
      AgentEvent._(type: 'finished', text: finalMessage);

  factory AgentEvent.error(String error) =>
      AgentEvent._(type: 'error', error: error);

  factory AgentEvent.statusChange(AgentStatus status) =>
      AgentEvent._(type: 'status', status: status);

  factory AgentEvent.cancelled() =>
      AgentEvent._(type: 'cancelled');

  @override
  String toString() {
    switch (type) {
      case 'text_delta':
        return 'AgentEvent.textDelta("${text!.length > 40 ? '${text!.substring(0, 40)}...' : text}")';
      case 'tool_call':
        return 'AgentEvent.toolCall($toolName)';
      case 'tool_result':
        return 'AgentEvent.toolResult($toolName)';
      case 'finished':
        return 'AgentEvent.finished()';
      case 'error':
        return 'AgentEvent.error($error)';
      default:
        return 'AgentEvent($type)';
    }
  }
}

/// A complete agent session with full history.
///
/// This is the main state object that gets stored in the Riverpod provider
/// and consumed by the Agent UI.
class AgentSession {
  /// Unique session ID.
  final String id;

  /// Current status of the session.
  final AgentStatus status;

  /// The original task/query that started this session.
  final String currentTask;

  /// The current iteration number (ReAct loop count).
  final int iteration;

  /// Maximum allowed iterations.
  final int maxIterations;

  /// Timestamp when the session started.
  final DateTime startedAt;

  /// Timestamp when the session finished (or null if still running).
  final DateTime? finishedAt;

  /// Timestamp of the last activity.
  final DateTime lastActivityAt;

  /// All events emitted during this session.
  final List<AgentEvent> events;

  /// The accumulated text response (final answer when finished).
  final String? finalResponse;

  /// Error message if the session ended with an error.
  final String? errorMessage;

  AgentSession({
    required this.id,
    this.status = AgentStatus.idle,
    this.currentTask = '',
    this.iteration = 0,
    this.maxIterations = 10,
    DateTime? startedAt,
    this.finishedAt,
    DateTime? lastActivityAt,
    this.events = const [],
    this.finalResponse,
    this.errorMessage,
  })  : startedAt = startedAt ?? DateTime.now(),
        lastActivityAt = lastActivityAt ?? DateTime.now();

  /// Create a new session with a given task.
  factory AgentSession.create({
    required String task,
    int maxIterations = 10,
    String? id,
  }) {
    final truncatedTask = task.length > 50 ? '${task.substring(0, 50)}...' : task;
    DebugLogger.info('Task started: "$truncatedTask"', scope: 'agent/session');
    return AgentSession(
      id: id ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
      status: AgentStatus.idle,
      currentTask: task,
      maxIterations: maxIterations,
      startedAt: DateTime.now(),
    );
  }

  /// Copy with modified fields.
  AgentSession copyWith({
    AgentStatus? status,
    int? iteration,
    DateTime? finishedAt,
    DateTime? lastActivityAt,
    List<AgentEvent>? events,
    String? finalResponse,
    String? errorMessage,
    String? currentTask,
  }) {
    return AgentSession(
      id: id,
      status: status ?? this.status,
      currentTask: currentTask ?? this.currentTask,
      iteration: iteration ?? this.iteration,
      maxIterations: maxIterations,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      lastActivityAt: lastActivityAt ?? DateTime.now(),
      events: events ?? this.events,
      finalResponse: finalResponse ?? this.finalResponse,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Add an event and return a new session state.
  AgentSession withEvent(AgentEvent event) {
    DebugLogger.stream('Event: ${event.type}', scope: 'agent/session', data: {'type': event.type});
    final newEvents = [...events, event];
    AgentStatus newStatus = status;
    String? newFinalResponse = finalResponse;
    String? newErrorMessage = errorMessage;

    switch (event.type) {
      case 'finished':
        newStatus = AgentStatus.finished;
        newFinalResponse = event.text;
      case 'error':
        newStatus = AgentStatus.error;
        newErrorMessage = event.error;
      case 'cancelled':
        newStatus = AgentStatus.cancelled;
      case 'status':
        newStatus = event.status ?? status;
      case 'tool_call':
        newStatus = AgentStatus.executingTools;
      case 'permission':
        newStatus = AgentStatus.waitingForPermission;
      case 'text_delta':
        if (status == AgentStatus.idle) newStatus = AgentStatus.streaming;
    }

    if (newStatus != status) {
      DebugLogger.info('Status: $newStatus', scope: 'agent/session');
    }
    return copyWith(
      status: newStatus,
      events: newEvents,
      lastActivityAt: DateTime.now(),
      finalResponse: newFinalResponse,
      errorMessage: newErrorMessage,
    );
  }

  /// Increment the iteration counter.
  AgentSession incrementIteration() {
    return copyWith(
      iteration: iteration + 1,
      lastActivityAt: DateTime.now(),
    );
  }

  /// Check if the session has reached its max iterations.
  bool get isMaxIterationsReached => iteration >= maxIterations;

  /// Check if the session is in a terminal state.
  bool get isTerminal =>
      status == AgentStatus.finished ||
      status == AgentStatus.error ||
      status == AgentStatus.cancelled;

  /// Get the last N events for display.
  List<AgentEvent> lastEvents(int n) {
    if (events.length <= n) return events;
    return events.sublist(events.length - n);
  }

  /// Get the accumulated text from all text_delta events.
  String get accumulatedText {
    return events
        .where((e) => e.type == 'text_delta' && e.text != null)
        .map((e) => e.text!)
        .join();
  }

  /// Get all tool call events.
  List<AgentEvent> get toolCallEvents =>
      events.where((e) => e.type == 'tool_call').toList();

  /// Get all tool result events.
  List<AgentEvent> get toolResultEvents =>
      events.where((e) => e.type == 'tool_result').toList();
}
