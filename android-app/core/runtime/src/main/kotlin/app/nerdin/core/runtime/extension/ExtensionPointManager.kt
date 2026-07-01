package app.nerdin.core.runtime.extension

import app.nerdin.core.api.ExtensionChangedEvent
import app.nerdin.core.api.NerdinEvent
import app.nerdin.core.api.NerdinService
import app.nerdin.core.runtime.event.EventBus

/**
 * Manages all extension points in the system.
 * Plugins register extensions here that other plugins can discover.
 */
class ExtensionPointManager(private val eventBus: EventBus) : NerdinService {

    private val extensionPoints = mutableMapOf<Class<*>, MutableList<Any>>()

    @Suppress("UNCHECKED_CAST")
    fun <T : Any> register(type: Class<T>, extension: T) {
        val list = extensionPoints.getOrPut(type) { mutableListOf() }
        list.add(extension)
        eventBus.publish(ExtensionChangedEvent(
            extensionType = type,
            changeType = ExtensionChangedEvent.ChangeType.REGISTERED
        ))
    }

    @Suppress("UNCHECKED_CAST")
    fun <T : Any> unregister(type: Class<T>, extension: T) {
        extensionPoints[type]?.remove(extension)
        eventBus.publish(ExtensionChangedEvent(
            extensionType = type,
            changeType = ExtensionChangedEvent.ChangeType.UNREGISTERED
        ))
    }

    @Suppress("UNCHECKED_CAST")
    fun <T> getExtensions(type: Class<T>): List<T> {
        return (extensionPoints[type] as? List<T>) ?: emptyList()
    }

    fun clear() {
        extensionPoints.clear()
    }
}
