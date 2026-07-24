import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../core/date/year_month.dart';
import '../calendar/data/calendar_service.dart';
import '../calendar/presentation/season_style.dart';
import '../events/application/recurrence_expander.dart';
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
    // 반복 규칙을 각 날짜에 전개(정확 날짜키 조회 대신).
    final expander = RecurrenceExpander(calendar);
    final todayKey = eventDateKey(today);
    final todayDay = calendar.day(today);
    final todayEvents = expander.eventsOn(events, today)..sort(_compareEvents);
    final todayEvent = todayEvents.isEmpty ? null : todayEvents.first;
    final todayRegularEvent = _firstRegularEvent(todayEvents);
    final todaySaintFeast = _firstSaintFeast(todayEvents);
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7;
    final start = DateTime(month.year, month.month, 1 - leading);
    final visibleDates = [
      for (var i = 0; i < 42; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final months = [
      for (var offset = -12; offset <= 12; offset++)
        _monthPayload(
          calendar: calendar,
          expander: expander,
          events: events,
          month: YearMonth.fromSerial(month.serial + offset),
          todayKey: todayKey,
        ),
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
        'eventDisplayText': todayEvent == null
            ? ''
            : _eventDisplayText(todayEvent),
        'regularEventDisplayText': todayRegularEvent == null
            ? ''
            : _regularEventDisplayText(todayRegularEvent),
        'saintFeastDisplayText': todaySaintFeast == null
            ? ''
            : _saintFeastDisplayText(todaySaintFeast),
        'eventColor': todayEvent?.categoryColor,
        'eventItems': _eventItems(todayEvents),
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
              expander: expander,
              events: events,
              date: date,
              inMonth: date.month == month.month,
              isToday: eventDateKey(date) == todayKey,
            ),
        ],
      },
      'months': months,
    };
  }

  Map<String, dynamic> _monthPayload({
    required CalendarService calendar,
    required RecurrenceExpander expander,
    required Map<String, List<CalendarEvent>> events,
    required YearMonth month,
    required String todayKey,
  }) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7;
    final start = DateTime(month.year, month.month, 1 - leading);
    return {
      'title': '${month.year}.${month.month}',
      'year': month.year,
      'month': month.month,
      'days': [
        for (var i = 0; i < 42; i++)
          _dayPayload(
            calendar: calendar,
            expander: expander,
            events: events,
            date: DateTime(start.year, start.month, start.day + i),
            inMonth:
                DateTime(start.year, start.month, start.day + i).month ==
                month.month,
            isToday:
                eventDateKey(
                  DateTime(start.year, start.month, start.day + i),
                ) ==
                todayKey,
          ),
      ],
    };
  }

  Map<String, dynamic> _dayPayload({
    required CalendarService calendar,
    required RecurrenceExpander expander,
    required Map<String, List<CalendarEvent>> events,
    required DateTime date,
    required bool inMonth,
    required bool isToday,
  }) {
    final key = eventDateKey(date);
    final day = calendar.day(date);
    final dayEvents = expander.eventsOn(events, date)..sort(_compareEvents);
    final firstEvent = dayEvents.isEmpty ? null : dayEvents.first;
    final regularEvent = _firstRegularEvent(dayEvents);
    final saintFeast = _firstSaintFeast(dayEvents);
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
      'eventDisplayText': firstEvent == null
          ? ''
          : _eventDisplayText(firstEvent),
      'regularEventDisplayText': regularEvent == null
          ? ''
          : _regularEventDisplayText(regularEvent),
      'saintFeastDisplayText': saintFeast == null
          ? ''
          : _saintFeastDisplayText(saintFeast),
      'eventColor': firstEvent?.categoryColor,
      'eventItems': _eventItems(dayEvents),
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

String _eventDisplayText(CalendarEvent event) {
  final memo = event.memo?.trim();
  if (memo != null && memo.isNotEmpty) return memo;
  return event.title;
}

CalendarEvent? _firstRegularEvent(List<CalendarEvent> events) {
  for (final event in events) {
    if (!event.isSaintFeast) return event;
  }
  return null;
}

CalendarEvent? _firstSaintFeast(List<CalendarEvent> events) {
  for (final event in events) {
    if (event.isSaintFeast) return event;
  }
  return null;
}

String _regularEventDisplayText(CalendarEvent event) {
  final memo = event.memo?.trim();
  if (memo != null && memo.isNotEmpty) {
    return '${event.categoryName} * $memo';
  }
  return event.categoryName;
}

String _saintFeastDisplayText(CalendarEvent event) {
  return event.saintFeastDisplayText;
}

List<Map<String, dynamic>> _eventItems(List<CalendarEvent> events) => [
  for (final event in events.take(3))
    {'title': _eventDisplayText(event), 'color': event.categoryColor},
];
