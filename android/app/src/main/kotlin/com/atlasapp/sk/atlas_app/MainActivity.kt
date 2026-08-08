package com.atlasapp.sk.atlas_app

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.atlasapp/file_open"
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
        channel?.invokeMethod("onFileOpened", path)
    }

    private fun openedUri(intent: Intent?): Uri? =
        when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            else -> null
        }

    private fun copyToCache(uri: Uri): String? {
        val name = queryDisplayName(uri) ?: "opened"
        val ext = resolveExtension(uri, name)
        val file = File(cacheDir, "opened_${System.currentTimeMillis()}.$ext")
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            file.absolutePath
        } catch (e: Exception) {
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
        return when (mime) {
            "application/epub+zip" -> "epub"
            "application/pdf" -> "pdf"
            else -> if (nameExt in setOf("epub", "pdf", "atlas")) nameExt else "atlas"
        }
    }
}