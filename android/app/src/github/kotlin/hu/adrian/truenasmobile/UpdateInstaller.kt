package hu.adrian.truenasmobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Installs the app update that Dart downloaded from GitHub Releases. This file
 * is only in the `github` flavor; the `play` flavor has an empty
 * [UpdateInstaller] of the same name, no REQUEST_INSTALL_PACKAGES permission
 * and no update FileProvider (Google Play forbids an app updating itself).
 */
object UpdateInstaller {
    private const val CHANNEL = "hu.adrian.truenasmobile/installer"

    fun register(activity: Activity, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                        "downloadDirectory" -> {
                            val dir = updatesDirectory(activity)
                            dir.mkdirs()
                            result.success(dir.absolutePath)
                        }
                        "canInstall" -> result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                activity.packageManager.canRequestPackageInstalls()
                        )
                        "openInstallSettings" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                activity.startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:${activity.packageName}"),
                                    )
                                )
                            }
                            result.success(null)
                        }
                        "install" -> {
                            val path = call.argument<String>("path")
                            if (path == null) {
                                result.error("bad_args", "path is missing", null)
                            } else {
                                install(activity, File(path))
                                result.success(null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }
    }

    private fun updatesDirectory(activity: Activity) = File(activity.cacheDir, "updates")

    /** Opens the system installer on an APK the app downloaded. */
    private fun install(activity: Activity, apk: File) {
        // Only what the app downloaded itself, never an arbitrary file.
        val allowed = updatesDirectory(activity).canonicalPath + File.separator
        require(apk.canonicalPath.startsWith(allowed)) { "not an update file" }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(intent)
    }
}
