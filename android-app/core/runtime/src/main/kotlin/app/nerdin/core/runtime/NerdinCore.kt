package app.nerdin.core.runtime

import android.content.Context
import android.util.Log
import app.nerdin.core.api.CoreLifecycleEvent
import app.nerdin.core.api.NerdinService
import app.nerdin.core.api.PluginContext
import app.nerdin.core.runtime.container.ServiceContainer
import app.nerdin.core.runtime.event.EventBus
import app.nerdin.core.runtime.extension.ExtensionPointManager
import app.nerdin.core.runtime.permission.PermissionManager
import app.nerdin.core.runtime.plugin.PluginLifecycleManager
import app.nerdin.core.runtime.service.ServiceRegistry
import app.nerdin.core.runtime.version.VersionCompatibility
import java.io.File

/**
 * Entry point for the Nerdin Core platform.
 * Orchestrates all core subsystems.
 */
class NerdinCore private constructor(
    val context: Context,
    val config: NerdinCoreConfig,
    val serviceContainer: ServiceContainer,
    val serviceRegistry: ServiceRegistry,
    val pluginManager: PluginLifecycleManager,
    val eventBus: EventBus,
    val permissionManager: PermissionManager,
    val extensionPointManager: ExtensionPointManager,
    val versionChecker: VersionCompatibility
) : NerdinService {

    companion object {
        /**
         * Create a NerdinCore instance.
         * If [config] is not provided, defaults are computed from [appContext].
         */
        suspend fun create(
            appContext: Context,
            config: NerdinCoreConfig? = null
        ): NerdinCore {
            val effectiveConfig = config ?: NerdinCoreConfig(
                pluginDir = File(appContext.filesDir, "plugins"),
                cacheFile = File(appContext.filesDir, "plugin_registry.json")
            )

            val eventBus = EventBus()
            val container = ServiceContainer.create()
            val serviceRegistry = ServiceRegistry()
            val permissionManager = PermissionManager(appContext)
            val extensionPointManager = ExtensionPointManager(eventBus)

            val core = NerdinCore(
                context = appContext,
                config = effectiveConfig,
                serviceContainer = container,
                serviceRegistry = serviceRegistry,
                pluginManager = PluginLifecycleManager(),
                eventBus = eventBus,
                permissionManager = permissionManager,
                extensionPointManager = extensionPointManager,
                versionChecker = VersionCompatibility
            )

            // Register core services in the DI container
            container.register(core, NerdinCore::class.java)
            container.register(eventBus, EventBus::class.java)
            container.register(serviceRegistry, ServiceRegistry::class.java)
            container.register(extensionPointManager, ExtensionPointManager::class.java)

            // Prepare plugin directory
            effectiveConfig.pluginDir.mkdirs()
            effectiveConfig.cacheFile.parentFile?.mkdirs()

            // Extract built-in plugins from APK assets
            if (effectiveConfig.extractFromAssets) {
                extractBuiltinPlugins(appContext, effectiveConfig.pluginDir)
            }

            eventBus.publish(CoreLifecycleEvent(CoreLifecycleEvent.Phase.BOOTING))
            return core
        }

        /**
         * Copy built-in plugin .dex files from APK assets/plugins/ to the plugin directory.
         * Only copies if the file doesn't already exist (won't overwrite user-downloaded versions).
         */
        private fun extractBuiltinPlugins(context: Context, targetDir: File) {
            try {
                val assetManager = context.assets
                val pluginAssets = assetManager.list("plugins") ?: return
                val dexAssets = pluginAssets.filter { it.endsWith(".dex") }

                if (dexAssets.isEmpty()) {
                    Log.d("NerdinCore", "No built-in plugin .dex files in assets/plugins/")
                    return
                }

                dexAssets.forEach { name ->
                    val targetFile = File(targetDir, name)
                    if (targetFile.exists()) {
                        Log.d("NerdinCore", "Plugin $name already exists, skipping extraction")
                        return@forEach
                    }
                    try {
                        assetManager.open("plugins/$name").use { input ->
                            targetFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        // Set read-only to satisfy Android 10+ DEX loading security check
                        targetFile.setReadOnly()
                        Log.d("NerdinCore", "Set $name to read-only for DEX loading")
                        Log.i("NerdinCore", "Extracted built-in plugin: $name (${targetFile.length()} bytes)")
                    } catch (e: Exception) {
                        Log.e("NerdinCore", "Failed to extract plugin $name", e)
                    }
                }

                // Also extract .pluginmeta files (used by PluginLifecycleManager fallback path)
                val metaAssets = pluginAssets.filter { it.endsWith(".pluginmeta") }
                metaAssets.forEach { name ->
                    val targetFile = File(targetDir, name)
                    if (targetFile.exists()) return@forEach // Don't overwrite
                    try {
                        assetManager.open("plugins/$name").use { input ->
                            targetFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        Log.d("NerdinCore", "Extracted plugin metadata: $name")
                    } catch (e: Exception) {
                        Log.e("NerdinCore", "Failed to extract plugin metadata $name", e)
                    }
                }
            } catch (e: Exception) {
                Log.e("NerdinCore", "Failed to list assets/plugins/", e)
            }
        }
    }

    /**
     * Start the core platform:
     * 1. Load plugins from plugin directory (DexClassLoader + cache)
     * 2. Enable all plugins
     * 3. Transition to READY state
     */
    suspend fun start() {
        eventBus.publish(CoreLifecycleEvent(CoreLifecycleEvent.Phase.LOADING_PLUGINS))

        pluginManager.loadFromDirectory(
            pluginDir = config.pluginDir,
            cacheFile = config.cacheFile,
            core = this,
            coreVersion = config.coreVersion
        )

        eventBus.publish(CoreLifecycleEvent(CoreLifecycleEvent.Phase.STARTING_SERVICES))
        pluginManager.enableAll()
        eventBus.publish(CoreLifecycleEvent(CoreLifecycleEvent.Phase.READY))
    }

    suspend fun shutdown() {
        eventBus.publish(CoreLifecycleEvent(CoreLifecycleEvent.Phase.SHUTTING_DOWN))
        pluginManager.disableAll()
        pluginManager.unloadAll()
        eventBus.publish(CoreLifecycleEvent(CoreLifecycleEvent.Phase.SHUTDOWN))
    }

    fun <T : NerdinService> getService(type: Class<T>): T? = serviceRegistry.resolve(type)

    fun createPluginContext(pluginId: String): PluginContext {
        return CorePluginContext(this, pluginId)
    }
}

/**
 * Configuration for the Nerdin Core platform.
 *
 * @param pluginDir Directory where plugin .dex files are stored.
 *                  Built-in plugins are extracted here from assets on first run.
 * @param cacheFile JSON file that caches plugin metadata for fast subsequent startup.
 * @param extractFromAssets Whether to extract built-in plugins from APK assets on first run.
 * @param coreVersion Current core version (SemVer string), used for cache invalidation.
 */
data class NerdinCoreConfig(
    val pluginDir: File,
    val cacheFile: File,
    val extractFromAssets: Boolean = true,
    val coreVersion: String = "0.1.0"
)
