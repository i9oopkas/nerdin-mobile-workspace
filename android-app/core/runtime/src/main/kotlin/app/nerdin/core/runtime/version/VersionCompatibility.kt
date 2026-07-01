package app.nerdin.core.runtime.version

import app.nerdin.core.api.PluginManifest
import app.nerdin.core.api.Version

/**
 * Checks version compatibility between plugins and the core.
 */
object VersionCompatibility {

    /** Current core version */
    val CORE_VERSION = Version(0, 1, 0)

    /** Current API version that plugins can target */
    val API_VERSION = Version(0, 1, 0)

    /**
     * Check if a plugin's manifest is compatible with the current core.
     */
    fun checkCoreVersion(manifest: PluginManifest): Boolean {
        // Plugin must support at least our API version
        if (manifest.apiVersion > API_VERSION) {
            return false
        }

        // Our core version must be within plugin's supported range
        if (CORE_VERSION < manifest.minCoreVersion) {
            return false
        }
        val maxVersion = manifest.maxCoreVersion
        if (maxVersion != null && CORE_VERSION > maxVersion) {
            return false
        }

        return true
    }

    /**
     * Check if one plugin's API version is compatible with another plugin's requirement.
     */
    fun checkDependencyApiVersion(
        requiredApiVersion: Version,
        providedApiVersion: Version
    ): Boolean {
        return providedApiVersion >= requiredApiVersion
    }
}
