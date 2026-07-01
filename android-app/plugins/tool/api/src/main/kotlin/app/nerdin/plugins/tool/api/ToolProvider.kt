package app.nerdin.plugins.tool.api

import app.nerdin.core.api.NerdinService
import app.nerdin.core.api.Tool
import app.nerdin.core.api.ToolResult

interface ToolProvider : NerdinService {
    suspend fun listTools(): List<Tool>
    suspend fun execute(toolId: String, args: Map<String, Any>): ToolResult
}
