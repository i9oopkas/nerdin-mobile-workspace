package app.nerdin.plugins.memory.api

import app.nerdin.core.api.NerdinService

interface MemoryProvider : NerdinService {
    val name: String
    suspend fun save(key: String, value: String, metadata: Map<String, String> = emptyMap())
    suspend fun get(key: String): String?
    suspend fun search(query: String, limit: Int = 10): List<MemoryEntry>
    suspend fun delete(key: String)
    suspend fun clear()
}
