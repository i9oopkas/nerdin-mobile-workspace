package app.nerdin.ui.api

import androidx.compose.runtime.Composable
import app.nerdin.core.api.ExtensionPoint

/**
 * A plugin implements this interface to provide UI content for a specific slot.
 * Registered via [PluginContext.registerExtension].
 *
 * Multiple plugins can provide UI for the same slot — they will be rendered
 * in priority order.
 */
interface UiProvider : ExtensionPoint<UiProvider> {
    /** The slot ID this provider fills, e.g. "topbar.end", "main.content" */
    val slotId: String

    /** Unique provider ID (pluginId + name), e.g. "nerdin.llm.openai.model-selector" */
    val id: String

    /** Human-readable label for debugging/Ui settings */
    val label: String

    /** Priority: lower number = higher priority. 0=default, 10=normal, 100=low */
    val priority: Int
        get() = 10

    /** Render the content for this slot */
    @Composable
    fun Content()
}
