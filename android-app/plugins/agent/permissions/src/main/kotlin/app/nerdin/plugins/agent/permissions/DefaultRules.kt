package app.nerdin.plugins.agent.permissions

import app.nerdin.plugins.agent.api.PermissionEffect
import app.nerdin.plugins.agent.api.PermissionRule

/**
 * Default hardcoded permission rules that apply when no session or persisted rule matches.
 * These represent safe defaults for an AI coding agent.
 *
 * Rules are ordered such that more specific rules appear after general ones
 * (last-match-wins within a priority tier).
 */
object DefaultRules {

    fun all(): List<PermissionRule> = listOf(
        // --- Read operations — generally safe ---
        PermissionRule("read_file", "**", PermissionEffect.ALLOW, priority = 0),
        PermissionRule("grep", "**", PermissionEffect.ALLOW, priority = 0),
        PermissionRule("glob", "**", PermissionEffect.ALLOW, priority = 0),
        PermissionRule("list_dir", "**", PermissionEffect.ALLOW, priority = 0),

        // --- Write operations within workspace — allowed ---
        PermissionRule(
            "write_file",
            "/data/data/app.nerdin.mobile/**",
            PermissionEffect.ALLOW,
            priority = 0
        ),
        PermissionRule(
            "write_file",
            "/storage/emulated/0/Android/data/app.nerdin.mobile/**",
            PermissionEffect.ALLOW,
            priority = 0
        ),
        // Write outside workspace — ask
        PermissionRule("write_file", "**", PermissionEffect.ASK, priority = 0),

        // --- Edit operations ---
        PermissionRule(
            "edit_file",
            "/data/data/app.nerdin.mobile/**",
            PermissionEffect.ALLOW,
            priority = 0
        ),
        PermissionRule("edit_file", "**", PermissionEffect.ASK, priority = 0),

        // --- Dangerous operations — always ask ---
        PermissionRule("delete_file", "**", PermissionEffect.ASK, priority = 0),
        PermissionRule("run_command", "**", PermissionEffect.ASK, priority = 0),
        PermissionRule("network", "**", PermissionEffect.ASK, priority = 0),

        // --- System operations — deny by default (higher priority) ---
        PermissionRule("write_file", "/system/**", PermissionEffect.DENY, priority = 1),
        PermissionRule("write_file", "/etc/**", PermissionEffect.DENY, priority = 1),
        PermissionRule("delete_file", "/system/**", PermissionEffect.DENY, priority = 1),
        PermissionRule("delete_file", "/etc/**", PermissionEffect.DENY, priority = 1),
        // Extra dangerous patterns
        PermissionRule("run_command", "rm -rf /*", PermissionEffect.DENY, priority = 2),
        PermissionRule("run_command", "rm -rf /", PermissionEffect.DENY, priority = 2),
    )
}
