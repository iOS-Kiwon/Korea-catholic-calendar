package com.sidore.catholiccalendar

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

open class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, appWidgetManager, appWidgetId)
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (handleWidgetAction(context, intent)) return
        super.onReceive(context, intent)
        // 자정 자체 갱신 알람 + 재부팅/시간·시간대 변경 시 위젯을 다시 그리고 알람을 재예약.
        when (intent.action) {
            ACTION_MIDNIGHT_UPDATE,
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_DATE_CHANGED -> refreshAllWidgets(context)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // 이 크기의 마지막 위젯이 제거됨. 다른 크기 위젯이 남아있지 않으면 알람도 취소.
        refreshAllWidgets(context)
    }

    companion object {
        // 자정 자체 갱신 알람이 위젯 provider로 보내는 커스텀 액션.
        const val ACTION_MIDNIGHT_UPDATE =
            "com.sidore.catholiccalendar.action.WIDGET_MIDNIGHT_UPDATE"
        private const val ACTION_PREV_MONTH =
            "com.sidore.catholiccalendar.action.WIDGET_PREV_MONTH"
        private const val ACTION_NEXT_MONTH =
            "com.sidore.catholiccalendar.action.WIDGET_NEXT_MONTH"
        private const val ACTION_TODAY_MONTH =
            "com.sidore.catholiccalendar.action.WIDGET_TODAY_MONTH"
        private const val EXTRA_APP_WIDGET_ID = "appWidgetId"
        private const val PREF_WIDGET_STATE = "widget_state"

        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray
        ) {
            for (appWidgetId in appWidgetIds) {
                appWidgetManager.updateAppWidget(
                    appWidgetId,
                    buildViews(context, appWidgetManager, appWidgetId)
                )
            }
            // 위젯을 그릴 때마다 다음 자정 갱신을 (재)예약한다.
            scheduleMidnightUpdate(context)
        }

        // 두 크기 provider의 모든 위젯을 다시 그린다. 남은 위젯이 없으면 알람을 취소.
        private fun refreshAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val components = listOf(
                ComponentName(context, TodayWidgetTwoByTwoProvider::class.java),
                ComponentName(context, TodayWidgetFourByFourProvider::class.java)
            )
            var hasAny = false
            for (component in components) {
                val ids = manager.getAppWidgetIds(component)
                if (ids.isNotEmpty()) {
                    hasAny = true
                    updateWidgets(context, manager, ids)
                }
            }
            if (!hasAny) cancelMidnightUpdate(context)
        }

        private fun scheduleMidnightUpdate(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pending = midnightPendingIntent(context)
            alarmManager.cancel(pending)
            // 부정확 예약(setAndAllowWhileIdle): SCHEDULE_EXACT_ALARM 권한이 필요 없고
            // 배터리에 안전하다. 초 단위 정확도는 보장되지 않지만 자정 직후 가까운 시점에
            // 위젯이 다시 그려진다. 앱 실행 시에도 재렌더링되므로 실사용상 충분하다.
            try {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC,
                    nextMidnightMillis(),
                    pending
                )
            } catch (_: Exception) {
                // 일부 기기에서 예약이 거부될 수 있으나 앱 실행/12시간 주기 갱신으로 보완됨.
            }
        }

        private fun cancelMidnightUpdate(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            alarmManager.cancel(midnightPendingIntent(context))
        }

        private fun midnightPendingIntent(context: Context): PendingIntent {
            // 매니페스트에 등록된 리시버(2x2)로 보낸다. 명시적 인텐트이므로 항상 전달되며,
            // 처리 시 두 크기 위젯을 모두 다시 그린다.
            val intent = Intent(context, TodayWidgetTwoByTwoProvider::class.java).apply {
                action = ACTION_MIDNIGHT_UPDATE
            }
            return PendingIntent.getBroadcast(
                context,
                1,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun nextMidnightMillis(): Long {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_MONTH, 1)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 1)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }

        private fun buildViews(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ): RemoteViews {
            val snapshot = readSnapshot(context)
            // baked된 today/isToday 대신 현재 날짜로 '오늘'을 판정한다.
            val todayKey = todayKey()
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val mode = widgetMode(minWidth, minHeight)

            val views = when (mode) {
                WidgetMode.Tiny -> buildSmallViews(context, snapshot, mode, todayKey)
                WidgetMode.WideShort -> buildSmallViews(context, snapshot, mode, todayKey)
                WidgetMode.Compact -> buildSmallViews(context, snapshot, mode, todayKey)
                WidgetMode.Calendar -> buildLargeViews(context, snapshot, todayKey, appWidgetId)
            }

            views.setOnClickPendingIntent(R.id.today_widget_root, openAppIntent(context))
            return views
        }

        private fun buildSmallViews(
            context: Context,
            snapshot: JSONObject,
            mode: WidgetMode,
            todayKey: String
        ): RemoteViews {
            // 스냅샷의 42칸 격자에서 오늘 셀을 찾는다. 없으면(예외적) baked된 today로 폴백.
            val dayCell = findDayByKey(snapshot, todayKey)
            val dateLabel: String
            val liturgyTitle: String
            val liturgyColor: String
            val regularEventDisplayText: String
            val saintFeastDisplayText: String
            if (dayCell != null) {
                dateLabel = dayCell.optString("dateLabel").ifBlank { fallbackDateLabel() }
                liturgyTitle = dayCell.optString("titleFull").ifBlank { "오늘의 전례" }
                liturgyColor = dayCell.optString("liturgicalColor")
                regularEventDisplayText = dayCell.optString("regularEventDisplayText")
                saintFeastDisplayText = dayCell.optString("saintFeastDisplayText")
                return buildSmallViewsWithText(
                    context,
                    mode,
                    dateLabel,
                    liturgyTitle,
                    liturgyColor,
                    regularEventDisplayText,
                    saintFeastDisplayText
                )
            } else {
                val today = snapshot.optJSONObject("today") ?: JSONObject()
                dateLabel = today.optString("dateLabel", fallbackDateLabel())
                liturgyTitle = today.optString("liturgicalTitle", "오늘의 전례")
                liturgyColor = today.optString("liturgicalColor")
                regularEventDisplayText = today.optString("regularEventDisplayText")
                saintFeastDisplayText = today.optString("saintFeastDisplayText")
                return buildSmallViewsWithText(
                    context,
                    mode,
                    dateLabel,
                    liturgyTitle,
                    liturgyColor,
                    regularEventDisplayText,
                    saintFeastDisplayText
                )
            }
        }

        private fun buildSmallViewsWithText(
            context: Context,
            mode: WidgetMode,
            dateLabel: String,
            liturgyTitle: String,
            liturgyColor: String,
            regularEventDisplayText: String,
            saintFeastDisplayText: String
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.today_widget_small)

            applySmallMode(context, views, mode)
            views.setTextViewText(
                R.id.today_widget_date,
                dateLabelForMode(dateLabel, mode)
            )
            views.setTextViewText(R.id.today_widget_liturgy, liturgyTitle)
            views.setTextColor(
                R.id.today_widget_liturgy,
                liturgicalColor(liturgyColor)
            )
            val regularText = regularEventDisplayText
            if (regularText.isBlank() || mode == WidgetMode.Tiny) {
                views.setViewVisibility(R.id.today_widget_event, View.GONE)
            } else {
                views.setViewVisibility(R.id.today_widget_event, View.VISIBLE)
                views.setTextViewText(R.id.today_widget_event, regularText)
            }
            if (saintFeastDisplayText.isBlank() || mode == WidgetMode.Tiny) {
                views.setViewVisibility(R.id.today_widget_feast, View.GONE)
            } else {
                views.setViewVisibility(R.id.today_widget_feast, View.VISIBLE)
                views.setTextViewText(R.id.today_widget_feast, saintFeastDisplayText)
            }
            return views
        }

        private fun applySmallMode(context: Context, views: RemoteViews, mode: WidgetMode) {
            when (mode) {
                WidgetMode.Tiny -> {
                    views.setTextViewTextSize(R.id.today_widget_date, TypedValue.COMPLEX_UNIT_SP, 18f)
                    views.setTextViewTextSize(R.id.today_widget_liturgy, TypedValue.COMPLEX_UNIT_SP, 12f)
                    views.setViewPadding(
                        R.id.today_widget_root,
                        dp(context, 4),
                        dp(context, 4),
                        dp(context, 4),
                        dp(context, 4)
                    )
                }
                WidgetMode.WideShort -> {
                    views.setTextViewTextSize(R.id.today_widget_date, TypedValue.COMPLEX_UNIT_SP, 19f)
                    views.setTextViewTextSize(R.id.today_widget_liturgy, TypedValue.COMPLEX_UNIT_SP, 13f)
                    views.setTextViewTextSize(R.id.today_widget_event, TypedValue.COMPLEX_UNIT_SP, 12f)
                    views.setViewPadding(
                        R.id.today_widget_root,
                        dp(context, 6),
                        dp(context, 5),
                        dp(context, 6),
                        dp(context, 5)
                    )
                }
                WidgetMode.Compact -> {
                    views.setTextViewTextSize(R.id.today_widget_date, TypedValue.COMPLEX_UNIT_SP, 24f)
                    views.setTextViewTextSize(R.id.today_widget_liturgy, TypedValue.COMPLEX_UNIT_SP, 15f)
                    views.setTextViewTextSize(R.id.today_widget_event, TypedValue.COMPLEX_UNIT_SP, 13f)
                    views.setTextViewTextSize(R.id.today_widget_feast, TypedValue.COMPLEX_UNIT_SP, 13f)
                    views.setViewPadding(
                        R.id.today_widget_root,
                        dp(context, 6),
                        dp(context, 18),
                        dp(context, 6),
                        dp(context, 6)
                    )
                }
                WidgetMode.Calendar -> Unit
            }
        }

        private fun buildLargeViews(
            context: Context,
            snapshot: JSONObject,
            todayKey: String,
            appWidgetId: Int
        ): RemoteViews {
            val targetSerial = displayedMonthSerial(context, snapshot, appWidgetId)
            val month = findMonthBySerial(snapshot, targetSerial)
                ?: snapshot.optJSONObject("month")
                ?: JSONObject()
            val days = month.optJSONArray("days") ?: JSONArray()
            val views = RemoteViews(context.packageName, R.layout.today_widget_large)
            views.setTextViewText(R.id.today_widget_month_title, month.optString("title", ""))
            views.removeAllViews(R.id.today_widget_month_rows)
            views.setOnClickPendingIntent(
                R.id.today_widget_prev,
                widgetActionIntent(context, appWidgetId, ACTION_PREV_MONTH)
            )
            views.setOnClickPendingIntent(
                R.id.today_widget_next,
                widgetActionIntent(context, appWidgetId, ACTION_NEXT_MONTH)
            )
            views.setOnClickPendingIntent(
                R.id.today_widget_today,
                widgetActionIntent(context, appWidgetId, ACTION_TODAY_MONTH)
            )
            for (rowIndex in 0 until 6) {
                val row = RemoteViews(context.packageName, R.layout.today_widget_month_row)
                for (colIndex in 0 until 7) {
                    val day = days.optJSONObject(rowIndex * 7 + colIndex) ?: JSONObject()
                    row.addView(
                        R.id.today_widget_month_row,
                        buildDayCell(
                            context,
                            day,
                            todayKey
                        )
                    )
                }
                views.addView(R.id.today_widget_month_rows, row)
            }
            return views
        }

        fun handleWidgetAction(context: Context, intent: Intent): Boolean {
            val action = intent.action ?: return false
            if (action != ACTION_PREV_MONTH &&
                action != ACTION_NEXT_MONTH &&
                action != ACTION_TODAY_MONTH
            ) {
                return false
            }

            val appWidgetId = intent.getIntExtra(
                EXTRA_APP_WIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return true

            val snapshot = readSnapshot(context)
            val current = displayedMonthSerial(context, snapshot, appWidgetId)
            val next = when (action) {
                ACTION_PREV_MONTH -> current - 1
                ACTION_NEXT_MONTH -> current + 1
                else -> currentMonthSerial()
            }
            saveDisplayedMonthSerial(context, appWidgetId, next)
            val manager = AppWidgetManager.getInstance(context)
            manager.updateAppWidget(
                appWidgetId,
                buildViews(context, manager, appWidgetId)
            )
            return true
        }

        private fun buildDayCell(
            context: Context,
            day: JSONObject,
            todayKey: String
        ): RemoteViews {
            val cell = RemoteViews(context.packageName, R.layout.today_widget_day_cell)
            val inMonth = day.optBoolean("inMonth")
            // baked된 isToday 대신 현재 날짜 기준으로 판정.
            val isToday = day.optString("dateKey") == todayKey
            val eventTitle = day.optString("eventTitle")
            val eventDisplayText = day.optString("eventDisplayText").ifBlank { eventTitle }
            val liturgyTitle = day.optString("liturgicalTitle")
            val eventLines = eventLines(day, eventDisplayText)

            cell.setTextViewText(R.id.today_widget_day_number, day.optInt("day").toString())
            cell.setTextColor(
                R.id.today_widget_day_number,
                dayNumberColor(day.optInt("weekday"), inMonth, isToday)
            )
            cell.setInt(
                R.id.today_widget_day_root,
                "setBackgroundColor",
                if (isToday) Color.rgb(255, 229, 180) else Color.TRANSPARENT
            )

            val primaryText = when {
                eventLines.isNotEmpty() -> eventLines.joinToString("\n")
                else -> liturgyTitle
            }
            cell.setTextViewText(R.id.today_widget_day_title, primaryText)
            cell.setTextColor(
                R.id.today_widget_day_title,
                if (eventLines.isNotEmpty() || eventTitle.isNotBlank()) Color.rgb(29, 27, 32)
                else liturgicalColor(day.optString("liturgicalColor"))
            )
            return cell
        }

        private fun eventLines(day: JSONObject, fallback: String): List<String> {
            val items = day.optJSONArray("eventItems")
            if (items != null) {
                val lines = mutableListOf<String>()
                for (index in 0 until minOf(3, items.length())) {
                    val title = items.optJSONObject(index)?.optString("title").orEmpty()
                    if (title.isNotBlank()) lines.add(title)
                }
                if (lines.isNotEmpty()) return lines
            }
            return if (fallback.isNotBlank()) listOf(fallback) else emptyList()
        }

        // 스냅샷 격자(month.days)에서 dateKey가 일치하는 날 셀을 찾는다.
        private fun findDayByKey(snapshot: JSONObject, todayKey: String): JSONObject? {
            val days = snapshot.optJSONObject("month")?.optJSONArray("days") ?: return null
            for (i in 0 until days.length()) {
                val day = days.optJSONObject(i) ?: continue
                if (day.optString("dateKey") == todayKey) return day
            }
            return null
        }

        private fun readSnapshot(context: Context): JSONObject {
            val raw = context
                .getSharedPreferences("widget_snapshot", Context.MODE_PRIVATE)
                .getString("widget_snapshot", null)
            return try {
                if (raw.isNullOrBlank()) JSONObject() else JSONObject(raw)
            } catch (_: Exception) {
                JSONObject()
            }
        }

        private fun displayedMonthSerial(
            context: Context,
            snapshot: JSONObject,
            appWidgetId: Int
        ): Int {
            val prefs = context.getSharedPreferences(PREF_WIDGET_STATE, Context.MODE_PRIVATE)
            val saved = prefs.getInt(monthStateKey(appWidgetId), Int.MIN_VALUE)
            if (saved != Int.MIN_VALUE) return saved
            val month = snapshot.optJSONObject("month")
            val year = month?.optInt("year") ?: Calendar.getInstance().get(Calendar.YEAR)
            val monthValue = month?.optInt("month") ?: (Calendar.getInstance().get(Calendar.MONTH) + 1)
            return monthSerial(year, monthValue)
        }

        private fun saveDisplayedMonthSerial(context: Context, appWidgetId: Int, serial: Int) {
            context.getSharedPreferences(PREF_WIDGET_STATE, Context.MODE_PRIVATE)
                .edit()
                .putInt(monthStateKey(appWidgetId), serial)
                .apply()
        }

        private fun monthStateKey(appWidgetId: Int): String =
            "displayed_month_$appWidgetId"

        private fun findMonthBySerial(snapshot: JSONObject, serial: Int): JSONObject? {
            val months = snapshot.optJSONArray("months") ?: return null
            for (i in 0 until months.length()) {
                val month = months.optJSONObject(i) ?: continue
                if (monthSerial(month.optInt("year"), month.optInt("month")) == serial) {
                    return month
                }
            }
            return null
        }

        private fun monthSerial(year: Int, month: Int): Int = year * 12 + (month - 1)

        private fun currentMonthSerial(): Int {
            val cal = Calendar.getInstance()
            return monthSerial(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1)
        }

        private fun openAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun widgetActionIntent(
            context: Context,
            appWidgetId: Int,
            action: String
        ): PendingIntent {
            val intent = Intent(context, TodayWidgetFourByFourProvider::class.java).apply {
                this.action = action
                putExtra(EXTRA_APP_WIDGET_ID, appWidgetId)
            }
            val actionCode = when (action) {
                ACTION_PREV_MONTH -> 1
                ACTION_NEXT_MONTH -> 2
                ACTION_TODAY_MONTH -> 3
                else -> 0
            }
            return PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + actionCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        // 오늘 날짜 키(YYYY-MM-DD, Dart eventDateKey와 동일 포맷, 로컬 시간대).
        private fun todayKey(): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        private fun fallbackDateLabel(): String =
            SimpleDateFormat("M/d EEEE", Locale.KOREAN).format(Date())

        private fun dateLabelForMode(dateLabel: String, mode: WidgetMode): String =
            if (mode == WidgetMode.Tiny) dateLabel.substringBefore(' ') else dateLabel

        private fun dp(context: Context, value: Int): Int =
            (value * context.resources.displayMetrics.density).toInt()

        private fun widgetMode(minWidth: Int, minHeight: Int): WidgetMode {
            if (minWidth >= 250 && minHeight >= 250) return WidgetMode.Calendar
            if (minWidth >= 110 && minHeight >= 110) return WidgetMode.Compact
            if (minWidth >= 110) return WidgetMode.WideShort
            return WidgetMode.Tiny
        }

        private fun dayNumberColor(weekday: Int, inMonth: Boolean, isToday: Boolean): Int {
            // 오늘은 빨간색 대신 검정(배경 하이라이트로 오늘을 구분).
            if (isToday) return Color.rgb(29, 27, 32)
            if (!inMonth) return Color.rgb(178, 172, 185)
            if (weekday == 7) return Color.rgb(218, 72, 28)
            if (weekday == 6) return Color.rgb(21, 101, 192)
            return Color.rgb(29, 27, 32)
        }

        private fun liturgicalColor(name: String): Int =
            when (name) {
                "red" -> Color.rgb(198, 40, 40)
                "white" -> Color.rgb(93, 87, 107)
                "violet" -> Color.rgb(104, 58, 183)
                "rose" -> Color.rgb(194, 24, 91)
                "black" -> Color.rgb(29, 27, 32)
                else -> Color.rgb(46, 125, 50)
            }

        private enum class WidgetMode {
            Tiny,
            WideShort,
            Compact,
            Calendar
        }
    }
}
