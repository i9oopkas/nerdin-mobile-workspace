package app.nerdin.ui.api

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier

/**
 * Renders all UiProvider content for a given slot.
 *
 * For simple slots (toolbar actions, buttons): renders all providers in a Row/Flow.
 * For content slots ("main.content"): renders the highest-priority provider.
 * For slots with no providers: renders nothing (invisible).
 *
 * @param slotId     The slot to render
 * @param modifier   Modifier for the slot container
 * @param single     If true, renders only the highest-priority provider (for main content slots)
 * @param layoutRegistry The registry to resolve providers from
 */
@Composable
fun SlotContainer(
    slotId: String,
    modifier: Modifier = Modifier,
    single: Boolean = false,
    layoutRegistry: LayoutRegistry
) {
    val providers = remember(slotId, layoutRegistry) {
        layoutRegistry.getProviders(slotId)
    }

    if (providers.isEmpty()) return

    if (single) {
        // Render the highest-priority provider
        Box(modifier = modifier) {
            providers.first().Content()
        }
    } else {
        // Render all providers (for toolbar buttons, sidebar items, etc.)
        Box(modifier = modifier) {
            providers.forEach { provider ->
                provider.Content()
            }
        }
    }
}
