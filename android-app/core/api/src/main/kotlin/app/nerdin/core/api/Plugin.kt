package app.nerdin.core.api

/**
 * Base interface for all Nerdin plugins.
 * Every plugin must implement this interface and declare its manifest.
 */
interface Plugin {

    /** Plugin descriptor with metadata and requirements */
    val manifest: PluginManifest

    /**
     * Called after the plugin class is loaded and the context is set up.
     * Plugin should initialize its internal state here.
     * Do NOT start background work — use onEnable() for that.
     */
    fun onLoad(context: PluginContext)

    /**
     * Called when the plugin becomes active.
     * Start services, register listeners, begin background work here.
     */
    fun onEnable()

    /**
     * Called when the plugin is being deactivated.
     * Stop services, release resources, save state.
     */
    fun onDisable()

    /**
     * Called before the plugin class is unloaded.
     * Final cleanup — close files, release native resources.
     */
    fun onUnload()
}
