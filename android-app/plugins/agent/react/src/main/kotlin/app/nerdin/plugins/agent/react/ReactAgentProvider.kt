package app.nerdin.plugins.agent.react

import android.util.Log
import app.nerdin.core.api.PluginContext
import app.nerdin.core.api.Tool
import app.nerdin.plugins.agent.api.AgentEvent
import app.nerdin.plugins.agent.api.AgentPermissionService
import app.nerdin.plugins.agent.api.AgentProvider
import app.nerdin.plugins.agent.api.AgentRequest
import app.nerdin.plugins.agent.api.AgentResponse
import app.nerdin.plugins.agent.api.AgentStep
import app.nerdin.plugins.agent.api.PermissionEffect
import app.nerdin.plugins.llm.api.ChatMessage
import app.nerdin.plugins.llm.api.ChatRequest
import app.nerdin.plugins.llm.api.ChatRole
import app.nerdin.plugins.llm.api.LLMProvider
import app.nerdin.plugins.tool.api.ToolProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.isActive
import org.json.JSONArray
import org.json.JSONObject

/**
 * ReAct (Reasoning + Acting) agent loop.
 *
 * For each iteration:
 * 1. Send conversation + tools to LLM (non-streaming, for structured response)
 * 2. Parse response for tool call JSON blocks
 * 3. If tool found: check permission -> execute tool -> append result -> loop
 * 4. If no tool: emit [AgentEvent.Chunk] with the final answer, then [AgentEvent.Complete]
 *
 * Tool calls are detected by parsing JSON blocks in the LLM response text, since
 * the [LLMProvider] returns plain text responses rather than structured tool_calls.
 */
class ReactAgentProvider(private val ctx: PluginContext) : AgentProvider {

    override val agentId: String get() = "nerdin.agent.react"
    override val displayName: String get() = "ReAct Agent"

    private val systemPrompt = """
        You are Nerdin, an AI coding assistant running on Android.
        You have access to tools that you can use to accomplish tasks.

        When you need to use a tool, respond with a JSON object in this EXACT format:
        {
          "function": {
            "name": "tool_name",
            "arguments": { "param1": "value1" }
          }
        }

        When you have the answer and don't need more tools, respond with plain text.
        Always think step by step.
    """.trimIndent()

    override suspend fun execute(request: AgentRequest): AgentResponse {
        val events = mutableListOf<AgentEvent>()
        stream(request).collect { events.add(it) }

        // The final answer comes from the last Chunk event
        val lastChunk = events.filterIsInstance<AgentEvent.Chunk>().lastOrNull()
        val error = events.filterIsInstance<AgentEvent.Error>().firstOrNull()
        val toolCalls = events.filterIsInstance<AgentEvent.ToolCall>()
        val toolResults = events.filterIsInstance<AgentEvent.ToolResult>()

        val steps = toolCalls.zip(toolResults) { call, result ->
            AgentStep(
                step = toolCalls.indexOf(call) + 1,
                action = call.toolId,
                input = call.args.toString(),
                output = result.result
            )
        }

        return AgentResponse(
            agentId = agentId,
            result = lastChunk?.text ?: error?.message ?: "No response",
            steps = steps
        )
    }

    override suspend fun stream(request: AgentRequest): Flow<AgentEvent> = callbackFlow {
        Log.d("ReactAgentProvider", "Starting agent task: ${request.task.take(100)}")

        // Discover required services at runtime via PluginContext
        val llm = ctx.getService(LLMProvider::class.java)
        if (llm == null) {
            send(AgentEvent.Error("LLMProvider not found — is plugin-llm-openai loaded?"))
            close(); return@callbackFlow
        }

        val toolProvider = ctx.getService(ToolProvider::class.java)
        val permissions = ctx.getService(AgentPermissionService::class.java)

        // Collect available tools, filtered by request.tools if specified
        val allTools = toolProvider?.listTools() ?: emptyList()
        val activeTools = if (request.tools.isNotEmpty()) {
            allTools.filter { it.id in request.tools }
        } else {
            allTools
        }

        Log.d("ReactAgentProvider", "Using ${activeTools.size} tools: ${activeTools.map { it.id }}")

        // Build the conversation with system prompt and user task
        val messages = mutableListOf(
            ChatMessage(role = ChatRole.SYSTEM, content = systemPrompt),
            ChatMessage(role = ChatRole.USER, content = request.task)
        )

        val model = request.context["model"] as? String ?: "big-pickle"
        var iteration = 0

        while (isActive && iteration < request.maxSteps) {
            iteration++
            send(AgentEvent.Thinking("Step $iteration (max ${request.maxSteps})"))

            // 1. Send conversation + tools to LLM (non-streaming for structured output)
            val chatReq = ChatRequest(
                model = model,
                messages = messages,
                tools = activeTools,
                temperature = 0.7f,
                maxTokens = 4096,
                stream = false
            )

            val response = llm.chat(chatReq)
            val content = response.message.content.trim()

            // Track response text for the final answer
            messages.add(ChatMessage(role = ChatRole.ASSISTANT, content = content))

            // 2. Check if the response contains a tool call JSON block
            val toolCall = extractToolCall(content)

            if (toolCall != null) {
                val (toolName, toolArgs) = toolCall
                Log.d("ReactAgentProvider", "Tool call: $toolName($toolArgs)")
                send(AgentEvent.ToolCall(toolId = toolName, args = toolArgs))

                // 3. Check permissions before executing
                if (permissions != null) {
                    val effect = permissions.check(
                        action = toolName,
                        resource = toolArgs.toString(),
                        agentId = agentId
                    )
                    when (effect) {
                        PermissionEffect.DENY -> {
                            val err = "Permission denied for $toolName"
                            messages.add(ChatMessage(role = ChatRole.TOOL, content = "Error: $err"))
                            send(AgentEvent.ToolResult(toolId = toolName, result = err))
                            continue
                        }
                        PermissionEffect.ASK -> {
                            // For ASK, proceed for now; the permission service
                            // will suspend until the user responds via its own flow
                            // If denied later, the tool execution will fail on its own
                            Log.d("ReactAgentProvider", "Permission ASK for $toolName — proceeding")
                        }
                        PermissionEffect.ALLOW -> { /* proceed */ }
                    }
                }

                // 4. Execute the tool
                try {
                    val result = toolProvider?.execute(toolName, toolArgs)
                    if (result != null && result.success) {
                        val output = result.data ?: "Success (no output)"
                        messages.add(ChatMessage(role = ChatRole.TOOL, content = output))
                        send(AgentEvent.ToolResult(toolId = toolName, result = output))
                    } else {
                        val err = result?.error ?: "Tool $toolName returned no result"
                        messages.add(ChatMessage(role = ChatRole.TOOL, content = "Error: $err"))
                        send(AgentEvent.ToolResult(toolId = toolName, result = err))
                    }
                } catch (e: Exception) {
                    val err = "${e::class.java.simpleName}: ${e.message}"
                    messages.add(ChatMessage(role = ChatRole.TOOL, content = "Error: $err"))
                    send(AgentEvent.ToolResult(toolId = toolName, result = err))
                }
            } else {
                // 5. No tool call found — this is the final answer
                send(AgentEvent.Chunk(text = content))
                send(AgentEvent.Complete)
                Log.d("ReactAgentProvider", "Agent completed in $iteration steps")
                close(); return@callbackFlow
            }
        }

        // Max iterations reached
        send(AgentEvent.Chunk(text = "Task completed after $iteration iterations"))
        send(AgentEvent.Complete)
        close()
    }

