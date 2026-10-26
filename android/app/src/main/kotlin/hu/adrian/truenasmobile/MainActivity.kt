package hu.adrian.truenasmobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// A FragmentActivity, because local_auth shows the biometric prompt in a fragment.
class MainActivity : FlutterFragmentActivity() {
    private var quickActionsChannel: MethodChannel? = null

    /** The home screen shortcut that started the app, until Dart has asked for it. */
    private var launchQuickAction: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A recreated activity still holds the intent that started it, and
        // that shortcut has been handled already.
        if (savedInstanceState == null) launchQuickAction = quickActionFrom(intent)
        super.onCreate(savedInstanceState)
    }

    // A shortcut tapped while the app is open.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        quickActionFrom(intent)?.let { quickActionsChannel?.invokeMethod("action", it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Progress of running jobs as a notification.
        flutterEngine.plugins.add(LiveProgressPlugin())
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
        // Home screen shortcuts that start, stop or restart an app, or run a
        // cloud sync.
        quickActionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QUICK_ACTIONS_CHANNEL)
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    try {
                        when (call.method) {
                            "canPin" -> result.success(ShortcutManagerCompat.isRequestPinShortcutSupported(this))
                            "pin" -> result.success(
                                pinShortcut(
                                    call.argument<String>("serverId"),
                                    call.argument<String>("kind"),
                                    call.argument<String>("target"),
                                    call.argument<String>("label"),
                                )
                            )
                            "launchAction" -> {
                                result.success(launchQuickAction)
                                launchQuickAction = null
                            }
                            else -> result.notImplemented()
                        }
                    } catch (e: Exception) {
                        result.error("failed", e.message, null)
                    }
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

    /** What a shortcut of this app says, or null for any other intent. */
    private fun quickActionFrom(intent: Intent?): Map<String, String>? {
        if (intent?.action != ACTION_QUICK_ACTION) return null
        val serverId = intent.getStringExtra("serverId")
        val kind = intent.getStringExtra("kind")
        val target = intent.getStringExtra("target")
        if (serverId == null || kind == null || target == null) return null
        return mapOf("serverId" to serverId, "kind" to kind, "target" to target)
    }

    /** Asks the launcher to pin a shortcut; it may ask the user to confirm. */
    private fun pinShortcut(serverId: String?, kind: String?, target: String?, label: String?): Boolean {
        if (serverId == null || kind == null || target == null || label == null) return false
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(this)) return false
        val intent = Intent(this, MainActivity::class.java)
            .setAction(ACTION_QUICK_ACTION)
            .putExtra("serverId", serverId)
            .putExtra("kind", kind)
            .putExtra("target", target)
        // The same server, action and target replace the shortcut already pinned.
        val shortcut = ShortcutInfoCompat.Builder(this, "$serverId/$kind/$target")
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(IconCompat.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()
        return ShortcutManagerCompat.requestPinShortcut(this, shortcut, null)
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
        private const val QUICK_ACTIONS_CHANNEL = "hu.adrian.truenasmobile/quick_actions"
        private const val ACTION_QUICK_ACTION = "hu.adrian.truenasmobile.QUICK_ACTION"
    }
}
