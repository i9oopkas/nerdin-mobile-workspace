package app.nerdin.plugins.tools.termux

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version

class TermuxToolsPlugin : Plugin {
    override val manifest = PluginManifest(
        pluginId = "nerdin.tools.termux",
        version = Version.parse("0.1.0"),
        apiVersion = Version.parse("0.1.0"),
        minCoreVersion = Version.parse("0.1.0"),
        provides = listOf("app.nerdin.plugins.tool.api.ToolProvider")
    )

    override fun onLoad(context: PluginContext) {
        Log.i("TermuxToolsPlugin", "Stub loaded")
    }

    override fun onEnable() {
        Log.i("TermuxToolsPlugin", "Stub enabled")
    }

    override fun onDisable() {
        Log.i("TermuxToolsPlugin", "Stub disabled")
    }

    override fun onUnload() {
        Log.i("TermuxToolsPlugin", "Stub unloaded")
    }
}
