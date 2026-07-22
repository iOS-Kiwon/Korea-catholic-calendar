import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../core/date/year_month.dart';
import '../calendar/data/calendar_service.dart';
import '../calendar/presentation/season_style.dart';
import '../events/model/calendar_event.dart';

class WidgetSnapshotService {
  const WidgetSnapshotService();

  static const _channel = MethodChannel(
    'com.sidore.catholiccalendar/widget_snapshot',
  );

  Future<void> sync({
    required CalendarService calendar,
    required Map<String, List<CalendarEvent>> events,
    DateTime? now,
  }) async {
    if (kIsWeb) return;

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final month = YearMonth.of(today);
    final payload = _buildPayload(
      calendar: calendar,
      events: events,
      today: today,
      month: month,
    );

    try {
      await _channel.invokeMethod<void>('sync', jsonEncode(payload));
    } on MissingPluginException {
      // Desktop/tests do not install the native widget bridge.
    }
  }

  Map<String, dynamic> _buildPayload({
    required CalendarService calendar,
    required Map<String, List<CalendarEvent>> events,
    required DateTime today,
    required YearMonth month,
  }) {
    final todayKey = eventDateKey(today);
    final todayDay = calendar.day(today);
    final todayEvents = [...?events[todayKey]]..sort(_compareEvents);
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7;
    final start = DateTime(month.year, month.month, 1 - leading);
    final visibleDates = [
      for (var i = 0; i < 42; i++)
        DateTime(start.year, start.month, start.day + i),
    ];

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'today': {
        'dateKey': todayKey,
        'dateLabel':
            '${today.month}/${today.day} ${_weekdayLabel(today.weekday)}요일',
        'liturgicalTitle': todayDay.title,
        'liturgicalColor': _colorName(todayDay.color),
        'eventTitle': todayEvents.isEmpty ? '' : todayEvents.first.title,
        'extraEventCount': todayEvents.length > 1 ? todayEvents.length - 1 : 0,
      },
      'month': {
        'title': '${month.year}.${month.month}',
        'year': month.year,
        'month': month.month,
        'days': [
          for (final date in visibleDates)
            _dayPayload(
              calendar: calendar,
              events: events,
              date: date,
              inMonth: date.month == month.month,
              isToday: eventDateKey(date) == todayKey,
            ),
        ],
      },
    };
  }

  Map<String, dynamic> _dayPayload({
    required CalendarService calendar,
    required Map<String, List<CalendarEvent>> events,
    required DateTime date,
    required bool inMonth,
    required bool isToday,
  }) {
    final key = eventDateKey(date);
    final day = calendar.day(date);
    final dayEvents = [...?events[key]]..sort(_compareEvents);
    final notable = inMonth && isNotableDay(day);
    return {
      'dateKey': key,
      'day': date.day,
      'weekday': date.weekday,
      'inMonth': inMonth,
      'isToday': isToday,
      // 달력 격자 셀에 표시되는 텍스트(주요 전례일만).
      'liturgicalTitle': notable ? day.title : '',
      // 위젯이 이 날을 '오늘'로 판정했을 때 작은 위젯에 쓰는 전체 정보.
      // (자정이 지나면 위젯은 baked된 today가 아니라 이 격자에서 오늘을 찾아 그린다.)
      'titleFull': day.title,
      'dateLabel': '${date.month}/${date.day} ${_weekdayLabel(date.weekday)}요일',
      'liturgicalColor': _colorName(day.color),
      'eventTitle': dayEvents.isEmpty ? '' : dayEvents.first.title,
      'extraEventCount': dayEvents.length > 1 ? dayEvents.length - 1 : 0,
    };
  }
}

int _compareEvents(CalendarEvent a, CalendarEvent b) {
  if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
  if (a.isAllDay && b.isAllDay) return 0;
  return a.time!.compareTo(b.time!);
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return '월';
    case DateTime.tuesday:
      return '화';
    case DateTime.wednesday:
      return '수';
    case DateTime.thursday:
      return '목';
    case DateTime.friday:
      return '금';
    case DateTime.saturday:
      return '토';
    default:
      return '일';
  }
}

String _colorName(LiturgicalColor color) {
  switch (color) {
    case LiturgicalColor.green:
      return 'green';
    case LiturgicalColor.red:
      return 'red';
    case LiturgicalColor.white:
      return 'white';
    case LiturgicalColor.violet:
      return 'violet';
    case LiturgicalColor.rose:
      return 'rose';
    case LiturgicalColor.black:
      return 'black';
  }
}
