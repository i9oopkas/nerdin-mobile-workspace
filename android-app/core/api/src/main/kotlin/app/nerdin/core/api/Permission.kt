package app.nerdin.core.api

/**
 * A permission that a plugin requires.
 * @param id Unique permission identifier (e.g. "network", "filesystem.read")
 * @param description Human-readable description of what this permission allows
 * @param androidPermission Optional Android platform permission (e.g. Manifest.permission.INTERNET)
 */
data class Permission(
    val id: String,
    val description: String,
    val androidPermission: String? = null
)
