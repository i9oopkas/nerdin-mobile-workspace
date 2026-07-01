package app.nerdin.core.api

/**
 * A resource that can be disposed (e.g. event subscriptions, listeners).
 * Implementations should release any held resources when [dispose] is called.
 */
fun interface Disposable {
    fun dispose()
}
