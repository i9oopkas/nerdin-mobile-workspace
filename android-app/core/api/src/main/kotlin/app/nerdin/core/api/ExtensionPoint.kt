package app.nerdin.core.api

/**
 * A typed extension point that allows plugins to register and unregister
 * extensions. Extensions are contributions from plugins that extend core
 * functionality.
 *
 * @param T The type of extension this point manages
 */
interface ExtensionPoint<T> {

    /**
     * Register an extension. Once registered, the extension will be returned
     * by [getExtensions] and notified via [ExtensionChangedEvent].
     */
    fun register(extension: T)

    /**
     * Unregister a previously registered extension.
     */
    fun unregister(extension: T)

    /**
     * Get all currently registered extensions.
     */
    fun getExtensions(): List<T>
}

/**
 * Event emitted when an extension is registered or unregistered.
 *
 * @param extensionType The class of the extension type
 * @param changeType Whether the extension was registered or unregistered
 */
data class ExtensionChangedEvent(
    val extensionType: Class<*>,
    val changeType: ChangeType
) : NerdinEvent {

    enum class ChangeType {
        REGISTERED,
        UNREGISTERED
    }
}
