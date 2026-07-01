package app.nerdin.plugins.memory.api

data class MemoryEntry(
    val key: String,
    val value: String,
    val metadata: Map<String, String> = emptyMap(),
    val score: Float = 0.0f,
    val timestamp: Long = System.currentTimeMillis()
)
