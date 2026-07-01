package app.nerdin.ui.core

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.util.Log
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.FullscreenExit
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.InputStreamReader
import kotlin.math.roundToInt

/**
 * A single log line.
 */
data class LogLine(
    val text: String,
    val level: String, // "V", "D", "I", "W", "E"
)

/**
 * Floating debug overlay that shows logcat output.
 *
 * Features:
 * - Semi-transparent dark panel with scrollable logs
 * - Collapse/expand toggle
 * - Copy logs to clipboard
 * - Draggable (long-press the top bar to drag)
 * - Auto-refresh every 2 seconds
 */
@Composable
fun DebugOverlay(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val logs = remember { mutableStateListOf<LogLine>() }
    var isExpanded by remember { mutableStateOf(true) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    val listState = rememberLazyListState()

    val saveLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("text/plain"),
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                try {
                    context.contentResolver.openOutputStream(uri)?.use { output ->
                        val content = buildLogText(logs)
                        output.write(content.toByteArray(Charsets.UTF_8))
                    }
                    Toast.makeText(context, "Logs saved", Toast.LENGTH_SHORT).show()
                } catch (e: Exception) {
                    Toast.makeText(context, "Failed to save: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    // Auto-refresh logs every 2 seconds
    LaunchedEffect(Unit) {
        while (true) {
            try {
                fetchLogcat(logs)
            } catch (e: Exception) {
                Log.w("DebugOverlay", "Failed to fetch logs", e)
            }
            delay(2000L)
        }
    }

    // Auto-scroll to bottom on new logs
    LaunchedEffect(logs.size) {
        if (logs.isNotEmpty()) {
            listState.animateScrollToItem(logs.size - 1)
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        // Main app content
        content()

        // Floating debug overlay
        if (isExpanded) {
            // Expanded panel
            Box(
                modifier = Modifier
                    .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
                    .size(width = 360.dp, height = 500.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xCC1A1A2E)) // Semi-transparent dark
                    .then(
                        Modifier.pointerInput(Unit) {
                            awaitPointerEventScope {
                                while (true) {
                                    val event = awaitPointerEvent()
                                    // Track drag on the title bar area
                                    val change = event.changes.firstOrNull() ?: break
                                    if (change.pressed) {
                                        change.consume()
                                        val delta = change.position - change.previousPosition
                                        offsetX += delta.x
                                        offsetY += delta.y
                                    }
                                }
                            }
                        }
                    )
            ) {
                Column(Modifier.fillMaxSize()) {
                    // Title bar (drag handle)
                    TitleBar(
                        logCount = logs.size,
                        onCopy = { copyLogs(context, logs) },
                        onSave = { saveLauncher.launch("nerdin_logs.log") },
                        onClear = { logs.clear() },
                        onCollapse = { isExpanded = false },
                    )

                    // Log lines
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(horizontal = 4.dp),
                    ) {
                        items(logs, key = { it.text.hashCode().toString() + it.text.length }) { line ->
                            LogLineView(line)
                        }
                    }

                    // Bottom bar with refresh info
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0x33000000))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = "${logs.size} lines · auto-refresh 2s",
                            color = Color.Gray,
                            fontSize = 10.sp,
                            fontFamily = FontFamily.Monospace,
                        )
                    }
                }
            }
        } else {
            // Collapsed: small floating button
            Box(
                modifier = Modifier
                    .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color(0xCC1A1A2E))
                    .clickable { isExpanded = true }
                    .pointerInput(Unit) {
                        detectDraggingGestures { dx, dy ->
                            offsetX += dx
                            offsetY += dy
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "🐛",
                    fontSize = 18.sp,
                )
            }
        }
    }
}

