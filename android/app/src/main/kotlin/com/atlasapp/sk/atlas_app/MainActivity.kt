package com.atlasapp.sk.atlas_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val CHANNEL = "com.atlasapp/file_open"
        private const val UPDATE_CHANNEL = "com.atlasapp/update_install"
        private const val APK_MIME = "application/vnd.android.package-archive"
    }

    private var channel: MethodChannel? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialOpenedFile" -> {
                        val path = pendingPath
                        pendingPath = null
                        result.success(path)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart verifies the manifest hash and downloaded bytes; this
                    // endpoint only hands the file to the system installer.
                    "installApk" -> {
                        val path = call.arguments as? String
                        if (path == null) {
                            result.error("INVALID", "Missing APK path", null)
                            return@setMethodCallHandler
                        }
                        result.success(installApk(File(path)))
                    }
                    "canRequestInstall" -> result.success(canRequestInstall())
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // Cold start: the app was launched to open a document. Dart's handler
        // is not registered yet, so stash the path for getInitialOpenedFile.
        storePendingOpenedFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverOpenedFile(intent)
    }

    /** Cold start: copies the opened URI and keeps it for Dart to pull. */
    private fun storePendingOpenedFile(intent: Intent?) {
        val uri = openedUri(intent) ?: return
        val path = copyToCache(uri) ?: return
        pendingPath = path
    }

    /** Warm start: copies the opened URI and pushes it straight to Dart. */
    private fun deliverOpenedFile(intent: Intent?) {
        val uri = openedUri(intent) ?: return
        val path = copyToCache(uri) ?: return
        if (channel != null) {
            channel?.invokeMethod("onFileOpened", path)
        } else {
            // Engine not ready yet — queue for Dart's getInitialOpenedFile.
            pendingPath = path
        }
    }

    private fun openedUri(intent: Intent?): Uri? =
        when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            else -> null
        }

    private fun copyToCache(uri: Uri): String? {
        val name = queryDisplayName(uri) ?: uri.lastPathSegment ?: "opened"
        val ext = resolveExtension(uri, name)
        val file = File(cacheDir, "opened_${System.currentTimeMillis()}.$ext")
        return try {
            val stream = contentResolver.openInputStream(uri)
            if (stream == null) return null
            stream.use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            if (!file.exists() || file.length() == 0L) {
                file.delete()
                return null
            }
            file.absolutePath
        } catch (e: Exception) {
            try { file.delete() } catch (_: Exception) {}
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) cursor.getString(idx) else null
                    } else null
                }
        } catch (e: Exception) {
            null
        }
    }

    private fun resolveExtension(uri: Uri, displayName: String): String {
        val mime = try { contentResolver.getType(uri) } catch (e: Exception) { null }
        val nameExt = displayName.substringAfterLast('.', "").lowercase()
        val known = setOf("epub", "pdf", "atlas", "txt", "text", "md", "markdown")
        return when {
            mime == "application/epub+zip" -> "epub"
            mime == "application/pdf" -> "pdf"
            nameExt in known -> nameExt
            mime == "text/plain" && nameExt.isEmpty() -> "txt"
            mime == "text/markdown" && nameExt.isEmpty() -> "md"
            mime == "application/octet-stream" && nameExt.isNotEmpty() -> nameExt
            nameExt.isNotEmpty() -> nameExt
            else -> "atlas"
        }
    }

    // ---------------------------------------------------------------------
    // Self-update install intent (see lib/updater/ + docs/release.md).
    // ---------------------------------------------------------------------

    /** Android 8+: sideloading requires explicit per-app "install unknown apps" consent. */
    private fun canRequestInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    /** Opens the system page where the user opts in to installing from Atlas. */
    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                )
            )
        }
    }

    private fun installApk(apkFile: File): String {
        if (!apkFile.exists() || apkFile.length() == 0L) return "missing"
        if (!canRequestInstall()) return "permission_needed"
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        val install = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = uri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(install)
            "launched"
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "No installer available", Toast.LENGTH_LONG).show()
            "error:${e.message}"
        }
    }
}