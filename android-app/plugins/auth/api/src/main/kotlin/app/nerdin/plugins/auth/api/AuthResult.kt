package app.nerdin.plugins.auth.api

data class AuthResult(
    val success: Boolean,
    val token: String? = null,
    val error: String? = null,
    val expiresAt: Long? = null
)
