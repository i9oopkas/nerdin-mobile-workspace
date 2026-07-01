package app.nerdin.plugins.llm.api

import app.nerdin.core.api.Tool

data class ChatRequest(
    val model: String,
    val messages: List<ChatMessage>,
    val temperature: Float = 0.7f,
    val maxTokens: Int = 4096,
    val stream: Boolean = false,
    val tools: List<Tool> = emptyList()
)

data class ChatMessage(
    val role: ChatRole,
    val content: String,
    val name: String? = null
)

enum class ChatRole { SYSTEM, USER, ASSISTANT, TOOL }
