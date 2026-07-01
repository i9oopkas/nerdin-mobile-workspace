package app.nerdin.core.runtime.plugin

import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

/**
 * Cache of discovered plugins for fast subsequent startup.
 * After the first runtime load, plugin metadata and file hashes are cached
 * so that DexClassLoader doesn't need to be created again.
 *
 * Cache invalidation:
 * - Plugin .dex file hash changed → re-scan that plugin
 * - Core version changed → full re-scan
 * - Cache file missing/corrupt → full re-scan
 */
data class PluginCache(
    val version: Int = CURRENT_VERSION,
    val coreVersion: String,
    val plugins: List<CachedPlugin>
) {
    companion object {
        const val CURRENT_VERSION = 1
        private const val CACHE_FILE = "plugin_registry.json"

        fun load(registryFile: File): PluginCache? {
            if (!registryFile.exists()) return null
            return try {
                val json = JSONObject(registryFile.readText())
                val cacheVersion = json.optInt("version", 0)
                if (cacheVersion != CURRENT_VERSION) return null

                val arr = json.getJSONArray("plugins")
                val plugins = (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    CachedPlugin(
                        pluginId = obj.getString("pluginId"),
                        filePath = obj.getString("filePath"),
                        fileHash = obj.getString("fileHash"),
                        className = obj.getString("className"),
                        manifest = PluginManifest(
                            pluginId = obj.getString("pluginId"),
                            version = Version.parse(obj.optString("version", "0.0.0")),
                            apiVersion = Version.parse(obj.optString("apiVersion", "0.0.0")),
                            minCoreVersion = Version.parse(obj.optString("minCoreVersion", "0.0.0")),
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
                            permissions = emptyList()
                        ),
                        lastLoaded = obj.optLong("lastLoaded", 0L)
                    )
                }
                PluginCache(
                    version = cacheVersion,
                    coreVersion = json.optString("coreVersion", "0.0.0"),
                    plugins = plugins
                )
            } catch (e: Exception) {
                android.util.Log.w("PluginCache", "Failed to load cache, will re-scan", e)
                null
            }
        }

        fun save(registryFile: File, cache: PluginCache) {
            try {
                val arr = JSONArray()
                cache.plugins.forEach { p ->
                    val obj = JSONObject().apply {
                        put("pluginId", p.pluginId)
                        put("filePath", p.filePath)
                        put("fileHash", p.fileHash)
                        put("className", p.className)
                        put("lastLoaded", p.lastLoaded)
                        put("version", p.manifest.version.toString())
                        put("apiVersion", p.manifest.apiVersion.toString())
                        put("minCoreVersion", p.manifest.minCoreVersion.toString())
                        put("maxCoreVersion", p.manifest.maxCoreVersion?.toString() ?: JSONObject.NULL)
                        put("dependencies", JSONArray(p.manifest.dependencies))
                        put("optionalDependencies", JSONArray(p.manifest.optionalDependencies))
                        put("provides", JSONArray(p.manifest.provides))
                        put("requires", JSONArray(p.manifest.requires))
                    }
                    arr.put(obj)
                }
                val json = JSONObject().apply {
                    put("version", cache.version)
                    put("coreVersion", cache.coreVersion)
                    put("plugins", arr)
                }
                registryFile.parentFile?.mkdirs()
                registryFile.writeText(json.toString(2))
            } catch (e: Exception) {
                android.util.Log.e("PluginCache", "Failed to save cache", e)
            }
        }

        fun sha256(file: File): String {
            val digest = MessageDigest.getInstance("SHA-256")
            file.inputStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    digest.update(buffer, 0, bytesRead)
                }
            }
            return digest.digest().joinToString("") { "%02x".format(it) }
        }
    }
}

/**
 * A single cached plugin entry.
 *
 * @param pluginId Unique plugin identifier (e.g. "nerdin.llm.openai")
 * @param filePath Absolute path to the .dex file
 * @param fileHash SHA-256 hash of the .dex file (for cache invalidation)
 * @param className Fully qualified class name implementing Plugin (e.g. "app.nerdin.plugins.llm.openai.OpenAiPlugin")
 * @param manifest Full plugin manifest (cached to avoid DexClassLoader on cache hit)
 * @param lastLoaded Unix timestamp of when this plugin was last loaded
 */
data class CachedPlugin(
    val pluginId: String,
    val filePath: String,
    val fileHash: String,
    val className: String,
    val manifest: PluginManifest,
    val lastLoaded: Long = System.currentTimeMillis()
)
