package app.nerdin.core.api

/**
 * Declarative manifest for a plugin module.
 * Core uses this to verify compatibility and resolve dependencies before loading.
 */
data class PluginManifest(
    /** Unique plugin identifier (e.g. "nerdin.provider.openai") */
    val pluginId: String,

    /** Plugin version */
    val version: Version,

    /** Version of the API contract this plugin was compiled against */
    val apiVersion: Version,

    /** Minimum core version required to run this plugin */
    val minCoreVersion: Version,

    /** Maximum core version supported (null = any higher version is fine) */
    val maxCoreVersion: Version? = null,

    /** Required plugin dependencies by pluginId */
    val dependencies: List<String> = emptyList(),

    /** Optional plugin dependencies */
    val optionalDependencies: List<String> = emptyList(),

    /** What this plugin provides (service/extension identifiers) */
    val provides: List<String> = emptyList(),

    /** What this plugin requires from other plugins */
    val requires: List<String> = emptyList(),

    /** Permissions this plugin needs */
    val permissions: List<Permission> = emptyList()
)
