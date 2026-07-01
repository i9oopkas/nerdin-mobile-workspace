package app.nerdin.core.runtime.plugin

import android.util.Log
import app.nerdin.core.api.Plugin
import app.nerdin.core.api.PluginLifecycleEvent
import app.nerdin.core.runtime.NerdinCore
import app.nerdin.core.runtime.version.VersionCompatibility
import dalvik.system.DexClassLoader
import java.io.File
import java.util.ServiceLoader

/**
 * Manages plugin lifecycle: discovery, loading, enabling, disabling, unloading.
 *
 * Supports two loading strategies:
 * 1. Classpath-based via ServiceLoader (legacy/development fallback)
 * 2. Runtime from .dex files via DexClassLoader with cache
 */
class PluginLifecycleManager {

    private val loadedPlugins = mutableMapOf<String, Plugin>()
    private val pluginStates = mutableMapOf<String, PluginLifecycleEvent.State>()

    // ──────────────────────────────────────────────
    //  Classpath-based loading (ServiceLoader)
    // ──────────────────────────────────────────────

    fun loadAll(core: NerdinCore) {
        val loader = ServiceLoader.load(Plugin::class.java, Plugin::class.java.classLoader)
        for (plugin in loader) {
            internalLoadPlugin(core, plugin)
        }
    }

    // ──────────────────────────────────────────────
    //  Runtime loading from .dex directory
    // ──────────────────────────────────────────────

    /**
     * Load plugins from .dex files in [pluginDir].
     *
     * Strategy:
     * 1. Try cache from [cacheFile]. If valid (core version matches, hashes match), load
     *    known plugins directly without ServiceLoader (we already know the class name).
     * 2. For cache misses / new / modified files: full discovery via DexClassLoader + ServiceLoader.
     * 3. Rebuild and save the cache after loading.
     *
     * @param pluginDir  Directory containing .dex plugin files
     * @param cacheFile  JSON file used as a persistent cache
     * @param core       NerdinCore instance
     * @param coreVersion Current core version string (semver), used to invalidate cache on core upgrade
     */
    fun loadFromDirectory(
        pluginDir: File,
        cacheFile: File,
        core: NerdinCore,
        coreVersion: String = "0.1.0"
    ) {
        val dexFiles = pluginDir.listFiles { f -> f.extension == "dex" } ?: emptyArray()
        if (dexFiles.isEmpty()) {
            Log.i("PluginLifecycleManager", "No .dex files in $pluginDir")
            return
        }

        val cache = PluginCache.load(cacheFile)
        val cacheIsValid = cache != null && cache.coreVersion == coreVersion

        // Track which dex files we've processed, so we can discover new ones
        val processedDexPaths = mutableSetOf<String>()

        if (cacheIsValid) {
            Log.i("PluginLifecycleManager", "Cache hit (${cache!!.plugins.size} plugins), verifying hashes…")
            cache!!.plugins.forEach { cached ->
                val dexFile = File(cached.filePath)
                processedDexPaths.add(dexFile.absolutePath)

                if (!dexFile.exists()) {
                    Log.w("PluginLifecycleManager", "Cached plugin ${cached.pluginId} file missing, skipping")
                    return@forEach
                }

                if (PluginCache.sha256(dexFile) != cached.fileHash) {
                    Log.w("PluginLifecycleManager", "Cached plugin ${cached.pluginId} hash mismatch, re-scanning")
                    discoverAndLoadPlugin(core, dexFile, pluginDir)
                    return@forEach
                }

                // Cache hit — instantiate from known class name without ServiceLoader
                val plugin = instantiatePlugin(cached.className, dexFile, pluginDir)
                if (plugin != null) {
                    internalLoadPlugin(core, plugin)
                }
            }
        } else {
            Log.i("PluginLifecycleManager", "Cache miss, scanning ${dexFiles.size} .dex files")
        }

        // Discover any .dex files not covered by cache (new / cache-missed)
        dexFiles.forEach { dexFile ->
            if (dexFile.absolutePath !in processedDexPaths) {
                discoverAndLoadPlugin(core, dexFile, pluginDir)
            }
        }

        // Build and persist updated cache
        buildAndSaveCache(coreVersion, pluginDir, dexFiles, cacheFile)
        Log.i("PluginLifecycleManager", "Plugin loading complete, ${loadedPlugins.size} loaded")
    }

