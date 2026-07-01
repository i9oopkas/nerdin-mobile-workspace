package app.nerdin.core.runtime.crash

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Process
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.util.concurrent.TimeUnit

/**
 * Simple [Thread.UncaughtExceptionHandler] that writes a crash report
 * directly to [Environment.DIRECTORY_DOWNLOADS]/Nerdin/crash_*.txt
 * (or a fallback in app cache if external storage is unavailable).
 *
 * No separate process, no SAF dialog — just write and kill.
 */
class NerdinCrashHandler(
    private val appContext: Context
) : Thread.UncaughtExceptionHandler {

    private val defaultHandler: Thread.UncaughtExceptionHandler? =
        Thread.getDefaultUncaughtExceptionHandler()

    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        try {
            val crashDir = resolveCrashDir()
            crashDir.mkdirs()

            val file = File(crashDir, "crash_${System.currentTimeMillis()}.txt")
            writeReport(file, thread, throwable)

            Log.i(TAG, "Crash report written to ${file.absolutePath}")
        } catch (e: Exception) {
            try {
                Log.e(TAG, "Failed to write crash report", e)
            } catch (_: Exception) { }
        }

        defaultHandler?.uncaughtException(thread, throwable)
        Process.killProcess(Process.myPid())
        System.exit(1)
    }

    /**
     * Resolves the directory for crash reports.
     *
     * Priority:
     * 1. Download/Nerdin/ — if we have storage access (MANAGE_EXTERNAL_STORAGE on API 30+,
     *    WRITE_EXTERNAL_STORAGE on older)
     * 2. app cache/crash_reports/ — fallback, always writable
     */
    private fun resolveCrashDir(): File {
        // Try external Download/Nerdin/
        if (Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()) {
            try {
                val downloadDir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                if (downloadDir.exists() || downloadDir.mkdirs()) {
                    val nerdinDir = File(downloadDir, "Nerdin")
                    if (nerdinDir.exists() || nerdinDir.mkdirs()) {
                        Log.d(TAG, "Using Downloads/Nerdin/ for crash reports")
                        return nerdinDir
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Cannot use Downloads/Nerdin/, falling back", e)
            }
        }
        // Fallback
        val fallback = File(appContext.cacheDir, "crash_reports")
        fallback.mkdirs()
        Log.d(TAG, "Using fallback ${fallback.absolutePath} for crash reports")
        return fallback
    }

    private fun writeReport(file: File, thread: Thread, throwable: Throwable) {
        file.bufferedWriter(Charsets.UTF_8).use { writer ->
            // ── Header ──
            writer.write("=== Nerdin Crash Report ===\n")
            writer.write("Version: 0.1.0\n")
            writer.write("Time: ${System.currentTimeMillis()}\n")
            writer.write("Thread: ${thread.name} (id=${thread.id}, priority=${thread.priority})\n")
            writer.write("Package: ${appContext.packageName}\n")
            writer.newLine()

            // ── Stack Trace ──
            writer.write("--- Stack Trace ---\n")
            val sw = StringWriter()
            throwable.printStackTrace(PrintWriter(sw))
            writer.write(sw.toString())
            writer.newLine()

            // ── Caused-by chain ──
            var cause = throwable.cause
            var depth = 0
            while (cause != null && depth < 10) {
                writer.write("--- Caused by (depth=$depth) ---\n")
                val csw = StringWriter()
                cause.printStackTrace(PrintWriter(csw))
                writer.write(csw.toString())
                writer.newLine()
                cause = cause.cause
                depth++
            }

            // ── Logcat (last 300 lines) ──
            writer.write("--- Logcat (last 300 lines) ---\n")
            try {
                val pb = ProcessBuilder("logcat", "-d", "-t", "300", "-v", "brief")
                pb.redirectErrorStream(true)
                val proc = pb.start()
                proc.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                    reader.copyTo(writer)
                }
                proc.waitFor(5, TimeUnit.SECONDS)
            } catch (e: Exception) {
                writer.write("(logcat unavailable: ${e.message})\n")
            }
            writer.newLine()

            // ── Device Info ──
            writer.write("--- Device ---\n")
            writer.write("Brand: ${Build.BRAND}\n")
            writer.write("Device: ${Build.DEVICE}\n")
            writer.write("Model: ${Build.MODEL}\n")
            writer.write("Product: ${Build.PRODUCT}\n")
            writer.write("Android: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})\n")
            writer.write("Fingerprint: ${Build.FINGERPRINT}\n")
            writer.write("Display: ${Build.DISPLAY}\n")
        }
    }

    companion object {
        private const val TAG = "NerdinCrash"
        const val EXTRA_CRASH_FILE_PATH = "crash_file_path"
    }
}
