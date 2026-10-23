package hu.adrian.truenasmobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date

/**
 * The home screen widgets: pool health, CPU and memory, and alerts. They only
 * draw what the app saved (see `lib/core/widgets/` on the Dart side): one JSON
 * document in the `home_widget` plugin's preferences, with the text already in
 * the user's language. Each widget shows one server, chosen when it is added.
 */
object WidgetStore {
    // The plugin's file and the key `home_widgets.dart` saves under.
    private const val DATA_FILE = "HomeWidgetPreferences"
    private const val DOCUMENT_KEY = "snapshot.v1"
    private const val CHOICE_FILE = "home_widget_choice"

    fun document(context: Context): JSONObject? {
        val raw = context.getSharedPreferences(DATA_FILE, Context.MODE_PRIVATE)
            .getString(DOCUMENT_KEY, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    fun servers(document: JSONObject?): List<JSONObject> {
        val list = document?.optJSONArray("servers") ?: return emptyList()
        return (0 until list.length()).mapNotNull { list.optJSONObject(it) }
    }

    /** The server chosen for [widgetId], else the app's default, else the first. */
    fun server(context: Context, document: JSONObject?, widgetId: Int): JSONObject? {
        val all = servers(document)
        val chosen = chosenServer(context, widgetId)
        return all.firstOrNull { it.optString("id") == chosen }
            ?: all.firstOrNull { it.optString("id") == document?.optString("defaultId") }
            ?: all.firstOrNull()
    }

    fun chosenServer(context: Context, widgetId: Int): String? =
        context.getSharedPreferences(CHOICE_FILE, Context.MODE_PRIVATE)
            .getString("server_$widgetId", null)

    fun choose(context: Context, widgetId: Int, serverId: String) {
        context.getSharedPreferences(CHOICE_FILE, Context.MODE_PRIVATE).edit()
            .putString("server_$widgetId", serverId).apply()
    }

    fun forget(context: Context, widgetIds: IntArray) {
        val edit = context.getSharedPreferences(CHOICE_FILE, Context.MODE_PRIVATE).edit()
        widgetIds.forEach { edit.remove("server_$it") }
        edit.apply()
    }

    fun label(document: JSONObject?, key: String, fallback: String): String =
        document?.optJSONObject("labels")?.optString(key)?.takeIf { it.isNotEmpty() } ?: fallback
}

/** Draws one kind of widget; the three below only say which. */
abstract class StatusWidgetProvider : AppWidgetProvider() {
    protected abstract val layout: Int
    protected abstract fun fill(
        context: Context,
        views: RemoteViews,
        document: JSONObject,
        server: JSONObject,
    )

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val document = WidgetStore.document(context)
        for (id in appWidgetIds) {
            manager.updateAppWidget(id, build(context, document, id))
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetStore.forget(context, appWidgetIds)
    }

    private fun build(context: Context, document: JSONObject?, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            views.setOnClickPendingIntent(
                R.id.root,
                PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        val server = WidgetStore.server(context, document, widgetId)
        if (document == null || server == null) {
            views.setTextViewText(R.id.title, "TrueNAS")
            views.setTextViewText(
                R.id.footer,
                WidgetStore.label(document, "setup", "Open TrueNAS Mobile to set up"),
            )
            hideBody(views)
            return views
        }
        views.setTextViewText(R.id.title, server.optString("name"))
        fill(context, views, document, server)
        views.setTextViewText(R.id.footer, footer(context, document, server))
        views.setTextColor(
            R.id.footer,
            context.getColor(
                if (server.optBoolean("unreachable")) R.color.widget_warn
                else R.color.widget_text_secondary,
            ),
        )
        return views
    }

    /** Nothing to show yet: the footer carries the message. */
    protected open fun hideBody(views: RemoteViews) {}

    private fun footer(context: Context, document: JSONObject, server: JSONObject): String {
        if (server.optBoolean("unreachable")) {
            return WidgetStore.label(document, "unreachable", "Can't reach the server")
        }
        if (!server.has("updatedAt") || server.isNull("updatedAt")) {
            return WidgetStore.label(document, "noData", "No data yet. Open the app.")
        }
        val time = DateFormat.getTimeFormat(context).format(Date(server.optLong("updatedAt")))
        return "${WidgetStore.label(document, "updated", "Updated")} $time"
    }

    protected fun color(context: Context, level: String?): Int = context.getColor(
        when (level) {
            "bad" -> R.color.widget_bad
            "warn" -> R.color.widget_warn
            else -> R.color.widget_ok
        },
    )

    /** Shows only the bar of [level] among [ids] (one per colour). */
    protected fun showBar(views: RemoteViews, ids: Map<String, Int>, level: String, percent: Int) {
        for ((name, id) in ids) {
            views.setViewVisibility(id, if (name == level) View.VISIBLE else View.GONE)
            if (name == level) views.setProgressBar(id, 100, percent.coerceIn(0, 100), false)
        }
    }

    protected fun JSONArray?.objects(): List<JSONObject> =
        if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }
}

class PoolsWidgetProvider : StatusWidgetProvider() {
    override val layout = R.layout.widget_pools

    private val rows = listOf(
        Triple(R.id.pool1, R.id.pool1_name, R.id.pool1_value),
        Triple(R.id.pool2, R.id.pool2_name, R.id.pool2_value),
        Triple(R.id.pool3, R.id.pool3_name, R.id.pool3_value),
    )
    private val bars = listOf(
        mapOf("ok" to R.id.pool1_bar_ok, "warn" to R.id.pool1_bar_warn, "bad" to R.id.pool1_bar_bad),
        mapOf("ok" to R.id.pool2_bar_ok, "warn" to R.id.pool2_bar_warn, "bad" to R.id.pool2_bar_bad),
        mapOf("ok" to R.id.pool3_bar_ok, "warn" to R.id.pool3_bar_warn, "bad" to R.id.pool3_bar_bad),
    )

    override fun hideBody(views: RemoteViews) {
        views.setTextViewText(R.id.summary, "")
        rows.forEach { views.setViewVisibility(it.first, View.GONE) }
    }

    override fun fill(context: Context, views: RemoteViews, document: JSONObject, server: JSONObject) {
        val pools = server.optJSONObject("pools")
        if (pools == null) {
            views.setTextViewText(R.id.summary, "")
            rows.forEach { views.setViewVisibility(it.first, View.GONE) }
            return
        }
        views.setTextViewText(R.id.summary, pools.optString("summary"))
        views.setTextColor(R.id.summary, color(context, pools.optString("level")))
        val items = pools.optJSONArray("items").objects()
        rows.forEachIndexed { index, (row, name, value) ->
            val item = items.getOrNull(index)
            if (item == null) {
                views.setViewVisibility(row, View.GONE)
                return@forEachIndexed
            }
            val level = item.optString("level", "ok")
            val used = item.optDouble("used", 0.0)
            views.setViewVisibility(row, View.VISIBLE)
            views.setTextViewText(name, item.optString("name"))
            views.setTextViewText(
                value,
                if (level == "ok") "${used.toInt()}%" else item.optString("status"),
            )
            views.setTextColor(
                value,
                if (level == "ok") context.getColor(R.color.widget_text_secondary)
                else color(context, level),
            )
            showBar(views, bars[index], level, used.toInt())
        }
    }
}

class SystemWidgetProvider : StatusWidgetProvider() {
    override val layout = R.layout.widget_system

    override fun hideBody(views: RemoteViews) {
        views.setViewVisibility(R.id.cpu, View.GONE)
        views.setViewVisibility(R.id.mem, View.GONE)
        views.setTextViewText(R.id.detail, "")
    }

    override fun fill(context: Context, views: RemoteViews, document: JSONObject, server: JSONObject) {
        val system = server.optJSONObject("system")
        if (system == null) {
            hideBody(views)
            views.setTextViewText(
                R.id.detail,
                WidgetStore.label(document, "noData", "No data yet. Open the app."),
            )
            return
        }
        metric(
            context, views, R.id.cpu, R.id.cpu_label, R.id.cpu_value,
            WidgetStore.label(document, "cpu", "CPU"),
            system, "cpu",
            mapOf("info" to R.id.cpu_bar_info, "warn" to R.id.cpu_bar_warn, "bad" to R.id.cpu_bar_bad),
        )
        metric(
            context, views, R.id.mem, R.id.mem_label, R.id.mem_value,
            WidgetStore.label(document, "memory", "RAM"),
            system, "memory",
            mapOf("info" to R.id.mem_bar_info, "warn" to R.id.mem_bar_warn, "bad" to R.id.mem_bar_bad),
        )
        val detail = listOf(system.optString("memoryText"), system.optString("temperature"))
            .filter { it.isNotEmpty() && it != "null" }
            .joinToString("  ·  ")
        views.setTextViewText(R.id.detail, detail)
    }

    private fun metric(
        context: Context,
        views: RemoteViews,
        row: Int,
        label: Int,
        value: Int,
        title: String,
        system: JSONObject,
        key: String,
        bars: Map<String, Int>,
    ) {
        if (!system.has(key) || system.isNull(key)) {
            views.setViewVisibility(row, View.GONE)
            return
        }
        val percent = system.optDouble(key, 0.0)
        // Blue until the load is high, like the iPhone widget.
        val level = if (percent >= 90) "bad" else if (percent >= 75) "warn" else "info"
        views.setViewVisibility(row, View.VISIBLE)
        views.setTextViewText(label, title)
        views.setTextViewText(value, "${percent.toInt()}%")
        showBar(views, bars, level, percent.toInt())
    }
}

class AlertsWidgetProvider : StatusWidgetProvider() {
    override val layout = R.layout.widget_alerts

    private val rows = listOf(
        Triple(R.id.alert1, R.id.alert1_dot, R.id.alert1_text),
        Triple(R.id.alert2, R.id.alert2_dot, R.id.alert2_text),
        Triple(R.id.alert3, R.id.alert3_dot, R.id.alert3_text),
    )

    /** Row, title, value and bar of the scrubs and cloud syncs that run. */
    private val jobRows = listOf(
        listOf(R.id.job1, R.id.job1_title, R.id.job1_value, R.id.job1_bar),
        listOf(R.id.job2, R.id.job2_title, R.id.job2_value, R.id.job2_bar),
    )

    override fun hideBody(views: RemoteViews) {
        views.setTextViewText(R.id.count, "")
        views.setTextViewText(R.id.summary, "")
        rows.forEach { views.setViewVisibility(it.first, View.GONE) }
        jobRows.forEach { views.setViewVisibility(it[0], View.GONE) }
    }

    override fun fill(context: Context, views: RemoteViews, document: JSONObject, server: JSONObject) {
        val alerts = server.optJSONObject("alerts")
        if (alerts == null) {
            hideBody(views)
            return
        }
        val count = alerts.optInt("count")
        views.setTextViewText(R.id.count, count.toString())
        views.setTextColor(
            R.id.count,
            if (count == 0) context.getColor(R.color.widget_ok)
            else color(context, alerts.optString("level")),
        )
        views.setTextViewText(R.id.summary, alerts.optString("summary"))
        val jobs = server.optJSONObject("jobs")?.optJSONArray("items").objects()
        // The jobs take the room of the last alert.
        val alertRows = if (jobs.isEmpty()) rows.size else rows.size - 1
        val items = alerts.optJSONArray("items").objects()
        rows.forEachIndexed { index, (row, dot, text) ->
            val item = if (index < alertRows) items.getOrNull(index) else null
            if (item == null) {
                views.setViewVisibility(row, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(row, View.VISIBLE)
            views.setTextColor(dot, color(context, item.optString("level")))
            views.setTextViewText(text, item.optString("text"))
        }
        jobRows.forEachIndexed { index, (row, title, value, bar) ->
            val job = jobs.getOrNull(index)
            if (job == null) {
                views.setViewVisibility(row, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(row, View.VISIBLE)
            views.setTextViewText(title, job.optString("title"))
            if (job.isNull("percent") || !job.has("percent")) {
                // Not started, or no progress to report: say what it is doing.
                views.setTextViewText(value, job.optString("detail"))
                views.setViewVisibility(bar, View.GONE)
            } else {
                val percent = job.optDouble("percent", 0.0)
                views.setTextViewText(value, "${percent.toInt()}%")
                views.setViewVisibility(bar, View.VISIBLE)
                views.setProgressBar(bar, 100, percent.toInt().coerceIn(0, 100), false)
            }
        }
    }
}
