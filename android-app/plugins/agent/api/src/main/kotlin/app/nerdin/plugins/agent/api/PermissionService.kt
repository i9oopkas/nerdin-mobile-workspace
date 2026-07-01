package app.nerdin.plugins.agent.api

import app.nerdin.core.api.NerdinService
import kotlinx.coroutines.flow.Flow

/**
 * Service that manages what actions an agent is allowed to perform.
 * Rules are evaluated last-match-wins with priority: session > persisted > defaults.
 */
interface AgentPermissionService : NerdinService {

    /**
     * Check whether [action] on [resource] is allowed for [agentId].
     * If the result is ASK, a PermissionRequest is created and the caller
     * should wait for the user to respond via [respond].
     */
    suspend fun check(action: String, resource: String, agentId: String? = null): PermissionEffect

    /**
     * Respond to a pending permission request.
     */
    suspend fun respond(requestId: String, reply: PermissionReply)

    /**
     * Observe pending permission requests (for UI to show dialogs).
     */
    fun pendingRequests(): Flow<PermissionRequest>

    /**
     * Add a rule (persisted).
     */
    suspend fun setRule(rule: PermissionRule)

    /**
     * Remove a persisted rule.
     */
    suspend fun removeRule(action: String, resource: String)

    /**
     * Clear all session-only rules.
     */
    fun clearSessionRules()
}

enum class PermissionEffect { ALLOW, DENY, ASK }

enum class PermissionReply { ONCE, ALWAYS_SESSION, ALWAYS, REJECT, EDIT }

data class PermissionRule(
    val action: String,
    val resource: String,
    val effect: PermissionEffect,
    val agentId: String? = null,
    val priority: Int = 0
)

data class PermissionRequest(
    val id: String,
    val sessionId: String,
    val action: String,
    val resources: List<String>,
    val savePatterns: List<String> = emptyList(),
    val metadata: Map<String, String> = emptyMap()
)
