package app.nerdin.core.runtime.container

import app.nerdin.core.api.NerdinService

/**
 * Core dependency injection container.
 * Manages service lifecycle and scopes.
 * Hand-written DI — no Koin/Dagger dependency.
 */
class ServiceContainer {

    private val services = mutableMapOf<Class<*>, ServiceProvider<*>>()
    private val scopedServices = mutableMapOf<ServiceScope, MutableList<Class<*>>>()

    companion object {
        fun create(): ServiceContainer = ServiceContainer()
    }

    @Suppress("UNCHECKED_CAST")
    fun <T : NerdinService> register(
        service: T,
        type: Class<T>,
        scope: ServiceScope = ServiceScope.CORE,
        pluginId: String? = null
    ) {
        services[type] = ServiceProvider(service, type, scope, pluginId)
        scopedServices.getOrPut(scope) { mutableListOf() }.add(type)
    }

    @Suppress("UNCHECKED_CAST")
    fun <T : NerdinService> resolve(type: Class<T>): T? {
        return (services[type]?.service as? T)
    }

    fun <T : NerdinService> unregister(type: Class<T>) {
        services.remove(type)
        scopedServices.values.forEach { it.remove(type) }
    }

    fun unregisterByPlugin(pluginId: String) {
        val toRemove = services.filter { (_, provider) ->
            provider.pluginId == pluginId
        }.keys
        toRemove.forEach { services.remove(it) }
        scopedServices.values.forEach { it.removeAll(toRemove) }
    }

    fun clearScope(scope: ServiceScope) {
        scopedServices[scope]?.toList()?.forEach { services.remove(it) }
        scopedServices[scope]?.clear()
    }

    fun clear() {
        services.clear()
        scopedServices.clear()
    }

    fun allServices(): List<Pair<Class<*>, Any>> {
        return services.map { (type, provider) -> type to provider.service }
    }
}
