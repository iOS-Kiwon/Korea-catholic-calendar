import 'package:catholic_calendar/features/events/model/reminder_lead.dart';
import 'package:catholic_calendar/features/events/presentation/reminder_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester t,
  List<ReminderLead> value, {
  required bool allDay,
  required ValueChanged<List<ReminderLead>> onChanged,
}) {
  return t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReminderEditor(
          reminders: value,
          allDay: allDay,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('기본 1개 + 알림 추가로 2개, 최대 2', (t) async {
    var value = const [ReminderLead.day1];
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);
    expect(find.text('첫 번째 알림'), findsOneWidget);
    expect(find.text('알림 추가'), findsOneWidget);

    await t.tap(find.text('알림 추가'));
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);
    await t.pump();
    expect(value, const [ReminderLead.day1, ReminderLead.day2]);
  });

  testWidgets('알림 추가는 분 단위보다 1일 전을 우선한다', (t) async {
    var value = const [ReminderLead.min10];
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);

    await t.tap(find.text('알림 추가'));
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);
    await t.pump();

    expect(value, const [ReminderLead.min10, ReminderLead.day1]);
  });

  testWidgets('종일이면 선택 시트에 분/시간 리드 없음', (t) async {
    await _pump(t, const [ReminderLead.day1], allDay: true, onChanged: (_) {});
    await t.tap(find.text('첫 번째 알림'));
    await t.pumpAndSettle();
    expect(find.text('1주일 전'), findsOneWidget); // 일/주 있음
    expect(find.text('5분 전'), findsNothing); // 분/시간 없음
  });

  testWidgets('선택 시트의 마지막 알림 시간도 선택된다', (t) async {
    var value = const [ReminderLead.min5];
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);

    await t.tap(find.text('첫 번째 알림'));
    await t.pumpAndSettle();
    await t.tap(find.text('1주일 전'));
    await t.pumpAndSettle();

    expect(value, const [ReminderLead.week1]);
  });

  testWidgets('다른 슬롯이 이미 고른 리드는 선택 시트에서 제외', (t) async {
    await _pump(
      t,
      const [ReminderLead.day1, ReminderLead.week1],
      allDay: true,
      onChanged: (_) {},
    );
    await t.tap(find.text('첫 번째 알림'));
    await t.pumpAndSettle();
    // '1일 전'은 배경 목록(첫 번째 알림)과 시트(현재 값, 체크 표시)에 각각 1번씩 총 2번 보인다.
    expect(find.text('1일 전'), findsNWidgets(2));
    // '1주일 전'은 배경 목록(두 번째 알림)에만 있고, 다른 슬롯이 이미 사용 중이라 시트에서는 빠진다.
    expect(find.text('1주일 전'), findsOneWidget);
  });
}
