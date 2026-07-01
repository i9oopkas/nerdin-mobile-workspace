package app.nerdin.plugins.termux

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version

class TermuxPlugin : Plugin {
    override val manifest = PluginManifest(
        pluginId = "nerdin.termux",
        version = Version.parse("0.1.0"),
        apiVersion = Version.parse("0.1.0"),
        minCoreVersion = Version.parse("0.1.0"),
        provides = listOf("app.nerdin.plugins.termux.TermuxService")
    )

    override fun onLoad(context: PluginContext) {
        Log.i("TermuxPlugin", "Stub loaded")
    }

    override fun onEnable() {
        Log.i("TermuxPlugin", "Stub enabled")
    }

    override fun onDisable() {
        Log.i("TermuxPlugin", "Stub disabled")
    }

    override fun onUnload() {
        Log.i("TermuxPlugin", "Stub unloaded")
    }
}
