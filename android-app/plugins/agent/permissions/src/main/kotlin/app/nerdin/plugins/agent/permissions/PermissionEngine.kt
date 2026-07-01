package app.nerdin.plugins.agent.permissions

import android.util.Log
import app.nerdin.core.api.PluginContext
import app.nerdin.plugins.agent.api.AgentPermissionService
import app.nerdin.plugins.agent.api.PermissionEffect
import app.nerdin.plugins.agent.api.PermissionReply
import app.nerdin.plugins.agent.api.PermissionRequest
import app.nerdin.plugins.agent.api.PermissionRule
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Core implementation of [AgentPermissionService].
 *
 * Rule evaluation follows a last-match-wins strategy across three tiers:
 * 1. **Session rules** – added during the current session (highest priority).
 * 2. **Persisted rules** – loaded from `permissions.json` (medium priority).
 * 3. **Default rules** – hardcoded safe defaults (lowest priority).
 *
 * Within each tier, rules added later take precedence (last-match-wins).
 */
class PermissionEngine(private val context: PluginContext) : AgentPermissionService {

    // ------------------------------------------------------------------
    // Rule storage
    // ------------------------------------------------------------------
    private val sessionRules = mutableListOf<PermissionRule>()
    private val persistedRules = mutableListOf<PermissionRule>()
    private val defaultRules = DefaultRules.all()

    // ------------------------------------------------------------------
    // Persistence
    // ------------------------------------------------------------------
    private val rulesFile: File
        get() = File(context.dataDir, "permissions.json")

    // ------------------------------------------------------------------
    // Pending-request infrastructure
    // ------------------------------------------------------------------
    private val pendingRequestsFlow = MutableSharedFlow<PermissionRequest>(
        replay = 0,
        extraBufferCapacity = 64
    )

    /** Maps a request ID to a deferred result that [respond] completes. */
    private val requestCompleters = ConcurrentHashMap<String, CompletableDeferred<PermissionReply>>()

    init {
        loadPersistedRules()
    }

    // ------------------------------------------------------------------
    // AgentPermissionService implementation
    // ------------------------------------------------------------------

    override suspend fun check(
        action: String,
        resource: String,
        agentId: String?
    ): PermissionEffect {
        // Evaluate rules: session first (last added wins), then persisted, then defaults
        val matchedRule = findFirstMatch(action, resource, agentId)

        val effect = matchedRule?.effect ?: PermissionEffect.ASK
        Log.d(
            "PermissionEngine",
            "check($action, $resource) → $effect" +
                    " (rule: ${matchedRule?.let { "${it.action}:${it.resource}" } ?: "default-ask"})"
        )

        if (effect == PermissionEffect.ASK) {
            // Create a pending request and suspend until the user responds
            val request = PermissionRequest(
                id = UUID.randomUUID().toString(),
                sessionId = agentId ?: "default",
                action = action,
                resources = listOf(resource)
            )

            val deferred = CompletableDeferred<PermissionReply>()
            requestCompleters[request.id] = deferred

            // Emit so the UI layer can pick it up and show a dialog
            pendingRequestsFlow.tryEmit(request)

            val reply = deferred.await()

            // Process the user's reply
            return handleReply(reply, action, resource, agentId)
        }

        return effect
    }

    override suspend fun respond(requestId: String, reply: PermissionReply) {
        val deferred = requestCompleters.remove(requestId)
        if (deferred != null) {
            deferred.complete(reply)
        } else {
            Log.w("PermissionEngine", "respond called for unknown request: $requestId")
        }
    }

    override fun pendingRequests(): Flow<PermissionRequest> = pendingRequestsFlow

    override suspend fun setRule(rule: PermissionRule) {
        persistedRules.add(rule)
        savePersistedRules()
    }

    override suspend fun removeRule(action: String, resource: String) {
        persistedRules.removeAll { it.action == action && it.resource == resource }
        savePersistedRules()
    }

    override fun clearSessionRules() {
        sessionRules.clear()
    }

    // ------------------------------------------------------------------
    // Rule evaluation
    // ------------------------------------------------------------------

