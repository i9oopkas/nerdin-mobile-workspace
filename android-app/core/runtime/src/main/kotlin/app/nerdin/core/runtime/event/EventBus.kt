package app.nerdin.core.runtime.event

import app.nerdin.core.api.Disposable
import app.nerdin.core.api.NerdinEvent
import app.nerdin.core.api.NerdinService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Core event bus with support for:
 * - Typed event subscriptions
 * - Priority ordering
 * - Sticky events (latest event by type is replayed to new subscribers)
 * - Synchronous publishing for internal/core events
 * - Async publishing for plugin events
 */
class EventBus : NerdinService {

    private data class Subscription(
        val type: Class<*>,
        val priority: Int,
        val handler: (NerdinEvent) -> Unit,
        val sync: Boolean
    )

    private val subscriptions = mutableListOf<Subscription>()
    private val stickyEvents = mutableMapOf<Class<*>, NerdinEvent>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /**
     * Subscribe to events of the given type.
     * @param priority Higher priority handlers are called first (default 0)
     * @param sync If true, handler is invoked synchronously on the publisher's thread
     */
    @Suppress("UNCHECKED_CAST")
    fun <T : NerdinEvent> subscribe(
        type: Class<T>,
        priority: Int = 0,
        sync: Boolean = false,
        handler: (T) -> Unit
    ): Disposable {
        val sub = Subscription(type, priority, { handler(it as T) }, sync)
        subscriptions.add(sub)
        subscriptions.sortByDescending { it.priority }

        // Deliver sticky event if available
        stickyEvents[type]?.let { event ->
            if (sync) {
                handler(event as T)
            } else {
                scope.launch { handler(event as T) }
            }
        }

        return Disposable { subscriptions.remove(sub) }
    }

    /** Convenience: subscribe with default priority */
    fun <T : NerdinEvent> subscribe(type: Class<T>, handler: (T) -> Unit): Disposable {
        return subscribe(type, priority = 0, handler = handler)
    }

    /**
     * Publish an event asynchronously (default).
     */
    fun publish(event: NerdinEvent) {
        val type = event::class.java
        // Handle sticky events
        stickyEvents[type] = event

        // Dispatch to matching subscriptions
        subscriptions
            .filter { it.type.isAssignableFrom(type) }
            .forEach { sub ->
                if (sub.sync) {
                    sub.handler(event)
                } else {
                    scope.launch { sub.handler(event) }
                }
            }
    }

    /**
     * Publish an event synchronously — all sync handlers are called
     * on the current thread before this method returns.
     * Used for critical internal events.
     */
    fun publishSync(event: NerdinEvent) {
        val type = event::class.java
        stickyEvents[type] = event

        subscriptions
            .filter { it.type.isAssignableFrom(type) && it.sync }
            .forEach { it.handler(event) }

        // Async subscriptions still go to scope
        subscriptions
            .filter { it.type.isAssignableFrom(type) && !it.sync }
            .forEach { scope.launch { it.handler(event) } }
    }

    /**
     * Set a sticky event manually (without triggering handlers).
     */
    fun setSticky(event: NerdinEvent) {
        stickyEvents[event::class.java] = event
    }

    /**
     * Remove a sticky event by type.
     */
    fun clearSticky(type: Class<*>) {
        stickyEvents.remove(type)
    }

    fun clear() {
        subscriptions.clear()
        stickyEvents.clear()
    }
}
