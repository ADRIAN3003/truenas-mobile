package hu.adrian.truenasmobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// A FragmentActivity, because local_auth shows the biometric prompt in a fragment.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                        "downloadDirectory" -> {
                            val dir = updatesDirectory()
                            dir.mkdirs()
                            result.success(dir.absolutePath)
                        }
                        "canInstall" -> result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls()
                        )
                        "openInstallSettings" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:$packageName"),
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
                                install(File(path))
                                result.success(null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }
        // Android 13 and newer have a language page for each app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LANGUAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                    when (call.method) {
                        "supported" -> result.success(supported)
                        "open" -> {
                            if (supported) {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_APP_LOCALE_SETTINGS,
                                        Uri.parse("package:$packageName"),
                                    )
                                )
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }
    }

    private fun updatesDirectory() = File(cacheDir, "updates")

    /** Opens the system installer on an APK the app downloaded. */
    private fun install(apk: File) {
        // Only what the app downloaded itself, never an arbitrary file.
        val allowed = updatesDirectory().canonicalPath + File.separator
        require(apk.canonicalPath.startsWith(allowed)) { "not an update file" }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(intent)
    }

    companion object {
        private const val CHANNEL = "hu.adrian.truenasmobile/installer"
        private const val LANGUAGE_CHANNEL = "hu.adrian.truenasmobile/language"
    }
}
