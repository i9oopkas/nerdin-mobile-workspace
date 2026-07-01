package app.nerdin.core.api

import java.io.File

/**
 * Interface through which a plugin interacts with the core platform.
 * This is the ONLY way a plugin should access core functionality.
 * No direct access to core/runtime classes is allowed.
 */
interface PluginContext {

    /** The ID of the plugin this context belongs to */
    val pluginId: String

    /** Plugin-specific data directory for persistent storage */
    val dataDir: File

    /**
     * Resolve a service by its interface type.
     * @return the service implementation, or null if not registered
     */
    fun <T : NerdinService> getService(type: Class<T>): T?

    /**
     * Get all registered extensions of a given type.
     * Extensions are contributions from other plugins.
     */
    fun <T> getExtensions(type: Class<T>): List<T>

    /**
     * Publish an event to the global event bus.
     * All plugins subscribed to this event type will receive it.
     */
    fun publishEvent(event: NerdinEvent)

    /**
     * Subscribe to events of a specific type.
     * @return a Disposable to cancel the subscription
     */
    fun <T : NerdinEvent> subscribe(type: Class<T>, handler: (T) -> Unit): Disposable

    /**
     * Check if the current plugin has a specific permission granted.
     */
    fun checkPermission(permission: Permission): Boolean

    /**
     * Register a service provided by this plugin.
     * Once registered, the service becomes discoverable by other plugins via [getService].
     *
     * @param type The interface class the service implements
     * @param service The service implementation instance
     */
    fun <T : NerdinService> registerService(type: Class<T>, service: T)

    /**
     * Register an extension contribution.
     * Extensions are contributions from plugins that extend core functionality.
     * Multiple plugins can register extensions of the same type.
     * Registered extensions can be retrieved by other plugins via [getExtensions].
     *
     * @param type The extension interface class
     * @param extension The extension implementation
     */
    fun <T : Any> registerExtension(type: Class<T>, extension: T)

    /**
     * Request one or more permissions from the user.
     * @return true if all permissions were granted
     */
    suspend fun requestPermissions(vararg permissions: Permission): Boolean
}
