package hu.adrian.truenasmobile

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

/**
 * Asks which server a new widget shows. With no server or only one saved there
 * is nothing to ask, and the widget is added at once.
 */
class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Backing out cancels the widget.
        setResult(RESULT_CANCELED)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val servers = WidgetStore.servers(WidgetStore.document(this))
        if (servers.size <= 1) {
            done(servers.firstOrNull()?.optString("id"))
            return
        }
        AlertDialog.Builder(this)
            .setTitle(R.string.widget_choose_server)
            .setItems(servers.map { it.optString("name") }.toTypedArray()) { _, which ->
                done(servers[which].optString("id"))
            }
            .setOnCancelListener { finish() }
            .show()
    }

    private fun done(serverId: String?) {
        if (serverId != null) WidgetStore.choose(this, widgetId, serverId)
        // The widget is not drawn until this says so, so draw it now.
        val manager = AppWidgetManager.getInstance(this)
        for (provider in listOf(
            PoolsWidgetProvider::class.java,
            SystemWidgetProvider::class.java,
            AlertsWidgetProvider::class.java,
        )) {
            if (manager.getAppWidgetInfo(widgetId)?.provider?.className == provider.name) {
                sendBroadcast(
                    Intent(this, provider)
                        .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId)),
                )
            }
        }
        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
        )
        finish()
    }
}
