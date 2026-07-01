package app.nerdin.ui.agent

import androidx.compose.runtime.Composable
import app.nerdin.core.api.PluginContext
import app.nerdin.ui.api.UiProvider

/**
 * Registers the agent chat screen as a UI provider for the "main.content.chat" slot.
 * This allows the LayoutHost to discover and render the chat screen.
 */
class AgentChatUiProvider(private val pluginContext: PluginContext) : UiProvider {

    override val slotId: String = "main.content.chat"
    override val id: String = "nerdin.ui.agent.chat"
    override val label: String = "Agent Chat"
    override val priority: Int = 0

    override fun register(extension: UiProvider) {
        // Registration is handled by PluginContext.registerExtension
    }

    override fun unregister(extension: UiProvider) {
        // Unregistration is handled by PluginContext
    }

    override fun getExtensions(): List<UiProvider> = listOf(this)

    @Composable
    override fun Content() {
        AgentChatScreen(pluginContext = pluginContext)
    }
}
