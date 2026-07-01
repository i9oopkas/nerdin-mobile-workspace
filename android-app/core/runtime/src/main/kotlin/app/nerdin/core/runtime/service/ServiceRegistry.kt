package app.nerdin.core.runtime.service

import app.nerdin.core.api.NerdinService
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Service registry that tracks all registered services
 * and allows observation of service changes.
 * Wraps ServiceContainer with reactive capabilities.
 */
class ServiceRegistry : NerdinService {

    private val _changes = MutableSharedFlow<ServiceChangeEvent>(
        replay = 0,
        extraBufferCapacity = 32
    )
    val changes: Flow<ServiceChangeEvent> = _changes.asSharedFlow()

    data class ServiceChangeEvent(
        val type: Class<*>,
        val changeType: ChangeType,
        val service: NerdinService?
    ) {
        enum class ChangeType { REGISTERED, UNREGISTERED }
    }

    private val services = mutableMapOf<Class<*>, NerdinService>()

    @Suppress("UNCHECKED_CAST")
    fun <T : NerdinService> register(type: Class<T>, service: T) {
        services[type] = service
        _changes.tryEmit(ServiceChangeEvent(type, ServiceChangeEvent.ChangeType.REGISTERED, service))
    }

    @Suppress("UNCHECKED_CAST")
    fun <T : NerdinService> resolve(type: Class<T>): T? {
        return services[type] as? T
    }

    fun <T : NerdinService> unregister(type: Class<T>) {
        val removed = services.remove(type)
        if (removed != null) {
            _changes.tryEmit(ServiceChangeEvent(type, ServiceChangeEvent.ChangeType.UNREGISTERED, removed))
        }
    }

    fun allServices(): Map<Class<*>, NerdinService> = services.toMap()

    fun clear() {
        services.clear()
    }
}
