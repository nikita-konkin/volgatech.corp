package net.volgatech.volgatech_pro

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * The home-screen widget: the lesson on now or next, and the one after.
 *
 * The app hands it the lessons it has loaded (two weeks at most, see
 * lib/core/lesson_widget.dart); the widget picks from them by the clock and
 * wakes itself when a lesson starts or ends, so it stays right without the
 * app running until those lessons run out.
 */
class LessonWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        render(context, manager, ids)

    override fun onDisabled(context: Context) {
        alarms(context).cancel(tick(context))
    }

    private class Lesson(
        val start: Long,
        val end: Long,
        val day: String,
        val dayLabel: String,
        val from: String,
        val to: String,
        val title: String,
        val room: String,
    )

    companion object {
        private const val PREFS = "lesson_widget"
        private const val KEY = "lessons"

        /** Yoshkar-Ola: the university's clocks, whatever the phone's zone. */
        private val zone: TimeZone = TimeZone.getTimeZone("Europe/Moscow")

        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, json).apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, LessonWidget::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val data = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null)
                ?.let { runCatching { JSONObject(it) }.getOrNull() }
            val now = System.currentTimeMillis()
            val lessons = data?.let { parse(it) } ?: emptyList()
            val upcoming = lessons.filter { it.end > now }.sortedBy { it.start }
            val views = RemoteViews(context.packageName, R.layout.lesson_widget)
            val first = upcoming.firstOrNull()
            if (first == null) {
                // Lessons beyond what was loaded aren't known: the app must
                // fetch them.
                val until = data?.optLong("until") ?: 0L
                views.setTextViewText(R.id.lesson_when, "Расписание")
                views.setViewVisibility(R.id.lesson_time, View.GONE)
                views.setTextViewText(
                    R.id.lesson_title,
                    if (now < until) "Ближайших занятий нет" else "Откройте приложение, чтобы обновить",
                )
                views.setViewVisibility(R.id.lesson_room, View.GONE)
                views.setViewVisibility(R.id.lesson_next, View.GONE)
            } else {
                val today = dayOf(now)
                views.setTextViewText(
                    R.id.lesson_when,
                    if (first.start <= now) "Сейчас · до ${first.to}" else dayLabel(first, today, now),
                )
                views.setViewVisibility(R.id.lesson_time, View.VISIBLE)
                views.setTextViewText(R.id.lesson_time, "${first.from}–${first.to}")
                views.setTextViewText(R.id.lesson_title, first.title)
                views.setViewVisibility(R.id.lesson_room, if (first.room.isEmpty()) View.GONE else View.VISIBLE)
                views.setTextViewText(R.id.lesson_room, first.room)
                val second = upcoming.getOrNull(1)
                if (second == null) {
                    views.setViewVisibility(R.id.lesson_next, View.GONE)
                } else {
                    val day = if (second.day == first.day) "" else "${dayLabel(second, today, now)}, "
                    views.setViewVisibility(R.id.lesson_next, View.VISIBLE)
                    views.setTextViewText(R.id.lesson_next, "Далее: $day${second.from} · ${second.title}")
                }
            }
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.lesson_root, open)
            manager.updateAppWidget(ids, views)
            wakeAt(context, nextChange(upcoming, now))
        }

        private fun parse(data: JSONObject): List<Lesson> {
            val list = data.optJSONArray("lessons") ?: return emptyList()
            return (0 until list.length()).mapNotNull { i ->
                val o = list.optJSONObject(i) ?: return@mapNotNull null
                Lesson(
                    start = o.optLong("start"),
                    end = o.optLong("end"),
                    day = o.optString("day"),
                    dayLabel = o.optString("dayLabel"),
                    from = o.optString("from"),
                    to = o.optString("to"),
                    title = o.optString("title"),
                    room = o.optString("room"),
                )
            }
        }

        /** «2026-10-06» in Yoshkar-Ola. */
        private fun dayOf(millis: Long): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply { timeZone = zone }.format(millis)

        private fun dayLabel(l: Lesson, today: String, now: Long): String = when (l.day) {
            today -> "Сегодня"
            dayOf(now + 24 * 3600 * 1000L) -> "Завтра"
            else -> l.dayLabel
        }

        /** The next moment the widget reads differently: a start, an end, midnight. */
        private fun nextChange(upcoming: List<Lesson>, now: Long): Long {
            val midnight = Calendar.getInstance(zone).apply {
                timeInMillis = now
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val first = upcoming.firstOrNull() ?: return midnight
            val edge = if (first.start > now) first.start else first.end
            return minOf(edge, midnight)
        }

        private fun alarms(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        private fun tick(context: Context): PendingIntent {
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, LessonWidget::class.java))
            val intent = Intent(context, LessonWidget::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            return PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        /**
         * On time, but not waking the phone: the widget is read with the
         * screen on, and an alarm due while it was off comes as it wakes.
         * Inexact (Android may defer it by most of the wait) only if exact
         * alarms were taken away.
         */
        private fun wakeAt(context: Context, at: Long) {
            val alarms = alarms(context)
            val tick = tick(context)
            try {
                if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
                    alarms.setExact(AlarmManager.RTC, at + 1000, tick)
                    return
                }
            } catch (_: SecurityException) {
            }
            alarms.set(AlarmManager.RTC, at + 1000, tick)
        }
    }
}
