import 'dart:convert';

import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
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
}
