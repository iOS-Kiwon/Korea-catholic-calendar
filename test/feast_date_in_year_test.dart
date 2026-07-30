import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

void main() {
  final service = CalendarService(engine: LiturgicalCalendar());

  test('부활절(easter) 날짜를 연도별로 계산한다', () {
    expect(service.feastDateInYear('easter', 2026), DateTime(2026, 4, 5));
    expect(service.feastDateInYear('easter', 2027), DateTime(2027, 3, 28));
  });

  test('알 수 없는 축일 id는 null', () {
    expect(service.feastDateInYear('no_such_feast', 2026), isNull);
  });

  test('반복 호출 시 같은 값(캐시)', () {
    final a = service.feastDateInYear('easter', 2030);
    final b = service.feastDateInYear('easter', 2030);
    expect(a, b);
    expect(a, isNotNull);
  });
}
