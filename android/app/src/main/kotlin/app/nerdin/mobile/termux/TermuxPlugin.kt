package app.nerdin.mobile.termux

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.net.InetSocketAddress
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class TermuxPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private var activityBinding: ActivityPluginBinding? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val pendingResults = ConcurrentHashMap<String, Result>()
    private var requestCounter = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "nerdin.mobile/termux")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isTermuxInstalled" -> {
                result.success(isPackageInstalled("com.termux"))
            }
            "runCommand" -> {
                val cmd = call.argument<String>("cmd") ?: ""
                val arguments = call.argument<List<String>>("arguments")
                val workdir = call.argument<String>("workdir")
                val stdin = call.argument<String>("stdin")
                runTermuxCommand(cmd, arguments, workdir, stdin, result)
            }
            "checkDaemonRunning" -> {
                val port = call.argument<Int>("port") ?: 64735
                scope.launch {
                    result.success(checkDaemonRunning(port))
                }
            }
            "ensurePermission" -> {
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            applicationContext.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun runTermuxCommand(
        cmd: String,
        arguments: List<String>?,
        workdir: String?,
        stdin: String?,
        result: Result
    ) {
        val requestId = "termux_${++requestCounter}_${UUID.randomUUID().toString().take(8)}"
        val action = "app.nerdin.mobile.termux.RESULT_${requestId}"

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val bundle = intent.getBundleExtra("com.termux.RUN_COMMAND_RESULT")
                if (bundle != null) {
                    val stdout = bundle.getString("stdout", "")
                    val stderr = bundle.getString("stderr", "")
                    val exitCode = bundle.getInt("exitCode", -1)
                    val err = bundle.getInt("err", 0)
                    val errmsg = bundle.getString("errmsg", "")

                    val response = mapOf(
                        "stdout" to (stdout ?: ""),
                        "stderr" to (stderr ?: ""),
                        "exitCode" to exitCode,
                        "err" to err,
                        "errmsg" to (errmsg ?: "")
                    )

                    try {
                        pendingResults[requestId]?.success(response)
                    } catch (e: Exception) {
                        Log.e("TermuxPlugin", "Failed to send result: ${e.message}")
                    } finally {
                        pendingResults.remove(requestId)
                        try { context.unregisterReceiver(this) } catch (_: Exception) {}
                    }
                } else {
                    pendingResults[requestId]?.error(
                        "NO_RESULT", "No result bundle from Termux", null
                    )
                    pendingResults.remove(requestId)
                    try { context.unregisterReceiver(this) } catch (_: Exception) {}
                }
            }
        }

        pendingResults[requestId] = result

        try {
            ContextCompat.registerReceiver(
                applicationContext,
                receiver,
                IntentFilter(action),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
        } catch (e: Exception) {
            pendingResults.remove(requestId)
            result.error("REGISTER_ERROR", "Failed to register receiver: ${e.message}", null)
            return
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            requestId.hashCode(),
            Intent(action),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val intent = Intent("com.termux.RUN_COMMAND").apply {
            setPackage("com.termux")
            putExtra("com.termux.RUN_COMMAND_PATH", cmd)
            if (!arguments.isNullOrEmpty()) {
                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arguments.toTypedArray())
            }
            if (!workdir.isNullOrBlank()) {
                putExtra("com.termux.RUN_COMMAND_WORKDIR", workdir)
            }
            if (!stdin.isNullOrBlank()) {
                putExtra("com.termux.RUN_COMMAND_STDIN", stdin)
            }
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
            putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", pendingIntent)
        }

        try {
            val componentName = applicationContext.startForegroundService(intent)
            if (componentName == null) {
                pendingResults.remove(requestId)
                try { applicationContext.unregisterReceiver(receiver) } catch (_: Exception) {}
                result.error("START_FAILED", "Termux RunCommandService not found or permission denied", null)
            }
        } catch (e: Exception) {
            pendingResults.remove(requestId)
            try { applicationContext.unregisterReceiver(receiver) } catch (_: Exception) {}

            if (e is SecurityException) {
                result.error("PERMISSION_DENIED",
                    "Missing com.termux.permission.RUN_COMMAND. " +
                    "Add it to AndroidManifest.xml and ensure allow-external-apps=true in Termux properties.", null)
            } else {
                result.error("START_ERROR", "Failed to start Termux command: ${e.message}", null)
            }
        }

        scope.launch {
            delay(30_000)
            if (pendingResults.containsKey(requestId)) {
                pendingResults.remove(requestId)
                try { applicationContext.unregisterReceiver(receiver) } catch (_: Exception) {}
                result.error("TIMEOUT", "Termux command timed out after 30 seconds", null)
            }
        }
    }

    private suspend fun checkDaemonRunning(port: Int): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val socket = Socket()
                socket.connect(InetSocketAddress("127.0.0.1", port), 500)
                socket.close()
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
