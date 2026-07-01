package app.nerdin.ui.api

import app.nerdin.core.api.PluginContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Collects all UI slots and providers from plugins and builds the layout tree.
 * Used by the LayoutHost composable to render the UI.
 *
 * This is the central registry that bridges plugin-declared UI with the app shell.
 */
@Singleton
class LayoutRegistry @Inject constructor(
    private val pluginContext: PluginContext
) {
    /** Built-in slots defined by the app shell */
    private val builtInSlots = mutableMapOf<String, UiSlot>()

    /** All discovered slots (built-in + plugin-contributed) */
    val allSlots: Map<String, UiSlot>
        get() {
            val slots = builtInSlots.toMutableMap()
            // Collect plugin-declared slots
            pluginContext.getExtensions(SlotContributor::class.java).forEach { contributor ->
                val slot = contributor.defineSlot()
                slots[slot.id] = slot
            }
            return slots
        }

    fun registerBuiltInSlots(slots: List<UiSlot>) {
        slots.forEach { builtInSlots[it.id] = it }
    }

    /**
     * Get all UiProvider instances for a given slot, sorted by priority.
     * Includes both built-in and plugin-provided providers.
     */
    fun getProviders(slotId: String): List<UiProvider> {
        // Providers can come from two places:
        // 1. Plugin-registered extensions (via registerExtension)
        val pluginProviders = pluginContext.getExtensions(UiProvider::class.java)
            .filter { it.slotId == slotId }
            .sortedBy { it.priority }

        // 2. Default providers from SlotContributors whose slot is this one
        val defaultProviders = pluginContext.getExtensions(SlotContributor::class.java)
            .filter { it.defineSlot().id == slotId }
            .mapNotNull { it.defaultProvider }

        return (defaultProviders + pluginProviders).distinctBy { it.id }
    }

    /**
     * Check if a slot has any visible providers.
     */
    fun hasContent(slotId: String): Boolean {
        return getProviders(slotId).isNotEmpty() ||
                builtInSlots.containsKey(slotId)
    }
}
