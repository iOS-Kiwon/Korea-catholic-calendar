import 'package:catholic_calendar/features/calendar/application/liturgical_display_filter.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final engine = LiturgicalCalendar();
  LiturgicalDay day(int y, int m, int d) => engine.day(DateTime(y, m, d));

  test('sundayShortTitle: 제N주일에서 "주일" 제거', () {
    // 2026-07-26 연중 제17주일
    expect(sundayShortTitle(day(2026, 7, 26)), '연중 제17');
    // 2026-03-01 사순 제2주일
    expect(sundayShortTitle(day(2026, 3, 1)), '사순 제2');
    // 평일/명명 축일은 null
    expect(sundayShortTitle(day(2026, 7, 28)), isNull); // 연중 평일
    expect(sundayShortTitle(day(2026, 8, 15)), isNull); // 성모 승천(주일 아님)
  });

  // 2026-07-25 성 야고보 사도 축일: 엔진 기본(fallback) 데이터셋에는 대축일급만 있고
  // 개별 성인 축일(james_apostle 등)은 없으므로(실제 앱은 assets/calendar/general.json의
  // 전체 데이터셋을 주입해 이 축일을 인식함) copyWith로 실제 값을 덧씌운다.
  // (기존 test/widget_test.dart의 동일 패턴을 그대로 따름.)
  LiturgicalDay saintFeastOf(int y, int m, int d) => day(y, m, d).copyWith(
    title: '성 야고보 사도 축일',
    celebration: const Celebration(
      id: 'james_apostle',
      name: '성 야고보 사도 축일',
      rank: Rank.feast,
      color: LiturgicalColor.red,
      kind: CelebrationKind.sanctorale,
      precedence: PrecedenceCode.generalFeast,
      displayType: LiturgicalDisplayType.liturgy,
    ),
  );

  group('showsLabelFor', () {
    final ordinarySunday = day(2026, 7, 26); // 연중 제17주일 (rank sunday)
    final solemnityWeekday = day(2026, 8, 15); // 성모 승천 대축일 (토)
    final saintFeast = saintFeastOf(2026, 7, 25); // 성 야고보 사도 축일 (sanctorale)
    final feria = day(2026, 7, 28); // 연중 평일

    test('all = 평일 제외', () {
      expect(showsLabelFor(LiturgicalDisplayFilter.all, ordinarySunday), isTrue);
      expect(showsLabelFor(LiturgicalDisplayFilter.all, saintFeast), isTrue);
      expect(showsLabelFor(LiturgicalDisplayFilter.all, feria), isFalse);
    });
    test('feastsOnly = 대축일 또는 성인일', () {
      expect(showsLabelFor(LiturgicalDisplayFilter.feastsOnly, solemnityWeekday), isTrue);
      expect(showsLabelFor(LiturgicalDisplayFilter.feastsOnly, saintFeast), isTrue);
      expect(showsLabelFor(LiturgicalDisplayFilter.feastsOnly, ordinarySunday), isFalse);
      expect(showsLabelFor(LiturgicalDisplayFilter.feastsOnly, feria), isFalse);
    });
    test('sundaysAndSolemnities = 주일 또는 대축일', () {
      expect(showsLabelFor(LiturgicalDisplayFilter.sundaysAndSolemnities, ordinarySunday), isTrue);
      expect(showsLabelFor(LiturgicalDisplayFilter.sundaysAndSolemnities, solemnityWeekday), isTrue);
      expect(showsLabelFor(LiturgicalDisplayFilter.sundaysAndSolemnities, saintFeast), isFalse);
    });
    test('none = 항상 숨김', () {
      expect(showsLabelFor(LiturgicalDisplayFilter.none, solemnityWeekday), isFalse);
    });
  });

  group('gridLiturgicalLabel (라벨 폴백 + 필터)', () {
    final ordinarySunday = day(2026, 7, 26);
    final saintFeast = saintFeastOf(2026, 7, 25);
    test('주일: shortTitle 없으면 주일 축약', () {
      expect(
        gridLiturgicalLabel(LiturgicalDisplayFilter.sundaysAndSolemnities, null, ordinarySunday),
        '연중 제17',
      );
    });
    test('성인 축일(대축일/축일만): shortTitle 없으면 day.title 폴백', () {
      final label = gridLiturgicalLabel(LiturgicalDisplayFilter.feastsOnly, null, saintFeast);
      expect(label, isNotNull);
      expect(label, contains('야고보'));
    });
    test('필터가 숨기면 null', () {
      expect(gridLiturgicalLabel(LiturgicalDisplayFilter.none, '성모 승천', saintFeast), isNull);
      expect(gridLiturgicalLabel(LiturgicalDisplayFilter.feastsOnly, null, ordinarySunday), isNull);
    });
    test('shortTitle 있으면 우선', () {
      expect(
        gridLiturgicalLabel(LiturgicalDisplayFilter.all, '성모 승천', day(2026, 8, 15)),
        '성모 승천',
      );
    });
  });

  test('프로바이더: 기본값 + 저장/복원', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    expect(c1.read(liturgicalDisplayFilterProvider),
        LiturgicalDisplayFilter.sundaysAndSolemnities);
    await c1.read(liturgicalDisplayFilterProvider.notifier)
        .set(LiturgicalDisplayFilter.all);
    expect(c1.read(liturgicalDisplayFilterProvider), LiturgicalDisplayFilter.all);

    // 새 컨테이너에서 하이드레이트되어 복원.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    // build()는 최초 read 시점에 호출되어 기본값 반환 후 비동기 하이드레이트 시작.
    // (ProviderContainer 생성만으로는 build가 트리거되지 않으므로 먼저 한 번 읽어
    // 하이드레이트를 시작시킨 뒤 한 프레임 대기해야 한다.)
    c2.read(liturgicalDisplayFilterProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(liturgicalDisplayFilterProvider), LiturgicalDisplayFilter.all);
  });
}