    /**
     * Find the first matching rule across all tiers.
     *
     * Iterates rules in insertion order; later rules override earlier ones
     * (last-match-wins). Session rules are checked first, then persisted,
     * then defaults.
     */
    private fun findFirstMatch(
        action: String,
        resource: String,
        agentId: String?
    ): PermissionRule? {
        // Collect rules in priority-sorted order: session > persisted > default
        val allRules = listOf(sessionRules, persistedRules, defaultRules)

        for (tier in allRules) {
            val match = tier.lastOrNull { matches(it, action, resource, agentId) }
            if (match != null) return match
        }
        return null
    }

    private fun matches(
        rule: PermissionRule,
        action: String,
        resource: String,
        agentId: String?
    ): Boolean {
        if (rule.agentId != null && rule.agentId != agentId) return false
        if (!matchGlob(rule.action, action)) return false
        if (!matchGlob(rule.resource, resource)) return false
        return true
    }

    // ------------------------------------------------------------------
    // Glob matching (supports * and ?)
    // ------------------------------------------------------------------

    /**
     * Simple glob pattern matching.
     *
     * - `*` matches any sequence of characters (including empty).
     * - `?` matches any single character.
     * - Literal characters match themselves (case-sensitive).
     */
    internal fun matchGlob(pattern: String, text: String): Boolean {
        if (pattern == "*" || pattern == text) return true

        var pi = 0
        var ti = 0
        var starIdx = -1
        var matchIdx = -1

        while (ti < text.length) {
            if (pi < pattern.length && (pattern[pi] == '?' || pattern[pi] == text[ti])) {
                pi++
                ti++
            } else if (pi < pattern.length && pattern[pi] == '*') {
                starIdx = pi
                matchIdx = ti
                pi++
            } else if (starIdx != -1) {
                pi = starIdx + 1
                matchIdx++
                ti = matchIdx
            } else {
                return false
            }
        }

        while (pi < pattern.length && pattern[pi] == '*') pi++
        return pi == pattern.length
    }

    // ------------------------------------------------------------------
    // Reply handling
    // ------------------------------------------------------------------

    private suspend fun handleReply(
        reply: PermissionReply,
        action: String,
        resource: String,
        agentId: String?
    ): PermissionEffect {
        return when (reply) {
            PermissionReply.ONCE -> PermissionEffect.ALLOW

            PermissionReply.ALWAYS_SESSION -> {
                sessionRules.add(
                    PermissionRule(action, resource, PermissionEffect.ALLOW, agentId, priority = 10)
                )
                PermissionEffect.ALLOW
            }

            PermissionReply.ALWAYS -> {
                persistedRules.add(
                    PermissionRule(action, resource, PermissionEffect.ALLOW, agentId, priority = 5)
                )
                savePersistedRules()
                PermissionEffect.ALLOW
            }

            PermissionReply.REJECT -> PermissionEffect.DENY

            PermissionReply.EDIT -> {
                // UI handles the edit flow separately; deny the current attempt
                PermissionEffect.DENY
            }
        }
    }

    // ------------------------------------------------------------------
    // JSON persistence
    // ------------------------------------------------------------------

    private fun loadPersistedRules() {
        try {
            if (!rulesFile.exists()) return
            val json = JSONObject(rulesFile.readText())
            val arr = json.optJSONArray("rules") ?: return
            persistedRules.clear()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                persistedRules.add(
                    PermissionRule(
                        action = obj.getString("action"),
                        resource = obj.getString("resource"),
                        effect = PermissionEffect.valueOf(obj.getString("effect")),
                        agentId = obj.optString("agentId", "").ifEmpty { null },
                        priority = obj.optInt("priority", 5)
                    )
                )
            }
        } catch (e: Exception) {
            Log.e("PermissionEngine", "Failed to load persisted rules", e)
        }
    }

    private fun savePersistedRules() {
        try {
            val arr = JSONArray()
            persistedRules.forEach { rule ->
                arr.put(
                    JSONObject().apply {
                        put("action", rule.action)
                        put("resource", rule.resource)
                        put("effect", rule.effect.name)
                        put("agentId", rule.agentId ?: JSONObject.NULL)
                        put("priority", rule.priority)
                    }
                )
            }
            val json = JSONObject().apply { put("rules", arr) }
            rulesFile.parentFile?.mkdirs()
            rulesFile.writeText(json.toString(2))
        } catch (e: Exception) {
            Log.e("PermissionEngine", "Failed to save persisted rules", e)
        }
    }
}
