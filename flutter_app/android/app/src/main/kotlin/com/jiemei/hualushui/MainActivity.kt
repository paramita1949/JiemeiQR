package com.jiemei.hualushui

import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.jiemei.hualushui/app_update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "path required", null)
                        return@setMethodCallHandler
                    }
                    openApkInstaller(path, result)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.jiemei.hualushui/geofence",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "registerGeofence" -> {
                    GeofenceRegistrar.unregister(applicationContext)
                    AttendanceNativeLog.add(applicationContext, "GEOFENCE_NATIVE", "register ignored foreground-only")
                    result.success("BACKGROUND_GEOFENCE_DISABLED")
                }

                "unregisterGeofence" -> {
                    val unregisterResult = GeofenceRegistrar.unregister(applicationContext)
                    if (unregisterResult.isSuccess) {
                        result.success(unregisterResult.getOrNull())
                    } else {
                        result.error("UNREGISTER_FAILED", unregisterResult.exceptionOrNull()?.message, null)
                    }
                }

                "getLocationProviderSummary" -> {
                    val manager = getSystemService(LOCATION_SERVICE) as LocationManager
                    val gpsEnabled = runCatching { manager.isProviderEnabled(LocationManager.GPS_PROVIDER) }.getOrDefault(false)
                    val networkEnabled = runCatching { manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) }.getOrDefault(false)
                    val passiveEnabled = runCatching { manager.isProviderEnabled(LocationManager.PASSIVE_PROVIDER) }.getOrDefault(false)
                    val summary = "系统融合定位（GPS/北斗/网络），当前开关：GPS=${if (gpsEnabled) "开" else "关"} 网络=${if (networkEnabled) "开" else "关"} 被动=${if (passiveEnabled) "开" else "关"}"
                    result.success(summary)
                }

                "getNativeGeofenceLogs" -> {
                    result.success(AttendanceNativeLog.dump(applicationContext))
                }

                "getAmapCurrentLocation" -> {
                    AmapLocationBridge.locateOnce(applicationContext, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openApkInstaller(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            result.error("APK_NOT_FOUND", "安装包不存在", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            result.error("INSTALL_PERMISSION", "请先允许本应用安装未知来源应用，然后再次点击检查更新", null)
            return
        }
        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.update_file_provider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
            result.success(null)
        } catch (error: Throwable) {
            result.error("INSTALL_FAILED", error.message, null)
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
        return lowerPath.endsWith(".jiemei") ||
            lowerPath.endsWith(".sqlite") ||
            lowerPath.endsWith(".zip") ||
            lowerPath.endsWith(".attendance.json")
    }
}
