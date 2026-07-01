package app.nerdin.plugins.llm.api

import app.nerdin.core.api.NerdinService
import kotlinx.coroutines.flow.Flow

interface LLMProvider : NerdinService {
    val providerId: String
    val displayName: String
    suspend fun chat(request: ChatRequest): ChatResponse
    suspend fun stream(request: ChatRequest): Flow<ChatChunk>
}
