package app.nerdin.plugins.llm.api

data class ChatResponse(
    val model: String,
    val message: ChatMessage,
    val usage: TokenUsage? = null
)

data class ChatChunk(
    val model: String,
    val delta: String,
    val finishReason: String? = null
)

data class TokenUsage(
    val promptTokens: Int,
    val completionTokens: Int,
    val totalTokens: Int
)
