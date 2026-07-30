import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/reminder_lead.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _base({List<ReminderLead>? reminders, String? time}) =>
    CalendarEvent(
      id: 'e1',
      date: '2026-07-28',
      categoryId: 'c1',
      categoryName: '가족',
      time: time,
      reminders: reminders ?? const [ReminderLead.day1],
    );

void main() {
  test('reminders 왕복', () {
    // hour1(분/시간 리드)은 시간이 있는 일정에만 유효하므로 time을 채운다.
    final e = _base(
      time: '15:00',
      reminders: const [ReminderLead.hour1, ReminderLead.day1],
    );
    final r = CalendarEvent.fromJson(e.toJson());
    expect(r.reminders, const [ReminderLead.hour1, ReminderLead.day1]);
  });
  test('기본값 [day1]', () {
    expect(_base().reminders, const [ReminderLead.day1]);
  });
  test('하위호환: reminders 없으면 [day1]', () {
    final json = {
      'id': 'x',
      'date': '2026-07-28',
      'categoryId': 'c1',
      'categoryName': '가족',
      'type': 'regular',
      'notify': true,
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.day1]);
  });
  test('빈 리스트도 [day1]로 보정', () {
    final json = {
      'id': 'x',
      'date': '2026-07-28',
      'categoryId': 'c1',
      'categoryName': '가족',
      'type': 'regular',
      'reminders': <String>[],
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.day1]);
  });
  test('copyWith', () {
    expect(
      _base().copyWith(reminders: const [ReminderLead.week1]).reminders,
      const [ReminderLead.week1],
    );
  });
  test('종일(time 없음) + 분/시간만 있으면 [day1]로 보정', () {
    final json = {
      'id': 'x',
      'date': '2026-07-28',
      'categoryId': 'c1',
      'categoryName': '가족',
      'type': 'regular',
      'reminders': ['min5', 'hour1'],
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.day1]);
  });
  test('종일 + 분/시간 섞임은 분/시간만 제거', () {
    final json = {
      'id': 'x',
      'date': '2026-07-28',
      'categoryId': 'c1',
      'categoryName': '가족',
      'type': 'regular',
      'reminders': ['min5', 'day2'],
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.day2]);
  });
  test('시간 있는 일정은 분/시간 리드 그대로 유지', () {
    final json = {
      'id': 'x',
      'date': '2026-07-28',
      'categoryId': 'c1',
      'categoryName': '가족',
      'type': 'regular',
      'time': '15:00',
      'reminders': ['min5'],
    };
    expect(CalendarEvent.fromJson(json).reminders, const [ReminderLead.min5]);
  });
}
