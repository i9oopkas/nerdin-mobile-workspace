package app.nerdin.plugins.agent.react

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version
import app.nerdin.plugins.agent.api.AgentProvider

class ReactAgentPlugin : Plugin {

    override val manifest = PluginManifest(
        pluginId = "nerdin.agent.react",
        version = Version.parse("0.1.0"),
        apiVersion = Version.parse("0.1.0"),
        minCoreVersion = Version.parse("0.1.0"),
        provides = listOf("app.nerdin.plugins.agent.api.AgentProvider"),
        requires = listOf(
            "app.nerdin.plugins.llm.api.LLMProvider",
            "app.nerdin.plugins.tool.api.ToolProvider",
            "app.nerdin.plugins.agent.api.AgentPermissionService"
        )
    )

    private lateinit var ctx: PluginContext
    private lateinit var provider: ReactAgentProvider

    override fun onLoad(context: PluginContext) {
        ctx = context
        Log.i("ReactAgentPlugin", "Loaded")
        provider = ReactAgentProvider(context)
    }

    override fun onEnable() {
        Log.i("ReactAgentPlugin", "Registering AgentProvider")
        ctx.registerService(AgentProvider::class.java, provider)
    }

    override fun onDisable() {
        Log.i("ReactAgentPlugin", "Disabled")
    }

    override fun onUnload() {
        Log.i("ReactAgentPlugin", "Unloaded")
    }
}
