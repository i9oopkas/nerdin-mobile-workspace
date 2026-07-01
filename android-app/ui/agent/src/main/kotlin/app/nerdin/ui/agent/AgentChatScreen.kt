package app.nerdin.ui.agent

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.nerdin.core.api.PluginContext
import app.nerdin.plugins.agent.api.AgentEvent
import app.nerdin.plugins.agent.api.AgentProvider
import app.nerdin.plugins.agent.api.AgentRequest
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.cancellable
import kotlinx.coroutines.launch

/**
 * Represents a single message in the chat UI.
 */
data class ChatUiMessage(
    val id: Long,
    val role: String,        // "user", "assistant", "system", "tool", "error"
    val text: String,
    val isStreaming: Boolean = false,
)

@Composable
fun AgentChatScreen(
    pluginContext: PluginContext,
    modifier: Modifier = Modifier,
) {
    val messages = remember { mutableStateListOf<ChatUiMessage>() }
    var inputText by remember { mutableStateOf("") }
    var isStreaming by remember { mutableStateOf(false) }
    var messageIdCounter by remember { mutableStateOf(0L) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    Column(modifier = modifier.fillMaxSize()) {
        // Messages area
        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (messages.isEmpty()) {
                // Empty state
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = "Start a conversation with Nerdin",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(
                        horizontal = 16.dp,
                        vertical = 8.dp
                    )
                ) {
                    items(messages, key = { it.id }) { msg ->
                        MessageBubble(message = msg)
                    }
                }
            }
        }

        // Auto-scroll to bottom on new messages
        LaunchedEffect(messages.size, messages.lastOrNull()?.text?.length) {
            if (messages.isNotEmpty()) {
                listState.animateScrollToItem(messages.size - 1)
            }
        }

        // Input area
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = inputText,
                onValueChange = { inputText = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Ask Nerdin...") },
                enabled = !isStreaming,
                maxLines = 4,
                shape = RoundedCornerShape(12.dp),
            )

            Spacer(Modifier.width(8.dp))

            if (isStreaming) {
                OutlinedButton(onClick = {
                    isStreaming = false
                }) {
                    Text("Stop")
                }
            } else {
                Button(
                    onClick = {
                        val text = inputText.trim()
                        if (text.isEmpty()) return@Button

                        inputText = ""
                        val userMsgId = ++messageIdCounter
                        messages.add(
                            ChatUiMessage(
                                id = userMsgId,
                                role = "user",
                                text = text,
                            )
                        )

                        // Start agent
                        isStreaming = true
                        val assistantMsgId = ++messageIdCounter
                        messages.add(
                            ChatUiMessage(
                                id = assistantMsgId,
                                role = "assistant",
                                text = "",
                                isStreaming = true,
                            )
                        )

                        scope.launch {
                            try {
                                val agentProvider = pluginContext.getService(AgentProvider::class.java)
                                if (agentProvider == null) {
                                    messages.add(
                                        ChatUiMessage(
                                            id = ++messageIdCounter,
                                            role = "error",
                                            text = "AgentProvider not found — is agent-react plugin loaded?",
                                        )
                                    )
                                    isStreaming = false
                                    return@launch
                                }

                                agentProvider.stream(
                                    AgentRequest(
                                        agentId = agentProvider.agentId,
                                        task = text,
                                        tools = emptyList(),
                                        maxSteps = 10,
                                    )
                                ).cancellable().collect { event ->
                                    if (!isStreaming) {
                                        currentCoroutineContext().cancel()
                                        return@collect
                                    }

                                    when (event) {
                                        is AgentEvent.Chunk -> {
                                            val idx = messages.indexOfLast { it.id == assistantMsgId }
                                            if (idx >= 0) {
                                                messages[idx] = messages[idx].copy(
                                                    text = messages[idx].text + event.text
                                                )
                                            }
                                        }
                                        is AgentEvent.Complete -> {
                                            val idx = messages.indexOfLast { it.id == assistantMsgId }
                                            if (idx >= 0) {
                                                messages[idx] = messages[idx].copy(isStreaming = false)
                                            }
                                            isStreaming = false
                                        }
                                        is AgentEvent.ToolCall -> {
                                            messages.add(
                                                ChatUiMessage(
                                                    id = ++messageIdCounter,
                                                    role = "system",
                                                    text = "🔧 Using tool: ${event.toolId}",
                                                )
                                            )
                                        }
                                        is AgentEvent.ToolResult -> {
                                            messages.add(
                                                ChatUiMessage(
                                                    id = ++messageIdCounter,
                                                    role = "tool",
                                                    text = event.result.take(200) +
                                                            if (event.result.length > 200) "..." else "",
                                                )
                                            )
                                        }
                                        is AgentEvent.Error -> {
                                            messages.add(
                                                ChatUiMessage(
                                                    id = ++messageIdCounter,
                                                    role = "error",
                                                    text = event.message,
                                                )
                                            )
                                            val idx = messages.indexOfLast { it.id == assistantMsgId }
                                            if (idx >= 0) {
                                                messages[idx] = messages[idx].copy(isStreaming = false)
                                            }
                                            isStreaming = false
                                        }
                                        is AgentEvent.Thinking -> {
                                            // Optionally update a status indicator
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                messages.add(
                                    ChatUiMessage(
                                        id = ++messageIdCounter,
                                        role = "error",
                                        text = "Error: ${e.message ?: e::class.java.simpleName}",
                                    )
                                )
                            } finally {
                                isStreaming = false
                            }
                        }
                    },
                    enabled = inputText.isNotBlank() && !isStreaming,
                ) {
                    Text("Send")
                }
            }
        }

        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun MessageBubble(message: ChatUiMessage) {
    val isUser = message.role == "user"
    val backgroundColor = when (message.role) {
        "user" -> MaterialTheme.colorScheme.primaryContainer
        "assistant" -> MaterialTheme.colorScheme.secondaryContainer
        "system" -> MaterialTheme.colorScheme.tertiaryContainer
        "tool" -> MaterialTheme.colorScheme.surfaceVariant
        "error" -> MaterialTheme.colorScheme.errorContainer
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    val textColor = when (message.role) {
        "error" -> MaterialTheme.colorScheme.onErrorContainer
        else -> MaterialTheme.colorScheme.onSurface
    }
    val label = when (message.role) {
        "user" -> "You"
        "assistant" -> "Nerdin"
        "system" -> "System"
        "tool" -> "Tool"
        "error" -> "Error"
        else -> message.role
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
    ) {
        Card(
            shape = RoundedCornerShape(
                topStart = 12.dp,
                topEnd = 12.dp,
                bottomStart = if (isUser) 12.dp else 4.dp,
                bottomEnd = if (isUser) 4.dp else 12.dp,
            ),
            colors = CardDefaults.cardColors(containerColor = backgroundColor),
            modifier = Modifier.widthIn(max = 320.dp),
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = textColor.copy(alpha = 0.6f),
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = message.text,
                    style = MaterialTheme.typography.bodyMedium,
                    color = textColor,
                )
                if (message.isStreaming) {
                    AnimatedVisibility(visible = true) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .padding(top = 4.dp)
                                .height(8.dp)
                                .width(8.dp),
                            strokeWidth = 2.dp,
                        )
                    }
                }
            }
        }
    }
}
