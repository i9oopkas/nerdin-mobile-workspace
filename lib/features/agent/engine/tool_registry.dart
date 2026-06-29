// Central tool registry for the Nerdin Mobile Agent Engine.
//
// Phase 1c — Agent Engine.
//
// [ToolRegistry] manages all available tools and provides permission-checked
// execution via [PermissionManager]. It converts tool call requests into
// executed results, handling permission flows (allow/ask/deny).
//
// Integration with Phase 1b (Permission System) and Phase 1d (API Client).

import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_definitions.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_manager.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_rules.dart';

/// Result of a tool execution.
class ToolResult {
  /// The ID of the tool call this result is for.
  final String toolCallId;

  /// The name of the tool that was executed.
  final String toolName;

  /// The output/observation from execution (or error message).
  final String output;

  /// Whether the execution was successful.
  final bool success;

  /// If permission was denied, this contains the exception.
  final PermissionDeniedException? deniedException;

  const ToolResult({
    required this.toolCallId,
    required this.toolName,
    required this.output,
    this.success = true,
    this.deniedException,
  });

  /// Convert to an LlmMessage for the conversation history.
  Map<String, dynamic> toToolMessage() => {
        'role': 'tool',
        'tool_call_id': toolCallId,
        'content': output,
      };

  @override
  String toString() =>
      'ToolResult(name: $toolName, success: $success, output: ${output.length > 100 ? '${output.substring(0, 100)}...' : output})';
}

/// Central registry for agent tools.
///
/// Tools are registered by name and can be looked up for execution.
/// The registry integrates with [PermissionManager] for access control.
class ToolRegistry {
  final Map<String, ToolDefinition> _tools = {};

  ToolRegistry();

  /// Register a single tool.
  void register(ToolDefinition tool) {
    DebugLogger.info('Tool registered: ${tool.name}', scope: 'agent/tool');
    _tools[tool.name] = tool;
  }

  /// Register multiple tools at once.
  void registerAll(List<ToolDefinition> tools) {
    for (final tool in tools) {
      _tools[tool.name] = tool;
    }
  }

  /// Look up a tool by name.
  ToolDefinition? get(String name) => _tools[name];

  /// Get all registered tools as OpenAI tool format.
  List<Map<String, dynamic>> toOpenAiTools() =>
      _tools.values.map((t) => t.toOpenAiTool()).toList();

  /// Get all registered tool names.
  List<String> get toolNames => _tools.keys.toList();

  /// Check if a tool is registered.
  bool has(String name) => _tools.containsKey(name);

  /// Number of registered tools.
  int get count => _tools.length;

  /// Execute a tool by name with the given arguments.
  ///
  /// Flow:
  /// 1. Look up the tool
  /// 2. Check permissions via [permissionManager]
  /// 3. If allowed → execute and return result
  /// 4. If denied → return error ToolResult
  /// 5. If ask → permissionManager throws [TimeoutException] or returns normally
  ///
  /// Returns a [ToolResult] with the execution output.
  Future<ToolResult> execute({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required PermissionManager permissionManager,
    String sessionId = 'default',
  }) async {
    // 1. Look up the tool
    final tool = _tools[toolName];
    if (tool == null) {
      return ToolResult(
        toolCallId: toolCallId,
        toolName: toolName,
        output: 'Error: Unknown tool "$toolName". Available tools: ${toolNames.join(", ")}',
        success: false,
      );
    }

    // 2. Extract resources for permission checking
    final resources = tool.extractResources(arguments);
    final action = tool.operationType.value;

    // 3. Check permissions
    try {
      await permissionManager.assert_(
        action: action,
        resources: resources,
        sessionId: sessionId,
        metadata: {
          'tool': toolName,
          'arguments': arguments,
        },
      );
    } on PermissionDeniedException catch (e) {
      return ToolResult(
        toolCallId: toolCallId,
        toolName: toolName,
        output: 'Error: Permission denied: $e. '
            'Cannot $action on ${resources.join(", ")}.',
        success: false,
        deniedException: e,
      );
    }

    // 4. Determine execution target
    final targetStr = arguments['target'] as String?;
    final target = targetStr != null
        ? (ExecutionTarget.values.where((e) => e.value == targetStr).firstOrNull
            ?? tool.defaultTarget)
        : tool.defaultTarget;
    arguments.remove('target');

    // 5. Execute the tool
    DebugLogger.info('Executing tool: $toolName', scope: 'agent/tool');
    try {
      final output = await tool.handler(arguments, target);
      DebugLogger.info('Tool $toolName result: ${output.length} chars', scope: 'agent/tool');
      return ToolResult(
        toolCallId: toolCallId,
        toolName: toolName,
        output: output,
        success: true,
      );
    } catch (e, st) {
      DebugLogger.error('Tool $toolName failed', error: e, scope: 'agent/tool');
      return ToolResult(
        toolCallId: toolCallId,
        toolName: toolName,
        output: 'Error executing $toolName: $e',
        success: false,
      );
    }
  }

  /// Create a [ToolRegistry] with all built-in tools pre-registered.
  ///
  /// Optionally provide [backends] to enable non-local execution targets.
  factory ToolRegistry.withBuiltins({ToolBackends? backends}) {
    final registry = ToolRegistry();
    registry.registerAll(createBuiltinTools(backends: backends));
    return registry;
  }
}