    // ──────────────────────────────────────────────
    //  Internal helpers
    // ──────────────────────────────────────────────

    /**
     * Try to load a plugin from a .dex file.
     * First tries ServiceLoader (works for classpath-based loading in dev mode),
     * then falls back to .pluginmeta file (works for .dex files at runtime, since
     * d8 strips META-INF/services/).
     */
    private fun discoverAndLoadPlugin(core: NerdinCore, dexFile: File, pluginDir: File) {
        // Ensure the DEX file is readable by DexClassLoader (Android 10+ requires read-only)
        if (!dexFile.canRead()) {
            Log.e("PluginLifecycleManager", "Cannot read ${dexFile.name} — the file may be missing or inaccessible")
            return
        }
        try {
            val classLoader = createDexClassLoader(dexFile, pluginDir)

            // Try ServiceLoader first (works for classpath/JAR development mode)
            val loader = ServiceLoader.load(Plugin::class.java, classLoader)
            var count = 0
            for (plugin in loader) {
                Log.i("PluginLifecycleManager", "ServiceLoader discovered plugin: ${plugin::class.java.name}")
                if (internalLoadPlugin(core, plugin)) count++
            }

            // Fallback: try .pluginmeta file (works for .dex at runtime, since d8 strips META-INF/services/)
            if (count == 0) {
                val metaFile = File(dexFile.parentFile, dexFile.nameWithoutExtension + ".pluginmeta")
                if (metaFile.exists()) {
                    val className = metaFile.readText().trim()
                    Log.i("PluginLifecycleManager", "Found .pluginmeta for ${dexFile.name}: $className")
                    try {
                        val pluginClass = classLoader.loadClass(className)
                        if (Plugin::class.java.isAssignableFrom(pluginClass)) {
                            val constructor = pluginClass.getDeclaredConstructor()
                            val plugin = constructor.newInstance() as Plugin
                            Log.i("PluginLifecycleManager", "Instantiated plugin from .pluginmeta: $className")
                            if (internalLoadPlugin(core, plugin)) count++
                        } else {
                            Log.w("PluginLifecycleManager", "Class $className does not implement Plugin interface")
                        }
                    } catch (e: Exception) {
                        Log.e("PluginLifecycleManager", "Failed to instantiate plugin $className from .pluginmeta", e)
                    }
                } else {
                    Log.w("PluginLifecycleManager", "No .pluginmeta file for ${dexFile.name} and ServiceLoader found nothing")
                }
            }

            if (count == 0) {
                Log.w("PluginLifecycleManager", "No Plugin implementations found in ${dexFile.name}")
            }
        } catch (e: Exception) {
            Log.e("PluginLifecycleManager", "Failed to scan ${dexFile.name}: ${e.message}", e)
        }
    }

    /**
     * Instantiate a single known plugin class from .dex without ServiceLoader.
     */
    private fun instantiatePlugin(className: String, dexFile: File, pluginDir: File): Plugin? {
        return try {
            val classLoader = createDexClassLoader(dexFile, pluginDir)
            @Suppress("UNCHECKED_CAST")
            val clazz = Class.forName(className, true, classLoader)
            clazz.getDeclaredConstructor().newInstance() as Plugin
        } catch (e: Exception) {
            Log.e("PluginLifecycleManager", "Failed to instantiate $className from ${dexFile.name}: ${e.message}", e)
            null
        }
    }

    private fun createDexClassLoader(dexFile: File, pluginDir: File): DexClassLoader {
        val optimizedDir = File(pluginDir, "optimized").also { it.mkdirs() }
        return DexClassLoader(
            dexFile.absolutePath,
            optimizedDir.absolutePath,
            null,
            Plugin::class.java.classLoader
        )
    }

