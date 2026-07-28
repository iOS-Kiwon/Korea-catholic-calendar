import 'package:catholic_calendar/features/events/model/reminder_lead.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('분/시간 리드는 시작 시각 기준', () {
    expect(ReminderLead.hour1.reminderTime(DateTime(2026, 7, 28), '15:00'),
        DateTime(2026, 7, 28, 14, 0));
    expect(ReminderLead.min30.reminderTime(DateTime(2026, 7, 28), '15:00'),
        DateTime(2026, 7, 28, 14, 30));
    // 자정 넘김
    expect(ReminderLead.hour2.reminderTime(DateTime(2026, 7, 28), '00:30'),
        DateTime(2026, 7, 27, 22, 30));
  });

  test('일/주 리드는 해당 날 -N일 09:00', () {
    expect(ReminderLead.day1.reminderTime(DateTime(2026, 7, 28), '15:00'),
        DateTime(2026, 7, 27, 9, 0));
    expect(ReminderLead.day2.reminderTime(DateTime(2026, 7, 28), null),
        DateTime(2026, 7, 26, 9, 0));
    expect(ReminderLead.week1.reminderTime(DateTime(2026, 7, 28), null),
        DateTime(2026, 7, 21, 9, 0));
  });

  test('종일 일정에는 분/시간 리드 없음(null)', () {
    expect(ReminderLead.min5.reminderTime(DateTime(2026, 7, 28), null), isNull);
    expect(ReminderLead.hour1.reminderTime(DateTime(2026, 7, 28), null), isNull);
  });

  test('isSubDay / fromStorage 왕복', () {
    expect(ReminderLead.hour2.isSubDay, isTrue);
    expect(ReminderLead.day1.isSubDay, isFalse);
    expect(ReminderLead.fromStorage('week1'), ReminderLead.week1);
    expect(ReminderLead.fromStorage('nope'), isNull);
  });
}
