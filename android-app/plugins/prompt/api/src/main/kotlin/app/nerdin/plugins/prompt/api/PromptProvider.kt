package app.nerdin.plugins.prompt.api

import app.nerdin.core.api.NerdinService

interface PromptProvider : NerdinService {
    suspend fun getPrompt(id: String): String?
    suspend fun listPrompts(): List<PromptInfo>
    suspend fun savePrompt(info: PromptInfo, content: String)
    suspend fun deletePrompt(id: String)
}
