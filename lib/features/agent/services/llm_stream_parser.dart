import 'dart:async';
import 'dart:convert';

import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_event.dart';

/// Parses OpenAI-compatible SSE streams into [LlmEvent] events.
///
/// Handles:
/// - Standard text deltas: `data: {"choices":[{"delta":{"content":"..."}}]}`
/// - Tool call deltas: `data: {"choices":[{"delta":{"tool_calls":[...]}}]}`
/// - Finish reasons: `data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}`
/// - Stream end: `data: [DONE]`
/// - Non-streaming JSON response (fallback)
///
/// The parser follows OpenAI's streaming specification and handles both
/// OpenAI-native chunked tool_calls and provider-specific complete-in-one responses.
class LlmStreamParser {
  /// Parse an SSE byte stream into [LlmEvent] events.
  Stream<LlmEvent> parse(Stream<List<int>> byteStream) {
    DebugLogger.stream('Parsing stream', scope: 'llm/parse');
    return byteStream
        .transform(const Utf8Decoder())
        .transform(const LineSplitter())
        .expand(_parseLine);
  }

  /// Parse a complete non-streaming JSON response into [LlmEvent] events.
  /// Useful as fallback for providers without SSE support.
  List<LlmEvent> parseNonStreaming(String responseBody) {
    final events = <LlmEvent>[];

    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        events.add(MessageFinished('error'));
        return events;
      }

      final choice = choices[0] as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>?;
      final finishReason = choice['finish_reason'] as String? ?? 'stop';

      // Extract content
      final content = message?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        events.add(TextDelta(content));
      }

      // Extract tool_calls
      final toolCalls = message?['tool_calls'] as List<dynamic>?;
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          final tcMap = tc as Map<String, dynamic>;
          final function = tcMap['function'] as Map<String, dynamic>?;
          events.add(ToolCallDelta(
            index: tcMap['index'] as int? ?? 0,
            id: tcMap['id'] as String?,
            functionName: function?['name'] as String?,
            arguments: function?['arguments'] as String? ?? '',
          ));
        }
      }

      events.add(MessageFinished(finishReason));
    } catch (e) {
      DebugLogger.error('Parse error', error: e, scope: 'llm/parse');
      events.add(LlmErrorEvent(e));
    }

    return events;
  }

  /// Parse a single SSE data line into [LlmEvent] events.
  List<LlmEvent> _parseLine(String line) {
    final events = <LlmEvent>[];

    // Skip non-data lines
    if (!line.startsWith('data:')) return events;

    final payload = line.substring(5).trimLeft();

    // Handle [DONE] signal
    if (payload == '[DONE]') return events;

    // Parse JSON payload
    Map<String, dynamic> json;
    try {
      json = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      // Non-JSON data line — skip (keepalive, etc.)
      return events;
    }

    final choices = json['choices'] as List<dynamic>?;

    // Non-chat completion events (e.g., model info, error)
    if (choices == null || choices.isEmpty) {
      // Handle error objects
      final error = json['error'];
      if (error != null) {
        events.add(LlmErrorEvent(error.toString()));
        events.add(MessageFinished('error'));
      }
      return events;
    }

    final choice = choices[0] as Map<String, dynamic>?;
    if (choice == null) return events;

    // Check finish_reason
    final finishReason = choice['finish_reason'] as String?;
    if (finishReason != null && finishReason != 'null' && finishReason.isNotEmpty) {
      events.add(MessageFinished(finishReason));
    }

    // Extract delta
    final delta = choice['delta'] as Map<String, dynamic>?;
    if (delta == null) return events;

    // Text content
    final content = delta['content'] as String?;
    if (content != null && content.isNotEmpty) {
      events.add(TextDelta(content));
    }

    // Tool calls
    final toolCalls = delta['tool_calls'] as List<dynamic>?;
    if (toolCalls != null) {
      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final function = tcMap['function'] as Map<String, dynamic>?;
        events.add(ToolCallDelta(
          index: tcMap['index'] as int? ?? 0,
          id: tcMap['id'] as String?,
          functionName: function?['name'] as String?,
          arguments: function?['arguments'] as String? ?? '',
        ));
      }
    }

    for (final event in events) {
      DebugLogger.stream('LLM event: ${event.runtimeType}', scope: 'llm/event');
    }

    return events;
  }
}


