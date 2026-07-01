package app.nerdin.core.runtime.container

enum class ServiceScope {
    /** Service lives as long as the core */
    CORE,

    /** Service lives as long as the plugin that registered it */
    PLUGIN,

    /** Service lives only for the duration of a session/request */
    SESSION
}
