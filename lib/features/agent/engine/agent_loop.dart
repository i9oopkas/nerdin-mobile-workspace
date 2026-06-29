// ReAct loop for the Nerdin Mobile Agent Engine.
//
// Phase 1c — Agent Engine.
//
// Implements the Reasoning + Acting loop:
// 1. Send conversation + tool definitions to LLM
// 2. Stream response, accumulating text and tool calls
// 3. If tool_calls finish_reason → execute tools, append results, loop
// 4. If stop finish_reason → task complete
//
// Integrates with:
// - [LlmClient] (Phase 1d) for LLM communication
// - [ToolRegistry] for tool execution
// - [PermissionManager] (Phase 1b) for access control
//
// Produces a [Stream] of [AgentEvent] for the Agent UI (Phase 1e).

import 'dart:async';
import 'dart:convert';

import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_session.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_registry.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_manager.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_client.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_event.dart';

/// The ReAct agent loop.
///
/// Usage:
/// ```dart
/// final loop = AgentLoop(llmClient: client, toolRegistry: registry, permissionManager: pm);
/// await for (final event in loop.run(task: "Refactor this code")) {
///   // render event in UI
/// }
/// ```
class AgentLoop {
  final LlmClient _llmClient;
  final ToolRegistry _toolRegistry;
  final PermissionManager _permissionManager;
  final String _sessionId;
  String? _lastFinishReason;

  /// System prompt that tells the LLM how to use tools.
  static const String _systemPrompt = '''
You are Nerdin, an AI coding assistant that helps users develop software.
You have access to a set of tools that let you read, write, and search files.

When you need to accomplish a task:
1. First, explore the codebase to understand the current state
2. Plan your approach
3. Use the available tools to make changes
4. Verify your changes

Tool usage rules:
- Use read_file to understand existing code before making changes
- Use glob and search to find relevant files
- Use grep to search for patterns in the code
- Use edit_file for targeted changes (preferred over write_file)
- Use write_file only when creating new files or making substantial changes
- After making changes, verify them by reading the modified files

Always think step by step. Show your reasoning before and after using tools.
When a task is complete, summarize what you did.
''';

  AgentLoop({
    required LlmClient llmClient,
    required ToolRegistry toolRegistry,
    required PermissionManager permissionManager,
    String sessionId = 'default',
  })  : _llmClient = llmClient,
        _toolRegistry = toolRegistry,
        _permissionManager = permissionManager,
        _sessionId = sessionId;

