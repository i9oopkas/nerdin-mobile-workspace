package app.nerdin.plugins.agent.api

import app.nerdin.core.api.NerdinService
import kotlinx.coroutines.flow.Flow

interface AgentProvider : NerdinService {
    val agentId: String
    val displayName: String
    suspend fun execute(request: AgentRequest): AgentResponse
    suspend fun stream(request: AgentRequest): Flow<AgentEvent>
}
