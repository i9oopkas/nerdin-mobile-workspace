package app.nerdin

import android.app.Application
import app.nerdin.core.api.PluginContext
import app.nerdin.core.runtime.NerdinCore
import app.nerdin.core.runtime.NerdinCoreConfig
import app.nerdin.core.runtime.crash.NerdinCrashHandler
import app.nerdin.ui.api.LayoutRegistry
import kotlinx.coroutines.runBlocking

class NerdinApplication : Application() {

    lateinit var nerdinCore: NerdinCore
        private set
    lateinit var pluginContext: PluginContext
        private set
    lateinit var layoutRegistry: LayoutRegistry
        private set

    override fun onCreate() {
        super.onCreate()

        instance = this

        // Install crash handler — writes to Downloads/Nerdin/ on crash
        Thread.setDefaultUncaughtExceptionHandler(
            NerdinCrashHandler(this)
        )

        // Initialize core
        runBlocking {
            nerdinCore = NerdinCore.create(
                appContext = this@NerdinApplication,
                config = NerdinCoreConfig(
                    pluginDir = filesDir.resolve("plugins"),
                    cacheFile = filesDir.resolve("plugin_registry.json"),
                    extractFromAssets = true,
                    coreVersion = "0.1.0"
                )
            )
            nerdinCore.start()
        }

        pluginContext = nerdinCore.createPluginContext("nerdin.core.shell")
        layoutRegistry = LayoutRegistry(pluginContext)
    }

    companion object {
        lateinit var instance: NerdinApplication
            private set
    }
}