  /// Run the agent loop for the given [task].
  ///
  /// Returns a [Stream] of [AgentEvent] events that the UI can render.
  /// The stream completes when the task is done or an error occurs.
  ///
  /// [maxIterations] limits the number of ReAct loop cycles.
  /// [model] overrides the default model.
  Stream<AgentEvent> run({
    required String task,
    int maxIterations = 10,
    String? model,
  }) async* {
    final messages = <LlmMessage>[
      LlmMessage.system(_systemPrompt),
      LlmMessage.user(task),
    ];

    final llmTools = _toolRegistry.toolNames.map((name) {
      final tool = _toolRegistry.get(name)!;
      return LlmToolDefinition(
        name: tool.name,
        description: tool.description,
        parameters: tool.effectiveInputSchema,
      );
    }).toList();

    int iteration = 0;

    while (iteration < maxIterations) {
      iteration++;
      DebugLogger.info('Agent loop iteration $iteration started', scope: 'agent/loop');
      yield AgentEvent.statusChange(AgentStatus.streaming);

      // --- Step 1: Send to LLM and stream response ---
      String accumulatedContent = '';
      final Map<int, _AccumulatedToolCall> accumulatedToolCalls = {};
      bool finishedWithToolCalls = false;

      final stream = _llmClient.sendStreaming(
        messages: messages,
        tools: llmTools.isNotEmpty ? llmTools : null,
        model: model,
      );

      try {
        await for (final event in stream) {
          switch (event) {
            case TextDelta(:final text):
              accumulatedContent += text;
              yield AgentEvent.textDelta(text);

            case ToolCallDelta(:final index, :final id, :final functionName, :final arguments):
              // Accumulate by index (last one wins per OpenAI spec)
              accumulatedToolCalls[index] = _AccumulatedToolCall(
                id: id ?? '',
                functionName: functionName ?? '',
                arguments: arguments,
                index: index,
              );

            case MessageFinished(:final finishReason):
              _lastFinishReason = finishReason;
              finishedWithToolCalls = _lastFinishReason == 'tool_calls';

            case LlmInfoEvent():
              // Ignore info events for now
              break;

            case LlmErrorEvent(:final error):
              yield AgentEvent.error('LLM error: $error');
              yield AgentEvent.statusChange(AgentStatus.error);
              return;
          }
        }
      } on Exception catch (e, stackTrace) {
        DebugLogger.error('Agent loop error', error: e, stackTrace: stackTrace, scope: 'agent/loop');
        yield AgentEvent.error('Stream error: $e');
        yield AgentEvent.statusChange(AgentStatus.error);
        return;
      }

      // --- Step 2: Add assistant message to history ---
      if (accumulatedContent.isNotEmpty || accumulatedToolCalls.isNotEmpty) {
        messages.add(LlmMessage(
          role: 'assistant',
          content: accumulatedContent.isNotEmpty ? accumulatedContent : null,
          toolCalls: accumulatedToolCalls.isNotEmpty
              ? accumulatedToolCalls.values.map((tc) => {
                    'id': tc.id,
                    'type': 'function',
                    'function': {
                      'name': tc.functionName,
                      'arguments': tc.arguments,
                    },
                  }).toList()
              : null,
        ));
      }

      // --- Step 3: Handle finish reason ---
      if (_lastFinishReason == 'stop' || accumulatedToolCalls.isEmpty) {
        DebugLogger.info('Agent loop finished (stop)', scope: 'agent/loop');
        // Task complete — LLM decided not to use tools
        yield AgentEvent.finished(accumulatedContent);
        yield AgentEvent.statusChange(AgentStatus.finished);
        return;
      }

      if (!finishedWithToolCalls && accumulatedToolCalls.isEmpty) {
        // No tool calls and not finished — something unexpected
        yield AgentEvent.error(
          'Unexpected state: no tool calls and not finished. '
          'Finish reason: $_lastFinishReason',
        );
        yield AgentEvent.statusChange(AgentStatus.error);
        return;
      }

      // --- Step 4: Execute tool calls ---
      yield AgentEvent.statusChange(AgentStatus.executingTools);

      for (final tc in accumulatedToolCalls.values) {
        // Parse arguments JSON
        Map<String, dynamic>? parsedArgs;
        try {
          parsedArgs = tc.arguments.isNotEmpty
              ? jsonDecode(tc.arguments) as Map<String, dynamic>
              : <String, dynamic>{};
        } catch (e) {
          final errorMsg = 'Failed to parse arguments for ${tc.functionName}: $e';
          yield AgentEvent.toolCall(tc.functionName, {'_parse_error': tc.arguments});
          yield AgentEvent.toolResult(tc.functionName, errorMsg);

          messages.add(LlmMessage(
            role: 'tool',
            toolCallId: tc.id,
            content: errorMsg,
          ));
          continue;
        }

        yield AgentEvent.toolCall(tc.functionName, parsedArgs);

        DebugLogger.info('Executing tool: ${tc.functionName}', scope: 'agent/loop', data: {'tool': tc.functionName, 'args': tc.arguments});

        // Execute the tool (ToolRegistry handles permission checks internally)
        final result = await _toolRegistry.execute(
          toolCallId: tc.id,
          toolName: tc.functionName,
          arguments: parsedArgs,
          permissionManager: _permissionManager,
          sessionId: _sessionId,
        );

        yield AgentEvent.toolResult(tc.functionName, result.output);
        messages.add(LlmMessage(
          role: 'tool',
          toolCallId: tc.id,
          content: result.output,
        ));
      }

      // --- Step 5: Check max iterations ---
      if (iteration >= maxIterations) {
        yield AgentEvent.finished(
          'Reached maximum iterations ($maxIterations). The task may be incomplete.',
        );
        yield AgentEvent.statusChange(AgentStatus.finished);
        return;
      }

      // Loop back to step 1
    }
  }
}

/// Accumulated state for a tool call during streaming.
class _AccumulatedToolCall {
  final String id;
  final String functionName;
  final String arguments;
  final int index;

  const _AccumulatedToolCall({
    required this.id,
    required this.functionName,
    required this.arguments,
    required this.index,
  });
}
