package hu.adrian.truenasmobile

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlin.math.roundToInt

/**
 * Shows a running TrueNAS job (scrub, replication, app update, ...) as an
 * ongoing progress notification. On Android 16 and newer it asks to be shown
 * as a live update: a progress chip in the status bar and on the lock screen.
 *
 * Nothing pushes to it: the Dart side updates it while the app is running.
 */
class LiveProgressPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null

    private val manager: NotificationManager
        get() = context.getSystemService(NotificationManager::class.java)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isSupported" -> result.success(true)
                "requestPermission" -> requestPermission(result)
                "show" -> {
                    show(call)
                    result.success(null)
                }
                "end" -> {
                    manager.cancel(call.argument<String>("id"), NOTIFICATION_ID)
                    result.success(null)
                }
                "endAllExcept" -> {
                    endAllExcept((call.argument<List<String>>("keep") ?: emptyList()).toSet())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("failed", e.message, null)
        }
    }

    /** Android 13 and newer ask before a notification may be shown. */
    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(manager.areNotificationsEnabled())
            return
        }
        val current = activity
        if (current == null || pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(
            current,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        pendingPermission?.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        )
        pendingPermission = null
        return true
    }

    private fun show(call: MethodCall) {
        val id = call.argument<String>("id") ?: return
        val status = call.argument<String>("status") ?: "running"
        val title = call.argument<String>("title") ?: ""
        val detail = call.argument<String>("detail") ?: ""
        val server = call.argument<String>("server") ?: ""
        val progress = call.argument<Double>("progress")
        val running = status == "running" || status == "waiting" || status == "stale"
        val percent = ((progress ?: 0.0) * 100).roundToInt().coerceIn(0, 100)
        val indeterminate = progress == null && running

        ensureChannel(
            call.argument<String>("channelName") ?: "Job progress",
            call.argument<String>("channelDescription") ?: "",
        )
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_job)
            .setContentTitle(title)
            .setContentText(detail)
            .setSubText(server)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOnlyAlertOnce(true)
            .setOngoing(running)
            .setAutoCancel(!running)
            .setShowWhen(false)
        if (open != null) {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    context,
                    0,
                    open,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            )
        }
        if (Build.VERSION.SDK_INT >= 36) {
            // Android 16 live update: a progress bar that can be promoted to
            // the status bar chip and the lock screen.
            if (running || status == "done") {
                builder.setStyle(
                    Notification.ProgressStyle()
                        .setProgressSegments(listOf(Notification.ProgressStyle.Segment(100)))
                        .setProgress(if (status == "done") 100 else percent)
                        .setProgressIndeterminate(indeterminate)
                )
            }
            requestPromotedOngoing(builder, running)
            if (running && progress != null) builder.setShortCriticalText("$percent%")
        } else if (running) {
            builder.setProgress(100, percent, indeterminate)
        }
        manager.notify(id, NOTIFICATION_ID, builder.build())
    }

    /**
     * Asks to be shown as a live update. The setter arrived with Android 16
     * QPR2 (API 36.1), which the build's SDK may not have, so it is looked up
     * when it runs and skipped where it is missing.
     */
    private fun requestPromotedOngoing(builder: Notification.Builder, promoted: Boolean) {
        try {
            Notification.Builder::class.java
                .getMethod("setRequestPromotedOngoing", java.lang.Boolean.TYPE)
                .invoke(builder, promoted)
        } catch (_: ReflectiveOperationException) {
            // Older Android 16: the notification stays an ordinary ongoing one.
        }
    }

    private fun ensureChannel(name: String, description: String) {
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW)
        channel.description = description
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    /** Removes what an earlier run of the app left behind. */
    private fun endAllExcept(keep: Set<String>) {
        for (shown in manager.activeNotifications) {
            val tag = shown.tag ?: continue
            if (shown.id == NOTIFICATION_ID &&
                shown.notification.channelId == CHANNEL_ID &&
                tag !in keep
            ) {
                manager.cancel(tag, NOTIFICATION_ID)
            }
        }
    }

    companion object {
        private const val CHANNEL = "hu.adrian.truenasmobile/live_progress"
        private const val CHANNEL_ID = "job_progress"
        private const val NOTIFICATION_ID = 0x4a6f
        private const val PERMISSION_REQUEST = 4711
    }
}
