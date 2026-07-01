package app.nerdin.ui.api

import app.nerdin.core.api.ExtensionPoint

/**
 * A plugin implements this interface to DECLARE a new UI slot in the layout tree.
 * The slot is then available for any plugin (including the declaring one) to fill.
 */
interface SlotContributor : ExtensionPoint<SlotContributor> {
    /** Define the new slot */
    fun defineSlot(): UiSlot

    /** Optional default provider for this slot (plugin's own default UI) */
    val defaultProvider: UiProvider?
        get() = null
}
