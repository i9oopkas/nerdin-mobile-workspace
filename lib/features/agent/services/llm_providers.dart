import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/core/utils/debug_logger.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_client.dart';
import 'package:nerdin_mobile_workspace/features/agent/services/llm_event.dart';

/// Configuration for a Zen API provider connection.
///
/// Zen is the default AI provider — an OpenAI-compatible gateway
/// by OpenCode (anomaly). Free models available without billing.
///
/// Default: `big-pickle` (200K context, free).
class ZenConfig {
  String baseUrl;
  String? apiKey;
  String defaultModel;
  Duration timeout;

  ZenConfig({
    this.baseUrl = 'https://opencode.ai/zen/v1',
    this.apiKey,
    this.defaultModel = 'big-pickle',
    this.timeout = const Duration(seconds: 120),
  });

  LlmConfig toLlmConfig() => LlmConfig(
        baseUrl: baseUrl,
        apiKey: apiKey,
        defaultModel: defaultModel,
        timeout: timeout,
        validateCertificate: true,
      );
}

/// Provider for the Zen API configuration.
///
/// Set during app startup or via settings UI. Defaults to
/// Zen with the free `big-pickle` model.
class ZenConfigNotifier extends Notifier<ZenConfig> {
  @override
  ZenConfig build() {
    DebugLogger.info('Zen config: model=${ZenConfig().defaultModel}, 200K context', scope: 'llm/config');
    return ZenConfig();
  }

  void updateBaseUrl(String url) {
    state = ZenConfig(baseUrl: url, apiKey: state.apiKey, defaultModel: state.defaultModel);
  }

  void updateApiKey(String? key) {
    state = ZenConfig(baseUrl: state.baseUrl, apiKey: key, defaultModel: state.defaultModel);
  }

  void updateDefaultModel(String model) {
    state = ZenConfig(baseUrl: state.baseUrl, apiKey: state.apiKey, defaultModel: model);
  }
}

final zenConfigProvider = NotifierProvider<ZenConfigNotifier, ZenConfig>(
  ZenConfigNotifier.new,
);

/// Derived LlmConfig from Zen config.
final llmConfigProvider = Provider<LlmConfig>((ref) {
  final zen = ref.watch(zenConfigProvider);
  return zen.toLlmConfig();
});

/// Provider for the LLM client instance.
final llmClientProvider = Provider<LlmClient>((ref) {
  final config = ref.watch(llmConfigProvider);
  return LlmClient(config: config);
});

/// Provider for the list of available models.
final availableModelsProvider = FutureProvider<List<ModelInfo>>((ref) async {
  final client = ref.watch(llmClientProvider);
  return client.listModels();
});

/// Provider for the currently selected model.
class SelectedModelNotifier extends Notifier<String> {
  @override
  String build() {
    final zen = ref.watch(zenConfigProvider);
    DebugLogger.info('Model selected: ${zen.defaultModel}', scope: 'llm/model');
    return zen.defaultModel;
  }

  void select(String modelId) {
    state = modelId;
  }
}

final selectedModelProvider = NotifierProvider<SelectedModelNotifier, String>(
  SelectedModelNotifier.new,
);