@Composable
private fun TitleBar(
    logCount: Int,
    onCopy: () -> Unit,
    onSave: () -> Unit,
    onClear: () -> Unit,
    onCollapse: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0x44000000))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Drag handle indicator
        Text(
            text = "☰ DEBUG",
            color = Color(0xFF00D4AA),
            fontSize = 12.sp,
            fontFamily = FontFamily.Monospace,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
        )

        Spacer(Modifier.weight(1f))

        // Save button
        IconButton(
            onClick = onSave,
            modifier = Modifier.size(28.dp),
        ) {
            Text("💾", fontSize = 14.sp)
        }

        // Copy button
        IconButton(
            onClick = onCopy,
            modifier = Modifier.size(28.dp),
        ) {
            Icon(
                Icons.Default.ContentCopy,
                contentDescription = "Copy logs",
                tint = Color.White,
                modifier = Modifier.size(16.dp),
            )
        }

        // Clear button
        IconButton(
            onClick = onClear,
            modifier = Modifier.size(28.dp),
        ) {
            Icon(
                Icons.Default.Refresh,
                contentDescription = "Clear",
                tint = Color.White,
                modifier = Modifier.size(16.dp),
            )
        }

        // Collapse button
        IconButton(
            onClick = onCollapse,
            modifier = Modifier.size(28.dp),
        ) {
            Icon(
                Icons.Default.FullscreenExit,
                contentDescription = "Collapse",
                tint = Color.White,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

@Composable
private fun LogLineView(line: LogLine) {
    val color = when (line.level) {
        "E" -> Color(0xFFEF5350) // Red for errors
        "W" -> Color(0xFFFFA726) // Orange for warnings
        "I" -> Color(0xFF66BB6A) // Green for info
        "D" -> Color(0xFF42A5F5) // Blue for debug
        else -> Color(0xFFBDBDBD) // Gray for verbose
    }

    Text(
        text = line.text,
        color = color,
        fontSize = 9.sp,
        fontFamily = FontFamily.Monospace,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 1.dp, horizontal = 2.dp),
    )
}

/**
 * Fetch recent logcat output and populate the logs list.
 */
@SuppressLint("PrivateApi")
private fun fetchLogcat(logs: MutableList<LogLine>) {
    try {
        val process = if (Build.VERSION.SDK_INT >= 33) {
            // Android 13+ requires READ_LOGS permission which most apps don't have
            // Use a fallback approach
            Runtime.getRuntime().exec("logcat -d -t 200 -v brief NerdinCore:I PluginLifecycleManager:I ReactAgentPlugin:I DebugOverlay:I *:S")
        } else {
            Runtime.getRuntime().exec("logcat -d -t 200 -v brief")
        }

        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val lines = mutableListOf<LogLine>()

        reader.use { br ->
            var line = br.readLine()
            while (line != null) {
                // Parse log level from the line
                val level = when {
                    line.contains(" E ") -> "E"
                    line.contains(" W ") -> "W"
                    line.contains(" I ") -> "I"
                    line.contains(" D ") -> "D"
                    else -> "V"
                }
                lines.add(LogLine(text = line, level = level))
                line = br.readLine()
            }
        }

        process.waitFor()

        // Replace logs (clear and add new)
        logs.clear()
        logs.addAll(lines)
    } catch (e: Exception) {
        Log.w("DebugOverlay", "Failed to read logcat", e)
    }
}

/**
 * Build formatted log text for saving to file.
 */
private fun buildLogText(logs: List<LogLine>): String {
    val sb = StringBuilder()
    sb.appendLine("=== Nerdin Debug Logs ===")
    sb.appendLine("Date: ${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US).format(java.util.Date())}")
    sb.appendLine("App: Nerdin Mobile v0.1.0")
    sb.appendLine()
    sb.appendLine("--- Logs (${logs.size} lines) ---")
    sb.appendLine()
    logs.forEach { sb.appendLine(it.text) }
    sb.appendLine()
    sb.appendLine("--- End ---")
    return sb.toString()
}

/**
 * Copy all logs to clipboard.
 */
private fun copyLogs(context: Context, logs: List<LogLine>) {
    val text = logs.joinToString("\n") { it.text }
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    clipboard?.setPrimaryClip(ClipData.newPlainText("Nerdin Debug Logs", text))
}

/**
 * Simple drag gesture detector for the collapsed button.
 */
private suspend fun androidx.compose.ui.input.pointer.PointerInputScope.detectDraggingGestures(
    onDrag: (Float, Float) -> Unit,
) {
    awaitPointerEventScope {
        while (true) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull() ?: break
            if (change.pressed) {
                change.consume()
                val delta = change.position - change.previousPosition
                onDrag(delta.x, delta.y)
            }
        }
    }
}
