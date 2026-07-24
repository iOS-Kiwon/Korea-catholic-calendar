import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _base({
  RecurrenceType recurrence = RecurrenceType.none,
  String? feastId,
  CalendarEventType type = CalendarEventType.regular,
}) => CalendarEvent(
  id: 'e1',
  date: '2026-04-23',
  categoryId: 'c1',
  categoryName: '가족',
  categoryColor: 0xFF2E7D32,
  type: type,
  recurrence: recurrence,
  feastId: feastId,
);

void main() {
  test('recurrence/feastId가 toJson/fromJson 왕복에서 보존된다', () {
    final e = _base(recurrence: RecurrenceType.yearlyFeast, feastId: 'easter');
    final round = CalendarEvent.fromJson(e.toJson());
    expect(round.recurrence, RecurrenceType.yearlyFeast);
    expect(round.feastId, 'easter');
  });

  test('매주 반복 왕복', () {
    final e = _base(recurrence: RecurrenceType.weekly);
    final round = CalendarEvent.fromJson(e.toJson());
    expect(round.recurrence, RecurrenceType.weekly);
    expect(round.feastId, isNull);
  });

  test('하위호환: recurrence 없는 일반 이벤트는 none', () {
    final json = {
      'id': 'x',
      'date': '2026-04-23',
      'categoryId': 'c1',
      'categoryName': '가족',
      'categoryColor': 0xFF2E7D32,
      'type': 'regular',
    };
    expect(CalendarEvent.fromJson(json).recurrence, RecurrenceType.none);
  });

  test('하위호환: recurrence 없는 축일은 yearlyDate(매년 반복 기본)', () {
    final json = {
      'id': 'x',
      'date': '2026-04-25',
      'categoryId': 'c1',
      'categoryName': '축일',
      'categoryColor': 0xFF8D6E63,
      'type': 'saintFeast',
      'saintName': '성 마르코',
    };
    expect(CalendarEvent.fromJson(json).recurrence, RecurrenceType.yearlyDate);
  });

  test('copyWith로 recurrence 변경', () {
    final e = _base();
    expect(e.copyWith(recurrence: RecurrenceType.daily).recurrence,
        RecurrenceType.daily);
  });
}
