// Unified event types for LLM streaming responses.
//
// All LLM providers (OpenAI, OpenRouter, Ollama, LM Studio, etc.) produce
// these events through [LlmStreamParser], decoupling the rest of the code
// from provider-specific SSE formats.
//
// Based on Conduit's [OpenWebUIStreamUpdate] sealed hierarchy but adapted
// for OpenAI-compatible APIs and agent-focused use cases (tool_calls).

/// Base sealed class for all LLM stream events.
sealed class LlmEvent {}

/// A text delta chunk from streaming content.
///
/// Corresponds to `choices[0].delta.content` in OpenAI SSE.
class TextDelta extends LlmEvent {
  final String text;

  TextDelta(this.text);

  @override
  String toString() => 'TextDelta(text: "${text.length > 40 ? '${text.substring(0, 40)}...' : text}")';
}

/// A tool call delta from streaming.
///
/// Handling rules:
/// - Some providers send complete tool_calls in one SSE event (OpenRouter, Ollama).
/// - Some send partial `arguments` across multiple chunks (OpenAI native).
/// - The [arguments] field always contains the *full accumulated* arguments so far
///   from the OpenAI specification — but some providers send incremental deltas.
///
/// The [LlmStreamParser] accumulates partial arguments and emits one [ToolCallDelta]
/// per index per SSE chunk. Consumers should accumulate by [index] until
/// [MessageFinished] with `finishReason: "tool_calls"` is received.
class ToolCallDelta extends LlmEvent {
  /// The index of the tool call (for parallel tool calls).
  final int index;

  /// The unique ID of the tool call (may be null in partial chunks).
  final String? id;

  /// The name of the function being called (may be null in partial chunks).
  final String? functionName;

  /// The JSON arguments string (may be partial or complete depending on provider).
  final String arguments;

  ToolCallDelta({
    required this.index,
    this.id,
    this.functionName,
    this.arguments = '',
  });

  @override
  String toString() =>
      'ToolCallDelta(index: $index, id: $id, fn: $functionName, args: $arguments)';
}

/// The stream has finished with a specific reason.
class MessageFinished extends LlmEvent {
  /// One of: "stop", "tool_calls", "length", "content_filter", "error".
  final String finishReason;

  MessageFinished(this.finishReason);

  bool get isToolCall => finishReason == 'tool_calls';
  bool get isStop => finishReason == 'stop';

  @override
  String toString() => 'MessageFinished(reason: $finishReason)';
}

/// A non-fatal event during streaming (e.g., usage info, model selection).
class LlmInfoEvent extends LlmEvent {
  final String type; // e.g. "usage", "model", "sources"
  final Map<String, dynamic> data;

  LlmInfoEvent({required this.type, required this.data});

  @override
  String toString() => 'LlmInfoEvent(type: $type)';
}

/// A fatal error during streaming.
class LlmErrorEvent extends LlmEvent {
  final Object error;
  final StackTrace? stackTrace;

  LlmErrorEvent(this.error, [this.stackTrace]);

  @override
  String toString() => 'LlmErrorEvent(error: $error)';
}

/// A model from the provider's model list.
class ModelInfo {
  final String id;
  final String? name;
  final String? provider;
  final int? maxTokens;
  final bool supportsVision;
  final bool supportsToolCalls;
  final bool supportsStreaming;

  const ModelInfo({
    required this.id,
    this.name,
    this.provider,
    this.maxTokens,
    this.supportsVision = false,
    this.supportsToolCalls = false,
    this.supportsStreaming = true,
  });

  @override
  String toString() => 'ModelInfo(id: $id, name: $name)';
}
