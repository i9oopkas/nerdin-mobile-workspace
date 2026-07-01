package app.nerdin.core.runtime.permission

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import app.nerdin.core.api.Permission

/**
 * Manages runtime permission checks for plugins.
 * Handles both Android platform permissions and custom Nerdin permissions.
 */
class PermissionManager(private val context: Context) {

    private val grantedCustomPermissions = mutableSetOf<String>()

    /**
     * Check if a permission is granted.
     * For Android permissions, delegates to ContextCompat.
     * For custom permissions, checks internal grant state.
     */
    fun checkPermission(permission: Permission): Boolean {
        val androidPermission = permission.androidPermission
        return if (androidPermission != null) {
            ContextCompat.checkSelfPermission(context, androidPermission) ==
                    PackageManager.PERMISSION_GRANTED
        } else {
            permission.id in grantedCustomPermissions
        }
    }

    /**
     * Grant a custom permission (for testing or pre-authorization).
     */
    fun grantCustomPermission(permissionId: String) {
        grantedCustomPermissions.add(permissionId)
    }

    /**
     * Revoke a custom permission.
     */
    fun revokeCustomPermission(permissionId: String) {
        grantedCustomPermissions.remove(permissionId)
    }

    /**
     * Check multiple permissions at once.
     * Returns the list of denied permissions.
     */
    fun checkPermissions(permissions: List<Permission>): List<Permission> {
        return permissions.filter { !checkPermission(it) }
    }

    fun clear() {
        grantedCustomPermissions.clear()
    }
}