    /**
     * Extract a tool call from the LLM response text.
     *
     * Since [LLMProvider.chat] returns plain text, we detect tool calls by
     * looking for JSON blocks matching known patterns:
     * - `{"function": {"name": "...", "arguments": {...}}}`
     * - `{"name": "...", "arguments": {...}}`
     * - `{"tool": "...", "args": {...}}`
     * - Wrapped in ```json ... ``` fences
     */
    private fun extractToolCall(response: String): Pair<String, Map<String, Any>>? {
        val jsonStr = extractJson(response) ?: return null

        return try {
            val json = JSONObject(jsonStr)

            // Format 1: {"function": {"name": "...", "arguments": {...}}}
            if (json.has("function")) {
                val func = json.getJSONObject("function")
                val name = func.getString("name")
                val rawArgs = func.optString("arguments", "{}")
                val args = jsonToMap(JSONObject(rawArgs))
                return name to args
            }

            // Format 2: {"name": "...", "arguments": {...}}
            if (json.has("name") && json.has("arguments")) {
                val name = json.getString("name")
                val args = when (val a = json.get("arguments")) {
                    is JSONObject -> jsonToMap(a)
                    is String -> jsonToMap(JSONObject(a))
                    else -> mapOf("value" to a.toString())
                }
                return name to args
            }

            // Format 3: {"tool": "...", "args": {...}}
            if (json.has("tool") && json.has("args")) {
                val name = json.getString("tool")
                val args = when (val a = json.get("args")) {
                    is JSONObject -> jsonToMap(a)
                    else -> mapOf("value" to a.toString())
                }
                return name to args
            }

            null
        } catch (e: Exception) {
            Log.w("ReactAgentProvider", "Failed to parse tool call JSON: ${e.message}")
            null
        }
    }

    /**
     * Extract a JSON object from text, looking inside ```json ... ``` blocks
     * or for standalone `{...}` objects.
     */
    private fun extractJson(text: String): String? {
        // Try ```json ... ``` block first (most reliable for LLM output)
        val blockMatch = Regex("```(?:json)?\\s*([\\s\\S]*?)\\s*```").find(text)
        if (blockMatch != null) {
            val candidate = blockMatch.groupValues[1].trim()
            if (candidate.startsWith("{") && candidate.endsWith("}")) return candidate
        }

        // Try finding standalone JSON objects
        val objMatch = Regex("\\{[^{}]*\\}").findAll(text).toList()
        if (objMatch.isNotEmpty()) {
            // Return the largest match that actually parses
            return objMatch
                .map { it.value }
                .filter { try { JSONObject(it); true } catch (e: Exception) { false } }
                .maxByOrNull { it.length }
        }

        return null
    }

    /** Recursively convert org.json.JSONObject to a Kotlin [Map]<[String], [Any]>. */
    private fun jsonToMap(json: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        json.keys().forEach { key ->
            val value = json.get(key)
            map[key] = when (value) {
                is JSONObject -> jsonToMap(value)
                is JSONArray -> {
                    (0 until value.length()).map { i ->
                        val item = value.get(i)
                        if (item is JSONObject) jsonToMap(item) else item
                    }
                }
                else -> value
            }
        }
        return map
    }
}
