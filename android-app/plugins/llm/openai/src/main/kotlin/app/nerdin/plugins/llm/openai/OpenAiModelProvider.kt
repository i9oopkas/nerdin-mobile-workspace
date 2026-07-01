package app.nerdin.plugins.llm.openai

import android.util.Log
import app.nerdin.plugins.llm.api.ModelInfo
import app.nerdin.plugins.llm.api.ModelProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class OpenAiModelProvider(
    private val config: OpenAiConfig
) : ModelProvider {

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    override suspend fun listModels(): List<ModelInfo> = withContext(Dispatchers.IO) {
        try {
            val builder = Request.Builder()
                .url("${config.baseUrl}/models")
                .get()

            if (!config.apiKey.isNullOrBlank()) {
                builder.addHeader("Authorization", "Bearer ${config.apiKey}")
            }

            val response = client.newCall(builder.build()).execute()
            if (!response.isSuccessful) {
                Log.w("OpenAiModelProvider", "Failed to list models: ${response.code}")
                return@withContext defaultModels()
            }

            val body = response.body?.string() ?: return@withContext defaultModels()
            val json = JSONObject(body)
            val data = json.optJSONArray("data")

            if (data == null || data.length() == 0) {
                return@withContext defaultModels()
            }

            (0 until data.length()).map { i ->
                val model = data.getJSONObject(i)
                ModelInfo(
                    id = model.optString("id", "unknown"),
                    name = model.optString("id", "Unknown"),
                    provider = config.providerId,
                    contextLength = model.optInt("max_context", 4096),
                    capabilities = listOf("chat")
                )
            }
        } catch (e: Exception) {
            Log.w("OpenAiModelProvider", "Failed to list models", e)
            defaultModels()
        }
    }

    override suspend fun getModel(modelId: String): ModelInfo? {
        return listModels().find { it.id == modelId }
    }

    private fun defaultModels(): List<ModelInfo> {
        return listOf(
            ModelInfo(
                id = config.defaultModel,
                name = config.defaultModel,
                provider = config.providerId,
                contextLength = 4096,
                capabilities = listOf("chat")
            )
        )
    }
}
