package app.nerdin.core.api

/**
 * Describes a callable tool/function that can be invoked by an LLM or agent.
 *
 * @param id Unique identifier for this tool
 * @param name Human-readable name
 * @param description Description of what the tool does, used by the LLM to decide when to call it
 * @param inputSchema JSON schema describing the expected input parameters
 */
data class Tool(
    val id: String,
    val name: String,
    val description: String,
    val inputSchema: Map<String, Any> = emptyMap()
)

/**
 * The result of a tool invocation.
 *
 * @param success Whether the tool completed successfully
 * @param data Optional result data (e.g. JSON string, structured result)
 * @param error Optional error message if the tool failed
 */
data class ToolResult(
    val success: Boolean,
    val data: String? = null,
    val error: String? = null
)
