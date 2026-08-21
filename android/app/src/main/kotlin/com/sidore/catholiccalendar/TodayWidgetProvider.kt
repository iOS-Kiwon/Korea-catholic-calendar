package com.sidore.catholiccalendar

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
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
import kotlin.math.ceil
import kotlin.math.min

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

        // 세 크기 provider의 모든 위젯을 다시 그린다. 남은 위젯이 없으면 알람을 취소.
        //
        // 자정/부팅 경로뿐 아니라 `MainActivity.syncWidgetSnapshot`(앱에서 일정·축일이
        // 바뀐 직후)에서도 이 함수를 쓴다. 예전에는 MainActivity가 provider 목록을
        // 따로 하드코딩해서, 나중에 추가된 4x1 주간 위젯이 즉시 갱신 대상에서 빠져
        // 다음 자정까지 예전 내용을 보여줬다. 목록은 여기 한 곳에만 둔다.
        fun refreshAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val components = listOf(
                ComponentName(context, TodayWidgetTwoByTwoProvider::class.java),
                ComponentName(context, TodayWidgetFourByFourProvider::class.java),
                ComponentName(context, TodayWidgetFourByOneProvider::class.java)
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
            // 1x4는 크기로 구분되지 않는다(minWidth>=110, minHeight<110이라 2x2를
            // 가로로 늘린 것과 같은 조건 = WideShort). 프로바이더 클래스로 판정한다.
            val providerName =
                appWidgetManager.getAppWidgetInfo(appWidgetId)?.provider?.className
            val mode = if (providerName == TodayWidgetFourByOneProvider::class.java.name) {
                WidgetMode.Week
            } else {
                widgetMode(minWidth, minHeight)
            }

            val views = when (mode) {
                WidgetMode.Tiny -> buildSmallViews(context, snapshot, mode, todayKey)
                WidgetMode.WideShort -> buildSmallViews(context, snapshot, mode, todayKey)
                WidgetMode.Compact -> buildSmallViews(context, snapshot, mode, todayKey)
                WidgetMode.Week -> buildWeekViews(context, snapshot, todayKey)
                WidgetMode.Calendar -> buildLargeViews(context, snapshot, todayKey, appWidgetId)
            }

            // 위젯 배경(날짜 칸·버튼이 아닌 곳) 탭. 데이터 없는 '앱 열기' 대신 보고 있는
            // 화면에 맞는 딥링크를 실어 보낸다. 4x4는 보고 있는 달, 나머지는 오늘.
            //
            // 데이터를 싣는 것이 중요한 이유가 하나 더 있다. 예전에는 이 인텐트에 data가
            // 없어서, 어떤 이유로든 날짜 칸의 클릭 대신 이 배경 클릭이 발동하면 앱이
            // 그냥 기본 화면으로 열려 원인을 구분할 수 없었다. 이제는 4x4에서 날짜를
            // 눌렀는데 '선택 없는 그 달'이 열리면 배경 클릭이 먹은 것이고, 엉뚱한 달이
            // 열리면 링크 전달 문제다.
            views.setOnClickPendingIntent(
                R.id.today_widget_root,
                when (mode) {
                    WidgetMode.Calendar -> monthOpenIntent(
                        context,
                        displayedMonthSerial(context, appWidgetId)
                    )
                    else -> dayOpenIntent(context, todayKey) ?: openAppIntent(context)
                }
            )
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
            val regularEventCategoryName: String
            val regularEventMemo: String
            val regularEventColor: Int
            val saintFeastDisplayText: String
            if (dayCell != null) {
                dateLabel = dayCell.optString("dateLabel").ifBlank { fallbackDateLabel() }
                liturgyTitle = dayCell.optString("titleFull").ifBlank { "오늘의 전례" }
                liturgyColor = dayCell.optString("liturgicalColor")
                regularEventDisplayText = dayCell.optString("regularEventDisplayText")
                regularEventCategoryName = regularEventCategoryLabel(dayCell, regularEventDisplayText)
                regularEventMemo = regularEventMemoText(dayCell, regularEventDisplayText, regularEventCategoryName)
                regularEventColor = regularEventLabelColor(dayCell)
                saintFeastDisplayText = dayCell.optString("saintFeastDisplayText")
                return buildSmallViewsWithText(
                    context,
                    mode,
                    dateLabel,
                    liturgyTitle,
                    liturgyColor,
                    regularEventDisplayText,
                    regularEventCategoryName,
                    regularEventMemo,
                    regularEventColor,
                    saintFeastDisplayText
                )
            } else {
                val today = snapshot.optJSONObject("today") ?: JSONObject()
                dateLabel = today.optString("dateLabel", fallbackDateLabel())
                liturgyTitle = today.optString("liturgicalTitle", "오늘의 전례")
                liturgyColor = today.optString("liturgicalColor")
                regularEventDisplayText = today.optString("regularEventDisplayText")
                regularEventCategoryName = regularEventCategoryLabel(today, regularEventDisplayText)
                regularEventMemo = regularEventMemoText(today, regularEventDisplayText, regularEventCategoryName)
                regularEventColor = regularEventLabelColor(today)
                saintFeastDisplayText = today.optString("saintFeastDisplayText")
                return buildSmallViewsWithText(
                    context,
                    mode,
                    dateLabel,
                    liturgyTitle,
                    liturgyColor,
                    regularEventDisplayText,
                    regularEventCategoryName,
                    regularEventMemo,
                    regularEventColor,
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
            regularEventCategoryName: String,
            regularEventMemo: String,
            regularEventColor: Int,
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
            val regularText = regularEventCategoryName.ifBlank { regularEventDisplayText }
            if (regularText.isBlank() || mode == WidgetMode.Tiny) {
                views.setViewVisibility(R.id.today_widget_event, View.GONE)
            } else {
                views.setViewVisibility(R.id.today_widget_event, View.VISIBLE)
                views.setImageViewBitmap(
                    R.id.today_widget_event_category,
                    categoryLabelBitmap(
                        context,
                        regularText,
                        regularEventColor,
                        eventTextSizeSp(mode)
                    )
                )
                views.setTextViewText(R.id.today_widget_event_memo, regularEventMemo)
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
                        R.id.today_widget_liturgy,
                        0,
                        0,
                        0,
                        0
                    )
                    views.setViewPadding(
                        R.id.today_widget_root,
                        dp(context, 10),
                        dp(context, 4),
                        dp(context, 10),
                        dp(context, 4)
                    )
                }
                WidgetMode.WideShort -> {
                    views.setTextViewTextSize(R.id.today_widget_date, TypedValue.COMPLEX_UNIT_SP, 19f)
                    views.setTextViewTextSize(R.id.today_widget_liturgy, TypedValue.COMPLEX_UNIT_SP, 13f)
                    views.setTextViewTextSize(R.id.today_widget_event_memo, TypedValue.COMPLEX_UNIT_SP, 13f)
                    views.setViewPadding(
                        R.id.today_widget_liturgy,
                        0,
                        0,
                        0,
                        0
                    )
                    views.setViewPadding(
                        R.id.today_widget_root,
                        dp(context, 10),
                        dp(context, 5),
                        dp(context, 10),
                        dp(context, 5)
                    )
                }
                WidgetMode.Compact -> {
                    views.setTextViewTextSize(R.id.today_widget_date, TypedValue.COMPLEX_UNIT_SP, 24f)
                    views.setTextViewTextSize(R.id.today_widget_liturgy, TypedValue.COMPLEX_UNIT_SP, 15f)
                    views.setTextViewTextSize(R.id.today_widget_event_memo, TypedValue.COMPLEX_UNIT_SP, 14f)
                    views.setTextViewTextSize(R.id.today_widget_feast, TypedValue.COMPLEX_UNIT_SP, 14f)
                    views.setViewPadding(
                        R.id.today_widget_liturgy,
                        dp(context, 2),
                        0,
                        0,
                        0
                    )
                    views.setViewPadding(
                        R.id.today_widget_root,
                        dp(context, 10),
                        dp(context, 18),
                        dp(context, 10),
                        dp(context, 6)
                    )
                }
                // 둘 다 small 레이아웃을 쓰지 않으므로 조정할 것이 없다.
                WidgetMode.Week, WidgetMode.Calendar -> Unit
            }
        }

        private fun buildLargeViews(
            context: Context,
            snapshot: JSONObject,
            todayKey: String,
            appWidgetId: Int
        ): RemoteViews {
            val targetSerial = displayedMonthSerial(context, appWidgetId)
            val month = findMonthBySerial(snapshot, targetSerial)
            val views = RemoteViews(context.packageName, R.layout.today_widget_large)
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

            // 스냅샷에 없는 달이면 격자 대신 안내를 보여준다. 헤더는 그대로 두므로
            // 반대 화살표나 `오늘`로 달력에 돌아올 수 있다.
            if (month == null) {
                views.setTextViewText(
                    R.id.today_widget_month_title,
                    monthTitleOf(targetSerial)
                )
                views.setViewVisibility(R.id.today_widget_weekday_row, View.GONE)
                views.setViewVisibility(R.id.today_widget_month_rows, View.GONE)
                views.setViewVisibility(R.id.today_widget_out_of_range, View.VISIBLE)
                val range = monthSerialRange(snapshot)
                views.setTextViewText(
                    R.id.today_widget_out_of_range_message,
                    when {
                        // 앱을 한 번도 실행하지 않아 스냅샷이 없는 상태.
                        range == null -> "앱을 한 번 실행하면\n달력이 표시됩니다."
                        targetSerial > range.last -> "이후 일정은\n앱에서 확인하세요."
                        else -> "이전 일정은\n앱에서 확인하세요."
                    }
                )
                // 위젯은 이 달을 그릴 수 없지만 앱은 그릴 수 있다. 그 달로 바로 보낸다.
                views.setOnClickPendingIntent(
                    R.id.today_widget_out_of_range_action,
                    monthOpenIntent(context, targetSerial)
                )
                return views
            }

            val days = month.optJSONArray("days") ?: JSONArray()
            views.setTextViewText(R.id.today_widget_month_title, month.optString("title", ""))
            views.setViewVisibility(R.id.today_widget_weekday_row, View.VISIBLE)
            views.setViewVisibility(R.id.today_widget_month_rows, View.VISIBLE)
            views.setViewVisibility(R.id.today_widget_out_of_range, View.GONE)
            views.removeAllViews(R.id.today_widget_month_rows)
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

        private fun buildWeekViews(
            context: Context,
            snapshot: JSONObject,
            todayKey: String
        ): RemoteViews {
            val month = snapshot.optJSONObject("month") ?: JSONObject()
            val views = RemoteViews(context.packageName, R.layout.today_widget_week)
            views.setTextViewText(R.id.today_widget_month_title, month.optString("title", ""))
            views.removeAllViews(R.id.today_widget_week_row)
            val row = RemoteViews(context.packageName, R.layout.today_widget_month_row)
            for (day in findWeekDays(snapshot, todayKey)) {
                row.addView(
                    R.id.today_widget_month_row,
                    buildDayCell(context, day, todayKey, forceInMonth = true)
                )
            }
            views.addView(R.id.today_widget_week_row, row)
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
            val current = displayedMonthSerial(context, appWidgetId)
            // 스냅샷 범위 밖으로는 딱 한 칸까지만 나가게 한다. 그 한 칸이 안내
            // 화면이고, 반대 화살표 한 번으로 달력에 돌아온다. clamp가 없으면
            // serial이 무한히 커져서, 되돌아오려면 나간 횟수만큼 눌러야 했다.
            val range = monthSerialRange(snapshot)
            val next = when (action) {
                ACTION_PREV_MONTH -> current - 1
                ACTION_NEXT_MONTH -> current + 1
                else -> currentMonthSerial()
            }.let { if (range == null) it else it.coerceIn(range.first - 1, range.last + 1) }
            if (action == ACTION_TODAY_MONTH) {
                clearDisplayedMonthSerial(context, appWidgetId)
            } else {
                saveDisplayedMonthSerial(context, appWidgetId, next)
            }
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
            todayKey: String,
            forceInMonth: Boolean = false
        ): RemoteViews {
            val cell = RemoteViews(context.packageName, R.layout.today_widget_day_cell)
            // 주간 위젯은 7일 모두 '이번 주'라 다음/이전 달 날짜도 진하게 그린다.
            val inMonth = forceInMonth || day.optBoolean("inMonth")
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

        /// 오늘이 속한 주(일~토)의 7칸을 돌려준다. 찾지 못하면 빈 칸 7개.
        ///
        /// snapshot.month(앱이 스냅샷을 저장한 시점의 달)가 아니라 오늘 날짜로
        /// 달을 계산해 months(±12개월)에서 찾는다. 그래야 앱을 열지 않은 채 달이
        /// 바뀌어도 올바른 주를 그린다.
        private fun findWeekDays(snapshot: JSONObject, todayKey: String): List<JSONObject> {
            val days = monthGridForDate(snapshot, todayKey)
                ?: snapshot.optJSONObject("month")?.optJSONArray("days")
                ?: return List(7) { JSONObject() }

            var index = -1
            for (i in 0 until days.length()) {
                if (days.optJSONObject(i)?.optString("dateKey") == todayKey) {
                    index = i
                    break
                }
            }
            if (index < 0) return List(7) { JSONObject() }

            val rowStart = (index / 7) * 7
            return (0 until 7).map { col ->
                val raw = days.optJSONObject(rowStart + col) ?: JSONObject()
                resolveWeekDayCell(snapshot, raw)
            }
        }

        /// dateKey("yyyy-MM-dd")가 속한 달의 42칸 격자. months에서 찾는다.
        private fun monthGridForDate(snapshot: JSONObject, dateKey: String): JSONArray? {
            if (dateKey.length < 7) return null
            val year = dateKey.substring(0, 4).toIntOrNull() ?: return null
            val month = dateKey.substring(5, 7).toIntOrNull() ?: return null
            return findMonthBySerial(snapshot, monthSerial(year, month))
                ?.optJSONArray("days")
        }

        /// 달 경계 주 보정.
        ///
        /// 주가 두 달에 걸치면 다음(이전) 달 날짜가 inMonth=false로 들어온다.
        /// 그런 칸은 Dart 쪽에서 liturgicalTitle을 비워 보내고(notable = inMonth &&
        /// isNotableDay) 날짜도 회색으로 그려진다. 그 날이 속한 달의 격자에서 같은
        /// 날을 다시 찾아 온전한 칸으로 바꾼다.
        private fun resolveWeekDayCell(
            snapshot: JSONObject,
            fallback: JSONObject
        ): JSONObject {
            if (fallback.optBoolean("inMonth")) return fallback
            val dateKey = fallback.optString("dateKey")
            val days = monthGridForDate(snapshot, dateKey) ?: return fallback
            for (i in 0 until days.length()) {
                val day = days.optJSONObject(i) ?: continue
                if (day.optString("dateKey") == dateKey && day.optBoolean("inMonth")) {
                    return day
                }
            }
            return fallback
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

        /// 이 위젯이 보여줄 달. 사용자가 이전/다음으로 옮겨둔 값이 있으면 그것,
        /// 없으면 **기기 시계의 현재 달**.
        ///
        /// 예전에는 기본값으로 snapshot.month(앱이 스냅샷을 저장한 시점의 달)를 썼다.
        /// 스냅샷은 Flutter 없이 재생성할 수 없어 자정 갱신으로도 바뀌지 않으므로,
        /// 앱을 한 달 넘게 열지 않으면 지난달이 그대로 남았고 `오늘` 버튼을 눌러도
        /// (저장값을 지워 기본값으로 돌아가므로) 지난달로 갔다.
        /// months에는 ±12개월이 구워져 있어 현재 달은 보통 그 안에 있고, 없으면
        /// buildLargeViews의 findMonthBySerial이 snapshot.month로 폴백한다.
        private fun displayedMonthSerial(context: Context, appWidgetId: Int): Int {
            val prefs = context.getSharedPreferences(PREF_WIDGET_STATE, Context.MODE_PRIVATE)
            val saved = prefs.getInt(monthStateKey(appWidgetId), Int.MIN_VALUE)
            if (saved != Int.MIN_VALUE) return saved
            return currentMonthSerial()
        }

        private fun saveDisplayedMonthSerial(context: Context, appWidgetId: Int, serial: Int) {
            context.getSharedPreferences(PREF_WIDGET_STATE, Context.MODE_PRIVATE)
                .edit()
                .putInt(monthStateKey(appWidgetId), serial)
                .apply()
        }

        private fun clearDisplayedMonthSerial(context: Context, appWidgetId: Int) {
            context.getSharedPreferences(PREF_WIDGET_STATE, Context.MODE_PRIVATE)
                .edit()
                .remove(monthStateKey(appWidgetId))
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
        /// 스냅샷에 구워진 달들의 serial 범위. 스냅샷이 없으면 null.
        private fun monthSerialRange(snapshot: JSONObject): IntRange? {
            val months = snapshot.optJSONArray("months") ?: return null
            if (months.length() == 0) return null
            var min = Int.MAX_VALUE
            var max = Int.MIN_VALUE
            for (i in 0 until months.length()) {
                val month = months.optJSONObject(i) ?: continue
                val serial = monthSerial(month.optInt("year"), month.optInt("month"))
                if (serial < min) min = serial
                if (serial > max) max = serial
            }
            return if (min > max) null else min..max
        }

        /// serial → "2027.9" (스냅샷에 그 달이 없어 title을 못 읽을 때 쓴다).
        private fun monthTitleOf(serial: Int): String =
            "${serial / 12}.${serial % 12 + 1}"

                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun widgetActionIntent(
        /// 앱을 특정 화면으로 여는 PendingIntent.
        ///
        /// **암시적** VIEW 인텐트를 쓴다. app_links(Flutter)가 인텐트의 data URI를
        /// 읽어 `resolveWidgetLink`로 넘기는 경로가 공유 링크에서 이미 검증돼 있고,
        /// 콜드/웜 스타트를 둘 다 처리해 준다(MainActivity는 launchMode=singleTop).
        ///
        /// **data URI가 칸마다 달라야 한다.** PendingIntent는 extras를 무시하고
        /// action/data/component로 동일성을 판정하므로, 42칸이 같은 URI를 쓰면 하나로
        /// 합쳐져 모든 칸이 같은 날짜를 연다. requestCode도 함께 다르게 준다.
        private fun appLinkIntent(
            context: Context,
            uri: String,
            requestCode: Int
        ): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
                setPackage(context.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        /// 날짜 칸 탭 → 그 날짜가 선택된 앱 메인 화면.
        /// requestCode는 yyyyMMdd(예: 20260815)로 칸마다 다르다.
        private fun dayOpenIntent(context: Context, dateKey: String): PendingIntent? {
            val digits = dateKey.replace("-", "").toIntOrNull() ?: return null
            return appLinkIntent(context, "catholiccalendar://day/$dateKey", digits)
        }

        /// 범위 밖 안내의 [앱으로 이동하기] → 그 달의 앱 메인 화면.
        /// requestCode는 day 쪽(8자리)과 겹치지 않게 음수로 둔다.
        private fun monthOpenIntent(context: Context, serial: Int): PendingIntent {
            val year = serial / 12
            val month = serial % 12 + 1
            val key = "$year-${month.toString().padStart(2, '0')}"
            return appLinkIntent(context, "catholiccalendar://month/$key", -serial)
        }

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

        private fun regularEventCategoryLabel(source: JSONObject, displayText: String): String {
            val category = source.optString("regularEventCategoryName")
            if (category.isNotBlank()) return category
            return displayText.substringBefore(" * ").ifBlank {
                displayText.substringBefore(' ')
            }
        }

        private fun regularEventMemoText(
            source: JSONObject,
            displayText: String,
            category: String
        ): String {
            val memo = source.optString("regularEventMemo")
            if (memo.isNotBlank()) return memo
            if (displayText.contains(" * ")) return displayText.substringAfter(" * ")
            return displayText.removePrefix(category).trim()
        }

        private fun regularEventLabelColor(source: JSONObject): Int =
            source.optInt(
                "regularEventColor",
                source.optInt("eventColor", Color.rgb(46, 125, 50))
            )

        private fun eventTextSizeSp(mode: WidgetMode): Float =
            when (mode) {
                WidgetMode.Compact -> 14f
                WidgetMode.WideShort -> 13f
                else -> 12f
            }

        private fun categoryLabelBitmap(
            context: Context,
            text: String,
            color: Int,
            textSizeSp: Float
        ): Bitmap {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = Color.rgb(29, 27, 32)
                textSize = TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_SP,
                    textSizeSp,
                    context.resources.displayMetrics
                )
                typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
            }
            val horizontalPadding = dp(context, 4)
            val verticalPadding = dp(context, 1)
            val maxWidth = dp(context, 96)
            val maxTextWidth = maxWidth - horizontalPadding * 2
            val label = ellipsize(text, paint, maxTextWidth.toFloat())
            val fontMetrics = paint.fontMetrics
            val width = min(
                maxWidth,
                ceil(paint.measureText(label) + horizontalPadding * 2).toInt()
            ).coerceAtLeast(1)
            val height = ceil(
                (fontMetrics.descent - fontMetrics.ascent) + verticalPadding * 2
            ).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val background = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = Color.argb(
                    (255 * 0.24f).toInt(),
                    Color.red(color),
                    Color.green(color),
                    Color.blue(color)
                )
            }
            val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
            canvas.drawRoundRect(rect, dp(context, 3).toFloat(), dp(context, 3).toFloat(), background)
            val baseline = verticalPadding - fontMetrics.ascent
            canvas.drawText(label, horizontalPadding.toFloat(), baseline, paint)
            return bitmap
        }

        private fun ellipsize(text: String, paint: Paint, maxWidth: Float): String {
            if (paint.measureText(text) <= maxWidth) return text
            val ellipsis = "…"
            var result = text
            while (result.isNotEmpty() && paint.measureText(result + ellipsis) > maxWidth) {
                result = result.dropLast(1)
            }
            return result + ellipsis
        }

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
            Week,
            Calendar
        }
    }
}
