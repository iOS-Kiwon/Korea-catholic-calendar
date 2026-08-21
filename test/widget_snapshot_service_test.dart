import 'dart:convert';

import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/data/korean_holidays.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/widgets/widget_snapshot_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.sidore.catholiccalendar/widget_snapshot');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('widget snapshot separates regular event category and memo', () async {
    String? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'sync');
          payload = call.arguments as String;
          return null;
        });

    await const WidgetSnapshotService().sync(
      calendar: CalendarService(engine: LiturgicalCalendar()),
      now: DateTime(2026, 7, 16, 9),
      events: {
        '2026-07-16': [
          const CalendarEvent(
            id: 'e1',
            date: '2026-07-16',
            categoryId: 'c1',
            categoryName: '본당 행사',
            categoryColor: 0xFF2E7D32,
            memo: '바자회',
            time: '19:30',
          ),
        ],
      },
    );

    final json = jsonDecode(payload!) as Map<String, dynamic>;
    final today = json['today'] as Map<String, dynamic>;

    expect(today['regularEventDisplayText'], '본당 행사 바자회');
    expect(today['regularEventDisplayText'], isNot(contains('*')));
    expect(today['regularEventCategoryName'], '본당 행사');
    expect(today['regularEventMemo'], '바자회');
    expect(today['regularEventColor'], 0xFF2E7D32);
  });

  test('widget snapshot uses shared liturgical short titles', () async {
    String? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          payload = call.arguments as String;
          return null;
        });

    await const WidgetSnapshotService().sync(
      calendar: CalendarService(engine: LiturgicalCalendar()),
      now: DateTime(2026, 4, 5, 9),
      events: const {},
    );

    final json = jsonDecode(payload!) as Map<String, dynamic>;
    final today = json['today'] as Map<String, dynamic>;

    expect(today['liturgicalTitle'], '부활절');
  });

  test('공휴일·대체공휴일을 위젯이 빨간색으로 그릴 수 있게 표시한다', () async {
    // 2026-08-15 광복절, 2026-08-17 대체공휴일(광복절이 토요일이라 월요일로 이월).
    // 위젯(Android `dayNumberColor`, iOS `MonthDayCell.numberColor`)이 이 플래그로
    // 날짜 숫자를 주일과 같은 빨간색으로 그린다.
    String? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          payload = call.arguments as String;
          return null;
        });

    final holidays = parseKoreanHolidays(
      jsonEncode({
        'holidays': {
          '2026-08-15': [
            {'id': 'liberation', 'title': '광복절', 'isSubstitute': false},
          ],
          '2026-08-17': [
            {'id': 'liberation_sub', 'title': '대체공휴일', 'isSubstitute': true},
          ],
        },
      }),
    );

    await const WidgetSnapshotService().sync(
      calendar: CalendarService(
        engine: LiturgicalCalendar(),
        koreanHolidays: holidays,
      ),
      now: DateTime(2026, 8, 15, 9),
      events: const {},
    );

    final json = jsonDecode(payload!) as Map<String, dynamic>;

    // 오늘(광복절)도 표시된다 - 작은 위젯이 today를 폴백으로 쓴다.
    expect((json['today'] as Map<String, dynamic>)['isHoliday'], isTrue);

    Map<String, dynamic> dayOf(String dateKey) {
      for (final raw in json['months'] as List<dynamic>) {
        for (final d in (raw as Map<String, dynamic>)['days'] as List<dynamic>) {
          final day = d as Map<String, dynamic>;
          if (day['dateKey'] == dateKey && day['inMonth'] == true) return day;
        }
      }
      fail('$dateKey 가 months 안에 없다');
    }

    expect(dayOf('2026-08-15')['isHoliday'], isTrue, reason: '광복절');
    expect(dayOf('2026-08-17')['isHoliday'], isTrue, reason: '대체공휴일');
    expect(dayOf('2026-08-18')['isHoliday'], isFalse, reason: '평일');
    // 주일은 위젯이 weekday로 이미 빨간색을 낸다 - 공휴일 플래그와 무관하다.
    expect(dayOf('2026-08-16')['isHoliday'], isFalse);
    expect(dayOf('2026-08-16')['weekday'], DateTime.sunday);
  });

  test('4x4 위젯이 월 이동으로 볼 수 있는 달에도 일정·축일 데이터가 들어 있다', () async {
    // 4x4 위젯의 이전/다음 달 버튼은 Flutter를 호출할 수 없다(RemoteViews).
    // `TodayWidgetProvider.findMonthBySerial`이 스냅샷의 `months`(±12개월)에서
    // 해당 달을 찾아 그리므로, 각 달의 42칸에 그날의 일정/축일이 미리 구워져 있어야
    // 월을 옮겨도 앱과 같은 내용이 보인다.
    String? payload;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          payload = call.arguments as String;
          return null;
        });

    await const WidgetSnapshotService().sync(
      calendar: CalendarService(engine: LiturgicalCalendar()),
      now: DateTime(2026, 8, 19, 9),
      events: {
        // 스냅샷 기준월(2026-08)이 아니라 3개월 뒤 + 3개월 전에 둔다.
        '2026-11-05': [
          const CalendarEvent(
            id: 'e1',
            date: '2026-11-05',
            categoryId: 'c1',
            categoryName: '본당 행사',
            categoryColor: 0xFF2E7D32,
            memo: '바자회',
            time: '19:30',
          ),
        ],
        '2026-05-05': [
          const CalendarEvent(
            id: 'e2',
            date: '2026-05-05',
            categoryId: 'c1',
            categoryName: '본당 행사',
            categoryColor: 0xFF1565C0,
            memo: '어린이 미사',
          ),
        ],
      },
    );

    final json = jsonDecode(payload!) as Map<String, dynamic>;
    final months = json['months'] as List<dynamic>;
    // ±12개월 = 25개월이 구워진다.
    expect(months.length, 25);

    Map<String, dynamic> dayOf(String dateKey) {
      for (final raw in months) {
        final month = raw as Map<String, dynamic>;
        for (final d in month['days'] as List<dynamic>) {
          final day = d as Map<String, dynamic>;
          if (day['dateKey'] == dateKey && day['inMonth'] == true) return day;
        }
      }
      fail('$dateKey 가 months 안에 없다');
    }

    final future = dayOf('2026-11-05');
    expect(future['regularEventDisplayText'], '본당 행사 바자회');
    expect(future['eventColor'], 0xFF2E7D32);
    expect((future['eventItems'] as List<dynamic>), hasLength(1));

    final past = dayOf('2026-05-05');
    expect(past['regularEventDisplayText'], '본당 행사 어린이 미사');
    expect(past['eventColor'], 0xFF1565C0);

    // 범위 경계: ±12개월은 들어 있고 ±13개월은 없다. 위젯이 그 밖으로 이동하면
    // `findMonthBySerial`이 null을 돌려주고 스냅샷 기준월로 폴백한다.
    int serialOf(Map<String, dynamic> m) =>
        (m['year'] as int) * 12 + (m['month'] as int) - 1;
    final serials = months.map((m) => serialOf(m as Map<String, dynamic>));
    const baseSerial = 2026 * 12 + 8 - 1;
    expect(serials.reduce((a, b) => a < b ? a : b), baseSerial - 12);
    expect(serials.reduce((a, b) => a > b ? a : b), baseSerial + 12);
  });
}
