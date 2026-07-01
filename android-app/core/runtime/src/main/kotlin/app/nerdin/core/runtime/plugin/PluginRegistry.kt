package app.nerdin.core.runtime.plugin

import android.content.Context
import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Persistent registry of installed plugins.
 * Stores plugin metadata in a JSON file.
 */
class PluginRegistry(private val context: Context) {

    private val registryFile = File(context.filesDir, "plugin_registry.json")
    private val registry: MutableMap<String, PluginManifest> = mutableMapOf()

    init {
        load()
    }

    fun register(manifest: PluginManifest) {
        registry[manifest.pluginId] = manifest
        save()
    }

    fun unregister(pluginId: String) {
        registry.remove(pluginId)
        save()
    }

    fun get(pluginId: String): PluginManifest? = registry[pluginId]
    fun all(): List<PluginManifest> = registry.values.toList()
    fun isInstalled(pluginId: String): Boolean = registry.containsKey(pluginId)

    private fun load() {
        if (!registryFile.exists()) return
        try {
            val json = JSONObject(registryFile.readText())
            val arr = json.getJSONArray("plugins")
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val manifest = PluginManifest(
                    pluginId = obj.getString("pluginId"),
                    version = Version.parse(obj.getString("version")),
                    apiVersion = Version.parse(obj.getString("apiVersion")),
                    minCoreVersion = Version.parse(obj.getString("minCoreVersion")),
                    maxCoreVersion = if (obj.has("maxCoreVersion") && !obj.isNull("maxCoreVersion"))
                        Version.parse(obj.getString("maxCoreVersion")) else null,
                    dependencies = obj.optJSONArray("dependencies")?.let {
                        (0 until it.length()).map { idx -> it.getString(idx) }
                    } ?: emptyList(),
                    optionalDependencies = obj.optJSONArray("optionalDependencies")?.let {
                        (0 until it.length()).map { idx -> it.getString(idx) }
                    } ?: emptyList(),
                    provides = obj.optJSONArray("provides")?.let {
                        (0 until it.length()).map { idx -> it.getString(idx) }
                    } ?: emptyList(),
                    requires = obj.optJSONArray("requires")?.let {
                        (0 until it.length()).map { idx -> it.getString(idx) }
                    } ?: emptyList(),
                    permissions = emptyList()  // permissions are loaded separately
                )
                registry[manifest.pluginId] = manifest
            }
        } catch (e: Exception) {
            android.util.Log.e("PluginRegistry", "Failed to load registry", e)
        }
    }

    private fun save() {
        try {
            val arr = JSONArray()
            registry.values.forEach { manifest ->
                val obj = JSONObject().apply {
                    put("pluginId", manifest.pluginId)
                    put("version", manifest.version.toString())
                    put("apiVersion", manifest.apiVersion.toString())
                    put("minCoreVersion", manifest.minCoreVersion.toString())
                    put("maxCoreVersion", manifest.maxCoreVersion?.toString() ?: JSONObject.NULL)
                    put("dependencies", JSONArray(manifest.dependencies))
                    put("optionalDependencies", JSONArray(manifest.optionalDependencies))
                    put("provides", JSONArray(manifest.provides))
                    put("requires", JSONArray(manifest.requires))
                }
                arr.put(obj)
            }
            val json = JSONObject().apply { put("plugins", arr) }
            registryFile.parentFile?.mkdirs()
            registryFile.writeText(json.toString(2))
        } catch (e: Exception) {
            android.util.Log.e("PluginRegistry", "Failed to save registry", e)
        }
    }
}
