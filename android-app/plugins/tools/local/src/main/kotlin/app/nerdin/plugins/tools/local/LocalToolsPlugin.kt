package app.nerdin.plugins.tools.local

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version
import app.nerdin.plugins.tool.api.ToolProvider

class LocalToolsPlugin : Plugin {

    override val manifest = PluginManifest(
        pluginId = "nerdin.tools.local",
        version = Version.parse("0.1.0"),
        apiVersion = Version.parse("0.1.0"),
        minCoreVersion = Version.parse("0.1.0"),
        provides = listOf("app.nerdin.plugins.tool.api.ToolProvider")
    )

    private lateinit var ctx: PluginContext
    private lateinit var toolProvider: LocalToolProvider

    override fun onLoad(context: PluginContext) {
        ctx = context
        Log.i("LocalToolsPlugin", "Initializing local tools")
        toolProvider = LocalToolProvider()
    }

    override fun onEnable() {
        Log.i("LocalToolsPlugin", "Registering ToolProvider")
        ctx.registerService(ToolProvider::class.java, toolProvider)
    }

    override fun onDisable() {}

    override fun onUnload() {}
}
