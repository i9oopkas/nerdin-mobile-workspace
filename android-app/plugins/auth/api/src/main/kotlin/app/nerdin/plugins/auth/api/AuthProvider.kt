package app.nerdin.plugins.auth.api

import app.nerdin.core.api.NerdinService

interface AuthProvider : NerdinService {
    suspend fun authenticate(credentials: Map<String, String>): AuthResult
    suspend fun refresh(): AuthResult
    fun isAuthenticated(): Boolean
    fun getCurrentUserId(): String?
}
