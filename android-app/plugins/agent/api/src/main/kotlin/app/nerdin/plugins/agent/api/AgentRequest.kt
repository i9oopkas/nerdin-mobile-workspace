package app.nerdin.plugins.agent.api

data class AgentRequest(
    val agentId: String,
    val task: String,
    val context: Map<String, Any> = emptyMap(),
    val tools: List<String> = emptyList(),
    val maxSteps: Int = 25
)
