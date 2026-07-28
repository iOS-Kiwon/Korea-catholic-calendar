import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/reminder_lead.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _base({List<ReminderLead>? reminders}) => CalendarEvent(
  id: 'e1', date: '2026-07-28', categoryId: 'c1', categoryName: '가족',
  reminders: reminders ?? const [ReminderLead.day1],
);

void main() {
  test('reminders 왕복', () {
    final e = _base(reminders: const [ReminderLead.hour1, ReminderLead.day1]);
    final r = CalendarEvent.fromJson(e.toJson());
    expect(r.reminders, const [ReminderLead.hour1, ReminderLead.day1]);
  });
  test('기본값 [day1]', () {
    expect(_base().reminders, const [ReminderLead.day1]);
  });
  test('하위호환: reminders 없으면 [day1]', () {
    final json = {
      'id': 'x', 'date': '2026-07-28', 'categoryId': 'c1',
      'categoryName': '가족', 'type': 'regular', 'notify': true,
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.day1]);
  });
  test('빈 리스트도 [day1]로 보정', () {
    final json = {
      'id': 'x', 'date': '2026-07-28', 'categoryId': 'c1',
      'categoryName': '가족', 'type': 'regular', 'reminders': <String>[],
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.day1]);
  });
  test('copyWith', () {
    expect(_base().copyWith(reminders: const [ReminderLead.week1]).reminders,
        const [ReminderLead.week1]);
  });
}
