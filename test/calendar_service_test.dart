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
       "url":"https://missa.cbck.or.kr/DailyMissa/20260715",
       "saintInfoUrl":"https://maria.catholic.or.kr/sa_ho/list/view.asp?menugubun=saint&ctxtSaintId=1"},
      {"date":"2026-06-28","color":"green","title":"연중 제13주일","special":"교황 주일"}
    ]}''';
    final service = CalendarService(
      engine: engine,
      cbck: CalendarService.parseSnapshot(snapshot),
    );

    final d = service.day(DateTime(2026, 7, 15));
    expect(d.title, '성 보나벤투라 주교 학자 기념일');
    expect(d.color, LiturgicalColor.white);
    expect(d.celebration.name, '성 보나벤투라 주교 학자 기념일');
    expect(d.celebration.rank, Rank.obligatoryMemorial);
    expect(d.scriptureReadings, hasLength(2));
    expect(d.sourceUrl, contains('DailyMissa'));
    expect(d.saintInfoUrl, contains('ctxtSaintId=1'));
    // Structural fields still come from the engine.
    expect(d.season, Season.ordinaryTime);
    expect(d.sundayCycle, SundayCycle.a); // 2025–26

    final sun = service.day(DateTime(2026, 6, 28));
    expect(sun.specialDay, '교황 주일');
  });

  test('parses explicit and inferred ranks from authoritative days', () {
    final service = CalendarService(
      engine: engine,
      cbck: CalendarService.parseDays(const [
        {'date': '2026-07-25', 'color': 'red', 'title': '성 야고보 사도 축일'},
        {
          'date': '2026-12-25',
          'color': 'white',
          'title': '주님 성탄 대축일',
          'rank': 'solemnity',
        },
        {'date': '2026-08-06', 'color': 'white', 'title': '주님의 거룩한 변모 축일'},
        {'date': '2026-08-25', 'color': 'white', 'title': '성 루도비코'},
      ]),
    );

    expect(service.day(DateTime(2026, 7, 25)).celebration.rank, Rank.feast);
    expect(
      service.day(DateTime(2026, 12, 25)).celebration.rank,
      Rank.solemnity,
    );
    expect(
      service.day(DateTime(2026, 8, 6)).celebration.rank,
      Rank.feastOfTheLord,
    );
    expect(
      service.day(DateTime(2026, 8, 25)).celebration.rank,
      Rank.optionalMemorial,
    );
    expect(
      service.day(DateTime(2026, 8, 25)).celebration.kind,
      CelebrationKind.sanctorale,
    );
  });

  test('uses remote shortTitle before bundled short title mapping', () {
    final service = CalendarService(
      engine: engine,
      cbck: CalendarService.parseDays(const [
        {
          'date': '2026-04-05',
          'color': 'white',
          'title': '주님 부활 대축일',
          'shortTitle': '부활',
        },
      ]),
    );

    final day = service.day(DateTime(2026, 4, 5));
    expect(day.celebration.id, 'easter');
    expect(service.shortTitleFor(day), '부활');
  });

  test('parses saint alternatives as optional memorials', () {
    final service = CalendarService(
      engine: engine,
      cbck: CalendarService.parseDays(const [
        {
          'date': '2026-08-25',
          'color': 'green',
          'title': '연중 제21주간 화요일',
          'alternatives': [
            {'name': '성 루도비코', 'color': 'white'},
            {'name': '성 요셉 데 갈라산즈 사제', 'color': 'white'},
          ],
        },
      ]),
    );

    final d = service.day(DateTime(2026, 8, 25));
    expect(d.celebration.rank, Rank.feria);
    expect(d.optionalMemorials, hasLength(2));
    expect(d.optionalMemorials.first.rank, Rank.optionalMemorial);
    expect(d.optionalMemorials.first.kind, CelebrationKind.sanctorale);
    expect(d.optionalMemorials.last.name, '성 요셉 데 갈라산즈 사제');
  });

  test(
    'applies liturgical display dataset to primary and alternative rows',
    () {
      final cbck = CalendarService.parseDays(const [
        {
          'date': '2026-08-25',
          'color': 'green',
          'title': '연중 제21주간 화요일',
          'alternatives': [
            {'name': '성 루도비코', 'color': 'white'},
            {'name': '성 요셉 데 갈라산즈 사제', 'color': 'white'},
          ],
        },
        {'date': '2026-11-02', 'color': 'white', 'title': '위령의 날'},
      ]);
      final service = CalendarService(
        engine: engine,
        cbck: CalendarService.applyDisplayDataset(cbck, '''
      {"entries":[
        {"date":"2026-08-25","source":"primary","sourceIndex":0,"title":"연중 제21주간 화요일","displayType":"liturgy"},
        {"date":"2026-08-25","source":"alternative","sourceIndex":0,"title":"성 루도비코","displayType":"saintFeast"},
        {"date":"2026-08-25","source":"alternative","sourceIndex":1,"title":"성 요셉 데 갈라산즈 사제","displayType":"saintFeast"},
        {"date":"2026-11-02","source":"primary","sourceIndex":0,"title":"위령의 날","displayType":"liturgy"}
      ]}'''),
      );

      final aug25 = service.day(DateTime(2026, 8, 25));
      expect(aug25.celebration.displayType, LiturgicalDisplayType.liturgy);
      expect(
        aug25.optionalMemorials.map((m) => m.displayType),
        everyElement(LiturgicalDisplayType.saintFeast),
      );

      final allSouls = service.day(DateTime(2026, 11, 2));
      expect(allSouls.celebration.rank, Rank.feast);
      expect(allSouls.celebration.displayType, LiturgicalDisplayType.liturgy);
    },
  );

  test('remote data merged later overrides bundled snapshot days', () {
    const snapshot = '''
    {"source":"test","days":[
      {"date":"2026-07-15","color":"green","title":"번들 스냅샷 제목"}
    ]}''';
    final service = CalendarService(
      engine: engine,
      cbck: CalendarService.parseSnapshot(snapshot),
    );

    service.merge(
      CalendarService.parseDays(const [
        {
          'date': '2026-07-15',
          'color': 'white',
          'title': '서버 수정 제목',
          'readings': ['① 이사 10,5-7.13-16'],
        },
      ]),
    );

    final d = service.day(DateTime(2026, 7, 15));
    expect(d.title, '서버 수정 제목');
    expect(d.color, LiturgicalColor.white);
    expect(d.scriptureReadings, hasLength(1));
  });

  test(
    'remote merge preserves bundled display type when response omits it',
    () {
      final service = CalendarService(
        engine: engine,
        cbck: CalendarService.parseDays(const [
          {
            'date': '2026-08-25',
            'color': 'green',
            'title': '연중 제21주간 화요일',
            'shortTitle': '연중',
            'displayType': 'liturgy',
            'alternatives': [
              {'name': '성 루도비코', 'color': 'white', 'displayType': 'saintFeast'},
            ],
          },
        ]),
      );

      service.merge(
        CalendarService.parseDays(const [
          {
            'date': '2026-08-25',
            'color': 'green',
            'title': '서버 제목',
            'alternatives': [
              {'name': '성 루도비코', 'color': 'white'},
            ],
          },
        ]),
      );

      final d = service.day(DateTime(2026, 8, 25));
      expect(d.title, '서버 제목');
      expect(service.shortTitleFor(d), '연중');
      expect(d.celebration.displayType, LiturgicalDisplayType.liturgy);
      expect(
        d.optionalMemorials.single.displayType,
        LiturgicalDisplayType.saintFeast,
      );
    },
  );
}
