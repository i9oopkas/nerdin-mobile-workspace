package app.nerdin.plugins.tools.local

import app.nerdin.core.api.Tool
import app.nerdin.core.api.ToolResult
import app.nerdin.plugins.tool.api.ToolProvider
import java.io.File

class LocalToolProvider : ToolProvider {

    private val tools = listOf(
        Tool(
            id = "read_file",
            name = "Read File",
            description = "Read the contents of a file",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "path" to mapOf("type" to "string", "description" to "Absolute path to the file"),
                    "offset" to mapOf(
                        "type" to "integer",
                        "description" to "Line offset to start from",
                        "optional" to true
                    ),
                    "limit" to mapOf(
                        "type" to "integer",
                        "description" to "Number of lines to read",
                        "optional" to true
                    )
                ),
                "required" to listOf("path")
            )
        ),
        Tool(
            id = "write_file",
            name = "Write File",
            description = "Write content to a file (creates or overwrites)",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "path" to mapOf("type" to "string", "description" to "Absolute path to the file"),
                    "content" to mapOf("type" to "string", "description" to "Content to write")
                ),
                "required" to listOf("path", "content")
            )
        ),
        Tool(
            id = "edit_file",
            name = "Edit File",
            description = "Find and replace text in a file (sed-like)",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "path" to mapOf("type" to "string", "description" to "Absolute path to the file"),
                    "oldText" to mapOf("type" to "string", "description" to "Text to find"),
                    "newText" to mapOf("type" to "string", "description" to "Replacement text")
                ),
                "required" to listOf("path", "oldText", "newText")
            )
        ),
        Tool(
            id = "grep",
            name = "Grep",
            description = "Search for a pattern in files",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "pattern" to mapOf("type" to "string", "description" to "Search pattern"),
                    "path" to mapOf(
                        "type" to "string",
                        "description" to "Directory or file to search (default: current)",
                        "optional" to true
                    ),
                    "regex" to mapOf(
                        "type" to "boolean",
                        "description" to "Treat pattern as regex",
                        "optional" to true
                    )
                ),
                "required" to listOf("pattern")
            )
        ),
        Tool(
            id = "glob",
            name = "Glob",
            description = "Find files matching a glob pattern",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "pattern" to mapOf("type" to "string", "description" to "Glob pattern (e.g. **/*.kt)"),
                    "basePath" to mapOf(
                        "type" to "string",
                        "description" to "Base directory",
                        "optional" to true
                    )
                ),
                "required" to listOf("pattern")
            )
        )
    )

    override suspend fun listTools(): List<Tool> = tools

    override suspend fun execute(toolId: String, args: Map<String, Any>): ToolResult {
        return try {
            when (toolId) {
                "read_file" -> executeReadFile(args)
                "write_file" -> executeWriteFile(args)
                "edit_file" -> executeEditFile(args)
                "grep" -> executeGrep(args)
                "glob" -> executeGlob(args)
                else -> ToolResult(false, error = "Unknown tool: $toolId")
            }
        } catch (e: Exception) {
            ToolResult(false, error = "${e::class.java.simpleName}: ${e.message}")
        }
    }

    private fun executeReadFile(args: Map<String, Any>): ToolResult {
        val path = args["path"] as? String
            ?: return ToolResult(false, error = "Missing path")
        val file = File(path)
        if (!file.exists()) return ToolResult(false, error = "File not found: $path")
        if (!file.isFile) return ToolResult(false, error = "Not a file: $path")

        val content = file.readText()
        val offset = (args["offset"] as? Number)?.toInt() ?: 0
        val limit = (args["limit"] as? Number)?.toInt() ?: Int.MAX_VALUE

        if (offset > 0 || limit < Int.MAX_VALUE) {
            val lines = content.lines()
            val selected = lines.drop(offset).take(limit)
            return ToolResult(true, data = selected.joinToString("\n"))
        }

        return ToolResult(true, data = content)
    }

    private fun executeWriteFile(args: Map<String, Any>): ToolResult {
        val path = args["path"] as? String
            ?: return ToolResult(false, error = "Missing path")
        val content = args["content"] as? String
            ?: return ToolResult(false, error = "Missing content")
        val file = File(path)
        file.parentFile?.mkdirs()
        file.writeText(content)
        return ToolResult(true, data = "Written ${content.length} bytes to $path")
    }

    private fun executeEditFile(args: Map<String, Any>): ToolResult {
        val path = args["path"] as? String
            ?: return ToolResult(false, error = "Missing path")
        val oldText = args["oldText"] as? String
            ?: return ToolResult(false, error = "Missing oldText")
        val newText = args["newText"] as? String
            ?: return ToolResult(false, error = "Missing newText")

        val file = File(path)
        if (!file.exists()) return ToolResult(false, error = "File not found: $path")

        val content = file.readText()
        if (!content.contains(oldText)) {
            return ToolResult(false, error = "Pattern not found in file")
        }

        val newContent = content.replace(oldText, newText)
        file.writeText(newContent)
        return ToolResult(true, data = "Replaced in $path")
    }

    private fun executeGrep(args: Map<String, Any>): ToolResult {
        val pattern = args["pattern"] as? String
            ?: return ToolResult(false, error = "Missing pattern")
        val path = (args["path"] as? String) ?: "."
        val isRegex = (args["regex"] as? Boolean) ?: false

        val baseFile = File(path)
        if (!baseFile.exists()) return ToolResult(false, error = "Path not found: $path")

        val results = mutableListOf<String>()
        val files = if (baseFile.isDirectory) {
            baseFile.walkTopDown().filter { it.isFile }.toList()
        } else {
            listOf(baseFile)
        }

        files.forEach { file ->
            try {
                file.useLines { lines ->
                    lines.forEachIndexed { index, line ->
                        val match = if (isRegex) {
                            Regex(pattern).containsMatchIn(line)
                        } else {
                            line.contains(pattern, ignoreCase = false)
                        }
                        if (match) {
                            results.add("${file.path}:${index + 1}:$line")
                        }
                    }
                }
            } catch (_: Exception) {
                // Skip files we can't read
            }
        }

        return ToolResult(
            true,
            data = results.joinToString("\n").ifEmpty { "No matches found" }
        )
    }

    private fun executeGlob(args: Map<String, Any>): ToolResult {
        val pattern = args["pattern"] as? String
            ?: return ToolResult(false, error = "Missing pattern")
        val basePath = (args["basePath"] as? String) ?: "."

        val baseFile = File(basePath)
        if (!baseFile.exists()) return ToolResult(false, error = "Base path not found: $basePath")

        val results = baseFile.walkTopDown()
            .filter { it.isFile }
            .filter { globMatch(pattern, it.path.removePrefix(baseFile.path).trimStart('/')) }
            .map { it.path }
            .toList()

        return ToolResult(
            true,
            data = results.joinToString("\n").ifEmpty { "No files matched" }
        )
    }

    /**
     * Simple glob matching for file paths.
     *
     * Supports:
     * - `*` matches any characters within a single path segment
     * - `**` matches across multiple path segments (any depth)
     * - `?` matches any single character within a segment
     */
    private fun globMatch(pattern: String, text: String): Boolean {
        val regexStr = pattern
            .replace(".", "\\.")
            .replace("**", "<<<DOUBLE>>>")
            .replace("*", "[^/]*")
            .replace("<<<DOUBLE>>>", ".*")
            .replace("?", ".")
        return Regex("^${regexStr}$").containsMatchIn(text)
    }
}
