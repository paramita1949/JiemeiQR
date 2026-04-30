package com.jiemei.hualushui

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var pendingImportPath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cacheImportPathFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        cacheImportPathFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.jiemei.hualushui/backup_import",
        ).setMethodCallHandler { call, result ->
            if (call.method == "consumePendingImportPath") {
                val path = pendingImportPath
                pendingImportPath = null
                result.success(path)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun cacheImportPathFromIntent(intent: Intent?) {
        if (intent == null) {
            return
        }
        val action = intent.action ?: return
        val uri = when (action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else -> null
        } ?: return

        val importedPath = resolveToImportPath(uri) ?: return
        if (!isImportFile(importedPath)) {
            return
        }
        pendingImportPath = importedPath
    }

    private fun resolveToImportPath(uri: Uri): String? {
        if (uri.scheme == "file") {
            return uri.path
        }
        if (uri.scheme != "content") {
            return null
        }
        return try {
            val fileName = queryDisplayName(uri) ?: "incoming-${System.currentTimeMillis()}.jiemei"
            val importDir = File(cacheDir, "incoming-imports")
            if (!importDir.exists()) {
                importDir.mkdirs()
            }
            val targetFile = File(importDir, fileName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            targetFile.path
        } catch (_: Throwable) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) cursor.getString(index) else null
                    } else {
                        null
                    }
                }
        }.getOrNull()
    }

    private fun isImportFile(path: String): Boolean {
        val lowerPath = path.lowercase()
        return lowerPath.endsWith(".jiemei") || lowerPath.endsWith(".sqlite") || lowerPath.endsWith(".zip")
    }
}
