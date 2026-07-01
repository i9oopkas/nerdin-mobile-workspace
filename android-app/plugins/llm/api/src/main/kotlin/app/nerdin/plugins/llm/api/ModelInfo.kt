package app.nerdin.plugins.llm.api

data class ModelInfo(
    val id: String,
    val name: String,
    val provider: String,
    val contextLength: Int,
    val capabilities: List<String> = emptyList()
)
