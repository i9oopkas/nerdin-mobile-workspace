package app.nerdin.plugins.llm.openai

import org.json.JSONObject
import java.io.File

/**
 * Configuration for an OpenAI-compatible LLM provider.
 *
 * Multiple named configurations can coexist (e.g. "openai", "zen", "ollama"),
 * each with its own base URL, API key, and default model.
 *
 * @param providerId Unique ID for this provider instance (e.g. "openai", "zen", "ollama")
 * @param displayName Human-readable name for UI menus
 * @param baseUrl API base URL (e.g. "https://api.openai.com/v1")
 * @param apiKey Optional API key
 * @param defaultModel Default model ID to use (e.g. "gpt-4o")
 * @param timeoutSeconds HTTP request timeout
 */
data class OpenAiConfig(
    val providerId: String = "zen",
    val displayName: String = "Zen (OpenCode)",
    val baseUrl: String = "https://api.opencode.ai",
    val apiKey: String? = null,
    val defaultModel: String = "big-pickle",
    val timeoutSeconds: Int = 60
) {
    companion object {
        private const val CONFIG_FILE = "llm_config.json"

        /**
         * Load configuration from a JSON file in the plugin's data directory.
         * Returns null if the file doesn't exist.
         */
        fun load(pluginDir: File): OpenAiConfig? {
            val configFile = File(pluginDir, CONFIG_FILE)
            if (!configFile.exists()) return null

            return try {
                val json = JSONObject(configFile.readText())
                OpenAiConfig(
                    providerId = json.optString("providerId", "openai"),
                    displayName = json.optString("displayName", "OpenAI"),
                    baseUrl = json.optString("baseUrl", "https://api.openai.com/v1"),
                    apiKey = json.optString("apiKey", null),
                    defaultModel = json.optString("defaultModel", "gpt-4o"),
                    timeoutSeconds = json.optInt("timeoutSeconds", 60)
                )
            } catch (e: Exception) {
                null
            }
        }

        /**
         * Save configuration to a JSON file.
         */
        fun save(pluginDir: File, config: OpenAiConfig) {
            val json = JSONObject().apply {
                put("providerId", config.providerId)
                put("displayName", config.displayName)
                put("baseUrl", config.baseUrl)
                put("apiKey", config.apiKey ?: "")
                put("defaultModel", config.defaultModel)
                put("timeoutSeconds", config.timeoutSeconds)
            }
            File(pluginDir, CONFIG_FILE).writeText(json.toString(2))
        }
    }
}
