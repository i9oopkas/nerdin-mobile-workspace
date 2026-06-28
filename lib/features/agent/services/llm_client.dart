import 'dart:async';

import 'package:dio/dio.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_event.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_stream_parser.dart';

/// Configuration for an LLM provider connection.
class LlmConfig {
  /// Base URL of the API (e.g. "https://api.openai.com/v1" or "http://localhost:11434/v1").
  final String baseUrl;

  /// API key for authentication (Bearer token).
  final String? apiKey;

  /// Additional headers to include in every request.
  final Map<String, String> extraHeaders;

  /// Default model to use when none is specified.
  final String defaultModel;

  /// Request timeout.
  final Duration timeout;

  /// Whether to verify TLS certificates.
  final bool validateCertificate;

  const LlmConfig({
    required this.baseUrl,
    this.apiKey,
    this.extraHeaders = const {},
    this.defaultModel = 'gpt-4o',
    this.timeout = const Duration(seconds: 60),
    this.validateCertificate = true,
  });

  /// Create a config for OpenRouter.
  factory LlmConfig.openRouter({required String apiKey, String? model}) {
    return LlmConfig(
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: apiKey,
      defaultModel: model ?? 'openai/gpt-4o',
      extraHeaders: {
        'HTTP-Referer': 'https://github.com/anomalyco/opencode',
        'X-Title': 'Nerdin Mobile Workspace',
      },
    );
  }

  /// Create a config for Ollama (local).
  factory LlmConfig.ollama({String host = 'localhost', int port = 11434, String? model}) {
    return LlmConfig(
      baseUrl: 'http://$host:$port/v1',
      defaultModel: model ?? 'llama3.2',
      validateCertificate: false,
    );
  }

  /// Create a config for LM Studio (local).
  factory LlmConfig.lmStudio({String host = 'localhost', int port = 1234, String? model}) {
    return LlmConfig(
      baseUrl: 'http://$host:$port/v1',
      defaultModel: model ?? 'local-model',
      validateCertificate: false,
    );
  }

  /// Create a config for OpenAI.
  factory LlmConfig.openAI({required String apiKey, String? model}) {
    return LlmConfig(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: apiKey,
      defaultModel: model ?? 'gpt-4o',
    );
  }
}

/// Represents a message in the chat completion request.
class LlmMessage {
  final String role; // "system", "user", "assistant", "tool"
  final String? content;
  final List<Map<String, dynamic>>? toolCalls;
  final String? toolCallId;

  const LlmMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'role': role};
    if (content != null) json['content'] = content;
    if (toolCalls != null) json['tool_calls'] = toolCalls;
    if (toolCallId != null) json['tool_call_id'] = toolCallId;
    return json;
  }

  factory LlmMessage.system(String content) => LlmMessage(role: 'system', content: content);
  factory LlmMessage.user(String content) => LlmMessage(role: 'user', content: content);
  factory LlmMessage.assistant(String content) => LlmMessage(role: 'assistant', content: content);
}

/// A tool/function definition for the LLM.
class LlmToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // JSON Schema

  const LlmToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

/// Main LLM API client for the agent system.
///
/// Supports streaming and non-streaming chat completions,
/// model listing, and multiple provider configurations.
class LlmClient {
  final LlmConfig config;
  final LlmStreamParser parser;
  late final Dio _dio;

  LlmClient({
    required this.config,
    LlmStreamParser? parser,
    Dio? dio,
  }) : parser = parser ?? LlmStreamParser() {
    _dio = dio ?? _createDio();
  }

  Dio _createDio() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      if (config.apiKey != null) 'Authorization': 'Bearer ${config.apiKey}',
      ...config.extraHeaders,
    };

    return Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        headers: headers,
        connectTimeout: config.timeout,
        receiveTimeout: config.timeout,
        sendTimeout: config.timeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  /// Send a streaming chat completion request.
  ///
  /// Returns a [Stream] of [LlmEvent] events. The stream completes when
  /// the server finishes sending events or on error.
  Stream<LlmEvent> sendStreaming({
    required List<LlmMessage> messages,
    String? model,
    List<LlmToolDefinition>? tools,
    double temperature = 0.7,
    int? maxTokens,
  }) async* {
    final body = _buildBody(
      messages: messages,
      model: model ?? config.defaultModel,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: true,
    );

    try {
      final response = await _dio.post<ResponseBody>(
        '/chat/completions',
        data: body,
        options: Options(
          responseType: ResponseType.stream,
        ),
      );

      final responseBody = response.data;
      if (responseBody == null) {
        yield LlmErrorEvent('Empty response from server');
        return;
      }

      // Parse the SSE stream
      final byteStream = responseBody.stream;
      yield* parser.parse(byteStream);
    } on DioException catch (e) {
      yield LlmErrorEvent(_formatDioError(e));
    } catch (e) {
      yield LlmErrorEvent(e);
    }
  }

  /// Send a non-streaming chat completion request.
  ///
  /// Returns a complete list of [LlmEvent] events after the response is received.
  /// Useful as fallback for providers without SSE support.
  Future<List<LlmEvent>> sendNonStreaming({
    required List<LlmMessage> messages,
    String? model,
    List<LlmToolDefinition>? tools,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final body = _buildBody(
      messages: messages,
      model: model ?? config.defaultModel,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      stream: false,
    );

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: body,
      );

      if (response.statusCode != 200) {
        return [LlmErrorEvent('HTTP ${response.statusCode}: ${response.statusMessage}')];
      }

      final responseBody = response.data as String?;
      if (responseBody == null || responseBody.isEmpty) {
        return [LlmErrorEvent('Empty response from server')];
      }

      return parser.parseNonStreaming(responseBody);
    } on DioException catch (e) {
      return [LlmErrorEvent(_formatDioError(e))];
    } catch (e) {
      return [LlmErrorEvent(e)];
    }
  }

  /// List available models from the provider.
  Future<List<ModelInfo>> listModels() async {
    try {
      final response = await _dio.get('/models');

      if (response.statusCode != 200) {
        return [];
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) return [];

      final modelsJson = data['data'] as List<dynamic>?;
      if (modelsJson == null) return [];

      return modelsJson.map((m) {
        final model = m as Map<String, dynamic>;
        final id = model['id'] as String? ?? '';
        final ownedBy = model['owned_by'] as String?;
        return ModelInfo(
          id: id,
          name: model['name'] as String? ?? model['id'] as String?,
          provider: ownedBy,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _buildBody({
    required List<LlmMessage> messages,
    required String model,
    List<LlmToolDefinition>? tools,
    double temperature = 0.7,
    int? maxTokens,
    bool stream = true,
  }) {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': stream,
      'temperature': temperature,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }

    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }

    return body;
  }

  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout: ${config.baseUrl}';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout: server took too long';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        return 'HTTP $statusCode: $body';
      case DioExceptionType.connectionError:
        return 'Connection refused: ${config.baseUrl}';
      default:
        return 'Request failed: ${e.message}';
    }
  }
}
