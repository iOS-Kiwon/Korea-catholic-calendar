import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/events/application/recurrence_expander.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

CalendarEvent _ev(
  String date,
  RecurrenceType recurrence, {
  String? feastId,
}) => CalendarEvent(
  id: 'e-$date-${recurrence.name}',
  date: date,
  categoryId: 'c1',
  categoryName: '가족',
  recurrence: recurrence,
  feastId: feastId,
);

void main() {
  final expander = RecurrenceExpander(CalendarService(engine: LiturgicalCalendar()));

  test('none: 앵커일에만 발생', () {
    final e = _ev('2026-04-23', RecurrenceType.none);
    expect(expander.occursOn(e, DateTime(2026, 4, 23)), isTrue);
    expect(expander.occursOn(e, DateTime(2026, 4, 24)), isFalse);
  });

  test('daily: 앵커 이후 매일, 이전은 미발생', () {
    final e = _ev('2026-04-23', RecurrenceType.daily);
    expect(expander.occursOn(e, DateTime(2026, 4, 22)), isFalse);
    expect(expander.occursOn(e, DateTime(2026, 4, 23)), isTrue);
    expect(expander.occursOn(e, DateTime(2026, 5, 1)), isTrue);
  });

  test('weekly: 같은 요일만(목요일)', () {
    final e = _ev('2026-04-23', RecurrenceType.weekly); // 목요일
    expect(expander.occursOn(e, DateTime(2026, 4, 30)), isTrue); // 목
    expect(expander.occursOn(e, DateTime(2026, 4, 24)), isFalse); // 금
  });

  test('monthly: 같은 일, 없는 달은 건너뜀(31일)', () {
    final e = _ev('2026-01-31', RecurrenceType.monthly);
    expect(expander.occursOn(e, DateTime(2026, 3, 31)), isTrue);
    expect(expander.occursOn(e, DateTime(2026, 2, 28)), isFalse); // 2월엔 31일 없음
  });

  test('yearlyDate: 같은 월·일, 2/29는 평년 건너뜀', () {
    final e = _ev('2024-02-29', RecurrenceType.yearlyDate);
    expect(expander.occursOn(e, DateTime(2028, 2, 29)), isTrue); // 윤년
    expect(expander.occursOn(e, DateTime(2027, 2, 28)), isFalse);
  });

  test('yearlyFeast: 매년 부활절(이동)', () {
    final e = _ev('2026-04-05', RecurrenceType.yearlyFeast, feastId: 'easter');
    expect(expander.occursOn(e, DateTime(2026, 4, 5)), isTrue); // 앵커=부활절 2026
    expect(expander.occursOn(e, DateTime(2027, 3, 28)), isTrue); // 부활절 2027
    expect(expander.occursOn(e, DateTime(2027, 4, 5)), isFalse); // 날짜 고정 아님
  });

  test('yearlyFeast: 캘린더 없으면 전개 안 함', () {
    final noCal = const RecurrenceExpander(null);
    final e = _ev('2026-04-05', RecurrenceType.yearlyFeast, feastId: 'easter');
    expect(noCal.occursOn(e, DateTime(2027, 3, 28)), isFalse);
  });

  test('eventsOn: 맵에서 그 날 발생 이벤트 수집', () {
    final map = {
      '2026-04-23': [_ev('2026-04-23', RecurrenceType.weekly)],
      '2026-04-01': [_ev('2026-04-01', RecurrenceType.none)],
    };
    final on430 = expander.eventsOn(map, DateTime(2026, 4, 30)); // 목요일
    expect(on430, hasLength(1));
    expect(on430.first.date, '2026-04-23');
  });

  test('nextOccurrences: daily 3개', () {
    final e = _ev('2026-04-23', RecurrenceType.daily);
    final next = expander.nextOccurrences(e, DateTime(2026, 4, 23), 3);
    expect(next, [
      DateTime(2026, 4, 23),
      DateTime(2026, 4, 24),
      DateTime(2026, 4, 25),
    ]);
  });

  test('nextOccurrences: weekly 3개(목요일)', () {
    final e = _ev('2026-04-23', RecurrenceType.weekly);
    final next = expander.nextOccurrences(e, DateTime(2026, 4, 23), 3);
    expect(next, [
      DateTime(2026, 4, 23),
      DateTime(2026, 4, 30),
      DateTime(2026, 5, 7),
    ]);
  });

  test('nextOccurrences: yearlyFeast 첫 회차는 2027 부활절', () {
    final e = _ev('2026-04-05', RecurrenceType.yearlyFeast, feastId: 'easter');
    final next = expander.nextOccurrences(e, DateTime(2026, 4, 6), 2);
    expect(next, hasLength(2));
    expect(next.first, DateTime(2027, 3, 28));
  });
}
