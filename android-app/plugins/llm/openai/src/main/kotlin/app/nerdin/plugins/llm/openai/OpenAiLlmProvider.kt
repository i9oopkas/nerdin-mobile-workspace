package app.nerdin.plugins.llm.openai

import android.util.Log
import app.nerdin.core.api.Tool
import app.nerdin.plugins.llm.api.ChatChunk
import app.nerdin.plugins.llm.api.ChatMessage
import app.nerdin.plugins.llm.api.ChatRequest
import app.nerdin.plugins.llm.api.ChatResponse
import app.nerdin.plugins.llm.api.ChatRole
import app.nerdin.plugins.llm.api.LLMProvider
import app.nerdin.plugins.llm.api.TokenUsage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class OpenAiLlmProvider(
    private val config: OpenAiConfig
) : LLMProvider {

    override val providerId: String get() = config.providerId
    override val displayName: String get() = config.displayName

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(config.timeoutSeconds.toLong(), TimeUnit.SECONDS)
        .readTimeout(config.timeoutSeconds.toLong(), TimeUnit.SECONDS)
        .writeTimeout(config.timeoutSeconds.toLong(), TimeUnit.SECONDS)
        .build()

    private val jsonMediaType = "application/json".toMediaType()

    override suspend fun chat(request: ChatRequest): ChatResponse = withContext(Dispatchers.IO) {
        val jsonBody = buildChatRequestJson(request)
        val httpRequest = buildHttpRequest(jsonBody)

        val response = client.newCall(httpRequest).execute()
        val body = response.body?.string() ?: throw RuntimeException("Empty response body")

        if (!response.isSuccessful) {
            throw RuntimeException("API error ${response.code}: $body")
        }

        val json = JSONObject(body)
        val choice = json.getJSONArray("choices").getJSONObject(0)
        val message = choice.getJSONObject("message")

        val content = message.optString("content", "")
        val role = message.optString("role", "assistant")

        val usage = json.optJSONObject("usage")?.let { u ->
            TokenUsage(
                promptTokens = u.optInt("prompt_tokens", 0),
                completionTokens = u.optInt("completion_tokens", 0),
                totalTokens = u.optInt("total_tokens", 0)
            )
        }

        ChatResponse(
            model = json.optString("model", request.model),
            message = ChatMessage(
                role = when (role) {
                    "assistant" -> ChatRole.ASSISTANT
                    else -> ChatRole.ASSISTANT
                },
                content = content
            ),
            usage = usage
        )
    }

    override suspend fun stream(request: ChatRequest): Flow<ChatChunk> = callbackFlow {
        val jsonBody = buildChatRequestJson(request.copy(stream = true))
        val httpRequest = buildHttpRequest(jsonBody)

        // We use OkHttp's streaming response rather than SSE eventsource,
        // because many providers don't implement proper SSE.
        val call = client.newCall(httpRequest)

        try {
            val response = withContext(Dispatchers.IO) { call.execute() }

            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: "Unknown error"
                throw RuntimeException("API error ${response.code}: $errorBody")
            }

            val body = response.body ?: throw RuntimeException("Empty response body")

            // Read line by line for SSE
            withContext(Dispatchers.IO) {
                body.source().let { source ->
                    while (!source.exhausted()) {
                        val line = source.readUtf8Line() ?: break

                        if (line.startsWith("data: ")) {
                            val data = line.removePrefix("data: ").trim()

                            if (data == "[DONE]") {
                                break
                            }

                            try {
                                val json = JSONObject(data)
                                val choices = json.optJSONArray("choices")
                                if (choices != null && choices.length() > 0) {
                                    val choice = choices.getJSONObject(0)
                                    val delta = choice.optJSONObject("delta")
                                    val finishReason = choice.optString("finish_reason", null)
                                    val content = delta?.optString("content", "") ?: ""

                                    trySend(ChatChunk(
                                        model = json.optString("model", request.model),
                                        delta = content,
                                        finishReason = if (finishReason.isNullOrEmpty() || finishReason == "null") null else finishReason
                                    ))
                                }
                            } catch (e: Exception) {
                                // Skip malformed JSON chunks
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("OpenAiLlmProvider", "Stream error", e)
            trySend(ChatChunk(
                model = request.model,
                delta = "",
                finishReason = "error"
            ))
        } finally {
            close()
        }

        awaitClose {
            call.cancel()
        }
    }

    /**
     * Build the JSON body for a chat completion request.
     */
    private fun buildChatRequestJson(request: ChatRequest): String {
        val messages = JSONArray()
        request.messages.forEach { msg ->
            val obj = JSONObject().apply {
                put("role", when (msg.role) {
                    ChatRole.SYSTEM -> "system"
                    ChatRole.USER -> "user"
                    ChatRole.ASSISTANT -> "assistant"
                    ChatRole.TOOL -> "tool"
                })
                put("content", msg.content)
            }
            messages.put(obj)
        }

        val json = JSONObject().apply {
            put("model", request.model)
            put("messages", messages)
            put("temperature", request.temperature.toDouble())
            put("max_tokens", request.maxTokens)
            put("stream", request.stream)

            if (request.tools.isNotEmpty()) {
                val toolsArray = JSONArray()
                request.tools.forEach { tool ->
                    toolsArray.put(JSONObject().apply {
                        put("type", "function")
                        put("function", JSONObject().apply {
                            put("name", tool.id)
                            put("description", tool.description)
                            put("parameters", JSONObject(tool.inputSchema))
                        })
                    })
                }
                put("tools", toolsArray)
            }
        }

        return json.toString()
    }

    private fun buildHttpRequest(jsonBody: String): Request {
        val builder = Request.Builder()
            .url("${config.baseUrl}/chat/completions")
            .post(jsonBody.toRequestBody(jsonMediaType))

        if (!config.apiKey.isNullOrBlank()) {
            builder.addHeader("Authorization", "Bearer ${config.apiKey}")
        }

        return builder.build()
    }

    fun close() {
        client.dispatcher.executorService.shutdown()
        client.connectionPool.evictAll()
    }
}
