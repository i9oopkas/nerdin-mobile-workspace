package app.nerdin

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import app.nerdin.ui.agent.AgentChatScreen
import app.nerdin.ui.core.DebugOverlay
import app.nerdin.ui.core.LayoutHost
import app.nerdin.ui.core.NerdinTheme
import app.nerdin.ui.settings.SettingsScreen
import java.io.File

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val app = application as NerdinApplication
        val layoutRegistry = app.layoutRegistry
        val pluginContext = app.pluginContext

        try {
            // Pre-create Nerdin directory if we already have permission
            if (Build.VERSION.SDK_INT >= 30 && Environment.isExternalStorageManager()) {
                File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "Nerdin"
                ).mkdirs()
            }
        } catch (_: Exception) { }

        setContent {
            NerdinTheme {
                // Shows MANAGE_EXTERNAL_STORAGE dialog on Android 11+ if not granted
                StoragePermissionGate()

                DebugOverlay {
                    LayoutHost(
                        layoutRegistry = layoutRegistry,
                        agentScreen = { AgentChatScreen(pluginContext = pluginContext) },
                        workspaceScreen = { WorkspacePlaceholder() },
                        settingsScreen = { SettingsScreen(pluginContext = pluginContext) },
                    )
                }
            }
        }
    }
}

/**
 * On Android 11+ shows a one-time dialog requesting MANAGE_EXTERNAL_STORAGE.
 * If granted, creates Download/Nerdin/ directory for logs and crash reports.
 */
@Composable
private fun StoragePermissionGate() {
    if (Build.VERSION.SDK_INT < 30) return
    if (Environment.isExternalStorageManager()) return

    val context = LocalContext.current
    var showDialog by remember { mutableStateOf(true) }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) {
        // resultCode is unreliable — recheck the actual permission state
        if (Environment.isExternalStorageManager()) {
            try {
                val dir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "Nerdin"
                )
                dir.mkdirs()
            } catch (_: Exception) { }
            Toast.makeText(context, "Storage access granted", Toast.LENGTH_SHORT).show()
        }
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Storage Access") },
            text = {
                Text(
                    "Nerdin needs All Files Access to save debug logs and crash " +
                    "reports to Download/Nerdin/ for troubleshooting."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showDialog = false
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION
                        ).apply {
                            data = Uri.parse("package:${context.packageName}")
                        }
                        launcher.launch(intent)
                    } catch (e: Exception) {
                        // Fallback for OEMs that don't support per-app permission page
                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        launcher.launch(intent)
                    }
                }) {
                    Text("Grant access")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDialog = false }) {
                    Text("Skip")
                }
            }
        )
    }
}

@Composable
private fun WorkspacePlaceholder() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Workspace",
                style = MaterialTheme.typography.headlineMedium,
            )
            Text(
                text = "Coming soon — file browser & editor",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
