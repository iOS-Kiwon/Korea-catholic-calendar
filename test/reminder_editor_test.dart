import 'package:catholic_calendar/features/events/model/reminder_lead.dart';
import 'package:catholic_calendar/features/events/presentation/reminder_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, List<ReminderLead> value,
    {required bool allDay, required ValueChanged<List<ReminderLead>> onChanged}) {
  return t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ReminderEditor(reminders: value, allDay: allDay, onChanged: onChanged),
    ),
  ));
}

void main() {
  testWidgets('기본 1개 + 알림 추가로 2개, 최대 2', (t) async {
    var value = const [ReminderLead.day1];
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);
    expect(find.text('알림 1'), findsOneWidget);
    expect(find.text('알림 추가'), findsOneWidget);

    await t.tap(find.text('알림 추가'));
    await _pump(t, value, allDay: false, onChanged: (v) => value = v);
    await t.pump();
    expect(value.length, 2);
  });

  testWidgets('종일이면 선택 시트에 분/시간 리드 없음', (t) async {
    await _pump(t, const [ReminderLead.day1], allDay: true, onChanged: (_) {});
    await t.tap(find.text('알림 1'));
    await t.pumpAndSettle();
    expect(find.text('1주일 전'), findsOneWidget); // 일/주 있음
    expect(find.text('5분 전'), findsNothing); // 분/시간 없음
  });
}
