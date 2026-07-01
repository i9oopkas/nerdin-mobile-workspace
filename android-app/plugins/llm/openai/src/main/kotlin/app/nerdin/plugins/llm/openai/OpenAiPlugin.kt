package app.nerdin.plugins.llm.openai

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version
import app.nerdin.plugins.llm.api.LLMProvider
import app.nerdin.plugins.llm.api.ModelProvider

class OpenAiPlugin : Plugin {

    override val manifest = PluginManifest(
        pluginId = "nerdin.llm.openai",
        version = Version.parse("0.1.0"),
        apiVersion = Version.parse("0.1.0"),
        minCoreVersion = Version.parse("0.1.0"),
        provides = listOf(
            "app.nerdin.plugins.llm.api.LLMProvider",
            "app.nerdin.plugins.llm.api.ModelProvider"
        )
    )

    private lateinit var config: OpenAiConfig
    private lateinit var provider: OpenAiLlmProvider
    private lateinit var modelProvider: OpenAiModelProvider
    private lateinit var context: PluginContext

    override fun onLoad(context: PluginContext) {
        this.context = context
        Log.i("OpenAiPlugin", "Loading OpenAI plugin")

        config = OpenAiConfig.load(context.dataDir) ?: OpenAiConfig()
        provider = OpenAiLlmProvider(config)
        modelProvider = OpenAiModelProvider(config)

        Log.i("OpenAiPlugin", "Configured: provider=${config.providerId}, baseUrl=${config.baseUrl}")
    }

    override fun onEnable() {
        Log.i("OpenAiPlugin", "Enabling — registering services")

        // Register our services so other plugins can find them via PluginContext.getService()
        context.registerService(LLMProvider::class.java, provider)
        context.registerService(ModelProvider::class.java, modelProvider)

        Log.i("OpenAiPlugin", "Registered: LLMProvider, ModelProvider")
    }

    override fun onDisable() {
        Log.i("OpenAiPlugin", "Disabling")
        provider.close()
    }

    override fun onUnload() {
        Log.i("OpenAiPlugin", "Unloading")
    }
}
