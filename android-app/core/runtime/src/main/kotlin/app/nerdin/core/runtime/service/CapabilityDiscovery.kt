package app.nerdin.core.runtime.service

import app.nerdin.core.api.NerdinService
import app.nerdin.core.api.Tool
import app.nerdin.core.api.ExtensionPoint

/**
 * Builds a map of all capabilities available in the system.
 * Discovers what services, tools, and extensions are registered.
 */
class CapabilityDiscovery(
    private val serviceRegistry: ServiceRegistry
) {
    data class SystemCapabilities(
        val services: Map<String, String>,     // serviceId -> implementation
        val tools: List<Tool>,
        val extensionPoints: List<String>
    )

    fun discover(): SystemCapabilities {
        val services = serviceRegistry.allServices().mapNotNull { (type, _) ->
            type.simpleName to type.name
        }.toMap()

        return SystemCapabilities(
            services = services,
            tools = emptyList(),   // populated by ToolProviders
            extensionPoints = emptyList()
        )
    }
}
