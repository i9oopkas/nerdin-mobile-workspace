package app.nerdin.core.runtime

import app.nerdin.core.api.Disposable
import app.nerdin.core.api.NerdinEvent
import app.nerdin.core.api.NerdinService
import app.nerdin.core.api.Permission
import app.nerdin.core.api.PluginContext
import java.io.File

/**
 * Implementation of PluginContext for the core runtime.
 * Bridges between the plugin API (contracts) and core runtime (implementation).
 */
class CorePluginContext(
    private val core: NerdinCore,
    override val pluginId: String
) : PluginContext {

    override val dataDir: File by lazy {
        File(core.context.filesDir, "plugins/$pluginId").also { it.mkdirs() }
    }

    override fun <T : NerdinService> getService(type: Class<T>): T? {
        return core.serviceRegistry.resolve(type)
    }

    override fun <T : NerdinService> registerService(type: Class<T>, service: T) {
        core.serviceRegistry.register(type, service)
    }

    override fun <T : Any> registerExtension(type: Class<T>, extension: T) {
        core.extensionPointManager.register(type, extension)
    }

    @Suppress("UNCHECKED_CAST")
    override fun <T> getExtensions(type: Class<T>): List<T> {
        return core.serviceContainer.resolve(app.nerdin.core.runtime.extension.ExtensionPointManager::class.java)
            ?.getExtensions(type)
            ?: emptyList()
    }

    override fun publishEvent(event: NerdinEvent) {
        core.eventBus.publish(event)
    }

    override fun <T : NerdinEvent> subscribe(type: Class<T>, handler: (T) -> Unit): Disposable {
        return core.eventBus.subscribe(type, handler)
    }

    override fun checkPermission(permission: Permission): Boolean {
        return core.permissionManager.checkPermission(permission)
    }

    override suspend fun requestPermissions(vararg permissions: Permission): Boolean {
        val denied = core.permissionManager.checkPermissions(permissions.toList())
        return denied.isEmpty()
    }
}
