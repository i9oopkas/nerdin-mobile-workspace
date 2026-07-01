package app.nerdin.core.runtime.container

import app.nerdin.core.api.NerdinService

/**
 * Wrapper around a service instance with metadata.
 */
class ServiceProvider<T : NerdinService>(
    val service: T,
    val type: Class<T>,
    val scope: ServiceScope,
    val pluginId: String? = null
)
