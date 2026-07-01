package app.nerdin.plugins.agent.permissions

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version
import app.nerdin.plugins.agent.api.AgentPermissionService

class AgentPermissionsPlugin : Plugin {

    override val manifest = PluginManifest(
        pluginId = "nerdin.agent.permissions",
        version = Version.parse("0.1.0"),
        apiVersion = Version.parse("0.1.0"),
        minCoreVersion = Version.parse("0.1.0"),
        provides = listOf("app.nerdin.plugins.agent.api.AgentPermissionService")
    )

    private lateinit var ctx: PluginContext
    private lateinit var engine: PermissionEngine

    override fun onLoad(context: PluginContext) {
        ctx = context
        Log.i("AgentPermissionsPlugin", "Loading permission engine")
        engine = PermissionEngine(context)
    }

    override fun onEnable() {
        Log.i("AgentPermissionsPlugin", "Registering AgentPermissionService")
        ctx.registerService(AgentPermissionService::class.java, engine)
    }

    override fun onDisable() {
        Log.i("AgentPermissionsPlugin", "Clearing session rules")
        engine.clearSessionRules()
    }

    override fun onUnload() {
        Log.i("AgentPermissionsPlugin", "Unloaded")
    }
}
