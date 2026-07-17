package com.sidore.catholiccalendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TodayWidgetProvider : AppWidgetProvider() {
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

    companion object {
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
        }

        private fun buildViews(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ): RemoteViews {
            val snapshot = readSnapshot(context)
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            val large = minWidth >= 250 && minHeight >= 250

            val views = if (large) {
                buildLargeViews(context, snapshot)
            } else {
                buildSmallViews(context, snapshot)
            }

            views.setOnClickPendingIntent(R.id.today_widget_root, openAppIntent(context))
            return views
        }

        private fun buildSmallViews(context: Context, snapshot: JSONObject): RemoteViews {
            val today = snapshot.optJSONObject("today") ?: JSONObject()
            val views = RemoteViews(context.packageName, R.layout.today_widget_small)
            val eventTitle = today.optString("eventTitle")
            val extraCount = today.optInt("extraEventCount")

            views.setTextViewText(
                R.id.today_widget_date,
                today.optString("dateLabel", fallbackDateLabel())
            )
            views.setTextViewText(
                R.id.today_widget_liturgy,
                today.optString("liturgicalTitle", "오늘의 전례")
            )
            views.setTextColor(
                R.id.today_widget_liturgy,
                liturgicalColor(today.optString("liturgicalColor"))
            )
            if (eventTitle.isBlank()) {
                views.setViewVisibility(R.id.today_widget_event, View.GONE)
            } else {
                views.setViewVisibility(R.id.today_widget_event, View.VISIBLE)
                views.setTextViewText(
                    R.id.today_widget_event,
                    if (extraCount > 0) "$eventTitle 외 ${extraCount}개" else eventTitle
                )
            }
            return views
        }

        private fun buildLargeViews(context: Context, snapshot: JSONObject): RemoteViews {
            val month = snapshot.optJSONObject("month") ?: JSONObject()
            val days = month.optJSONArray("days") ?: JSONArray()
            val views = RemoteViews(context.packageName, R.layout.today_widget_large)
            views.setTextViewText(R.id.today_widget_month_title, month.optString("title", ""))
            views.removeAllViews(R.id.today_widget_month_rows)

            for (rowIndex in 0 until 6) {
                val row = RemoteViews(context.packageName, R.layout.today_widget_month_row)
                for (colIndex in 0 until 7) {
                    val day = days.optJSONObject(rowIndex * 7 + colIndex) ?: JSONObject()
                    row.addView(R.id.today_widget_month_row, buildDayCell(context, day))
                }
                views.addView(R.id.today_widget_month_rows, row)
            }
            return views
        }

        private fun buildDayCell(context: Context, day: JSONObject): RemoteViews {
            val cell = RemoteViews(context.packageName, R.layout.today_widget_day_cell)
            val inMonth = day.optBoolean("inMonth")
            val isToday = day.optBoolean("isToday")
            val eventTitle = day.optString("eventTitle")
            val liturgyTitle = day.optString("liturgicalTitle")
            val extraCount = day.optInt("extraEventCount")

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
                eventTitle.isNotBlank() && extraCount > 0 -> "$eventTitle +$extraCount"
                eventTitle.isNotBlank() -> eventTitle
                else -> liturgyTitle
            }
            cell.setTextViewText(R.id.today_widget_day_title, primaryText)
            cell.setTextColor(
                R.id.today_widget_day_title,
                if (eventTitle.isNotBlank()) Color.rgb(29, 27, 32)
                else liturgicalColor(day.optString("liturgicalColor"))
            )
            return cell
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

        private fun fallbackDateLabel(): String =
            SimpleDateFormat("M/d EEEE", Locale.KOREAN).format(Date())

        private fun dayNumberColor(weekday: Int, inMonth: Boolean, isToday: Boolean): Int {
            if (isToday) return Color.rgb(218, 72, 28)
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
    }
}