    /**
     * Build a cache entry for every currently loaded plugin by re-matching against .dex files.
     *
     * Heuristic: for each loaded plugin, find the .dex file whose name is a substring
     * of the plugin's class name or pluginId.  This is saved alongside the SHA-256 hash
     * so future startups can skip ServiceLoader entirely.
     */
    private fun buildAndSaveCache(
        coreVersion: String,
        pluginDir: File,
        dexFiles: Array<File>,
        cacheFile: File
    ) {
        val cached = loadedPlugins.map { (pluginId, plugin) ->
            // Match .dex file — find whose filename is contained in the class package
            val className = plugin::class.java.name
            val dexFile = dexFiles.firstOrNull { d ->
                className.contains(d.nameWithoutExtension, ignoreCase = true) ||
                        pluginId.contains(d.nameWithoutExtension, ignoreCase = true)
            }

            CachedPlugin(
                pluginId = pluginId,
                filePath = dexFile?.absolutePath ?: "",
                fileHash = dexFile?.let { PluginCache.sha256(it) } ?: "",
                className = className,
                manifest = plugin.manifest
            )
        }

        val cache = PluginCache(coreVersion = coreVersion, plugins = cached)
        PluginCache.save(cacheFile, cache)
    }

    // ──────────────────────────────────────────────
    //  Core lifecycle
    // ──────────────────────────────────────────────

    fun internalLoadPlugin(core: NerdinCore, plugin: Plugin): Boolean {
        val manifest = plugin.manifest
        Log.d("PluginLifecycleManager", "Loading plugin: ${manifest.pluginId} v${manifest.version}")

        if (!VersionCompatibility.checkCoreVersion(manifest)) {
            Log.w("PluginLifecycleManager", "Plugin ${manifest.pluginId} requires core ${manifest.minCoreVersion}..${manifest.maxCoreVersion ?: "any"}, skipping")
            return false
        }

        if (loadedPlugins.containsKey(manifest.pluginId)) {
            Log.w("PluginLifecycleManager", "Plugin ${manifest.pluginId} already loaded")
            return false
        }

        return try {
            val context = core.createPluginContext(manifest.pluginId)
            plugin.onLoad(context)
            loadedPlugins[manifest.pluginId] = plugin
            pluginStates[manifest.pluginId] = PluginLifecycleEvent.State.LOADED

            core.eventBus.publish(PluginLifecycleEvent(
                pluginId = manifest.pluginId,
                previousState = PluginLifecycleEvent.State.INSTALLED,
                newState = PluginLifecycleEvent.State.LOADED
            ))
            true
        } catch (e: Exception) {
            Log.e("PluginLifecycleManager", "Failed to load plugin ${manifest.pluginId}", e)
            false
        }
    }

    fun enableAll() {
        loadedPlugins.forEach { (id, plugin) ->
            try {
                plugin.onEnable()
                pluginStates[id] = PluginLifecycleEvent.State.ENABLED
            } catch (e: Exception) {
                Log.e("PluginLifecycleManager", "Failed to enable plugin $id", e)
            }
        }
    }

    fun disableAll() {
        loadedPlugins.forEach { (id, plugin) ->
            try {
                plugin.onDisable()
                pluginStates[id] = PluginLifecycleEvent.State.DISABLED
            } catch (e: Exception) {
                Log.e("PluginLifecycleManager", "Failed to disable plugin $id", e)
            }
        }
    }

    fun unloadAll() {
        loadedPlugins.forEach { (id, plugin) ->
            try {
                plugin.onUnload()
                pluginStates[id] = PluginLifecycleEvent.State.UNLOADED
            } catch (e: Exception) {
                Log.e("PluginLifecycleManager", "Failed to unload plugin $id", e)
            }
        }
        loadedPlugins.clear()
    }

    fun getPlugin(id: String): Plugin? = loadedPlugins[id]
    fun getState(id: String): PluginLifecycleEvent.State? = pluginStates[id]
    fun allPlugins(): List<Plugin> = loadedPlugins.values.toList()
    fun isLoaded(id: String): Boolean = loadedPlugins.containsKey(id)
}
