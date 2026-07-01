package app.nerdin.plugins.llm.api

import app.nerdin.core.api.NerdinService

interface EmbeddingProvider : NerdinService {
    suspend fun embed(text: String): List<Float>
    suspend fun embedBatch(texts: List<String>): List<List<Float>>
    val dimensions: Int
}
