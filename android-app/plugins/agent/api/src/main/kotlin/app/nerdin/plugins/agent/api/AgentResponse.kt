package app.nerdin.plugins.agent.api

data class AgentResponse(
    val agentId: String,
    val result: String,
    val steps: List<AgentStep> = emptyList(),
    val usage: TokenUsage? = null
) {
    data class TokenUsage(
        val promptTokens: Int,
        val completionTokens: Int,
        val totalTokens: Int
    )
}

data class AgentStep(
    val step: Int,
    val action: String,
    val input: String,
    val output: String
)

sealed interface AgentEvent {
    data class Thinking(val thought: String) : AgentEvent
    data class ToolCall(val toolId: String, val args: Map<String, Any>) : AgentEvent
    data class ToolResult(val toolId: String, val result: String) : AgentEvent
    data class Error(val message: String) : AgentEvent
    data object Complete : AgentEvent
    data class Chunk(val text: String) : AgentEvent
}
