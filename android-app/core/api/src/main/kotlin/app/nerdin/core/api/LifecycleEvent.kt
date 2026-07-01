package app.nerdin.core.api

/**
 * Event emitted when a plugin transitions between lifecycle states.
 *
 * @param pluginId The ID of the plugin whose state changed
 * @param previousState The state the plugin moved from
 * @param newState The state the plugin moved to
 */
data class PluginLifecycleEvent(
    val pluginId: String,
    val previousState: State,
    val newState: State
) : NerdinEvent {

    enum class State {
        INSTALLED,
        LOADED,
        ENABLED,
        DISABLED,
        UNLOADED
    }
}

/**
 * Event emitted when the core platform transitions between lifecycle phases.
 *
 * @param phase The current lifecycle phase of the core platform
 */
data class CoreLifecycleEvent(
    val phase: Phase
) : NerdinEvent {

    enum class Phase {
        BOOTING,
        LOADING_PLUGINS,
        STARTING_SERVICES,
        READY,
        SHUTTING_DOWN,
        SHUTDOWN
    }
}
