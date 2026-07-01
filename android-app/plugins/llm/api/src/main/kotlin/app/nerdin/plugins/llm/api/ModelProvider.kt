package app.nerdin.plugins.llm.api

import app.nerdin.core.api.NerdinService

interface ModelProvider : NerdinService {
    suspend fun listModels(): List<ModelInfo>
    suspend fun getModel(modelId: String): ModelInfo?
}
