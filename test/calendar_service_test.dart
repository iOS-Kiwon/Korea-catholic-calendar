import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

void main() {
  final engine = LiturgicalCalendar();

  test('falls back to the engine when the snapshot has no entry', () {
    final service = CalendarService(engine: engine);
    final d = service.day(DateTime(2026, 7, 15));
    expect(d.title, '연중 제15주간 수요일'); // computed
    expect(d.scriptureReadings, isEmpty);
    expect(service.hasMonth(2026, 7), isFalse);
  });

  test('prefers the CBCK snapshot, enriching title/color/readings/special', () {
    const snapshot = '''
    {"source":"test","days":[
      {"date":"2026-07-15","color":"white","title":"성 보나벤투라 주교 학자 기념일",
       "readings":["① 이사 10,5-7.13-16","㉥ 마태 11,25-27"],
       "url":"https://missa.cbck.or.kr/DailyMissa/20260715"},
      {"date":"2026-06-28","color":"green","title":"연중 제13주일","special":"교황 주일"}
    ]}''';
    final service = CalendarService(
      engine: engine,
      cbck: CalendarService.parseSnapshot(snapshot),
    );

    final d = service.day(DateTime(2026, 7, 15));
    expect(d.title, '성 보나벤투라 주교 학자 기념일');
    expect(d.color, LiturgicalColor.white);
    expect(d.scriptureReadings, hasLength(2));
    expect(d.sourceUrl, contains('DailyMissa'));
    // Structural fields still come from the engine.
    expect(d.season, Season.ordinaryTime);
    expect(d.sundayCycle, SundayCycle.a); // 2025–26

    final sun = service.day(DateTime(2026, 6, 28));
    expect(sun.specialDay, '교황 주일');
  });
}
