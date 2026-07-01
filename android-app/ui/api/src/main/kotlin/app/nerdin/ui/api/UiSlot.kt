package app.nerdin.ui.api

/**
 * A named position in the UI layout tree.
 * Built-in slots are defined in [BuiltInSlots].
 * Plugins can define their own slots via [SlotContributor].
 *
 * @param id           Unique path, e.g. "topbar.end" or "main.sidebar.debug"
 * @param parentId     Parent slot path, or null for root slots
 * @param position     Where this slot renders relative to siblings
 * @param label        Human-readable name for debugging/Ui configuration
 * @param defaultVisible Whether this slot is visible by default
 */
data class UiSlot(
    val id: String,
    val parentId: String?,
    val position: SlotPosition,
    val label: String,
    val defaultVisible: Boolean = true
)
