// 홈 위젯 → 앱 딥링크 해석.
//
// 위젯은 스냅샷이 오래돼 존재하지 않는 날짜를 보낼 수 있고, 공유 링크와 스킴을
// 공유하므로(`catholiccalendar://`) host로 갈라야 한다. 잘못된 입력이 엉뚱한 화면을
// 열지 않는지가 이 파일의 핵심이다.
import 'package:catholic_calendar/core/date/year_month.dart';
import 'package:catholic_calendar/features/widgets/widget_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetLinkTarget? resolve(String uri) => resolveWidgetLink(Uri.parse(uri));

  group('day', () {
    test('날짜를 선택한 달력 경로로 해석한다', () {
      final target = resolve('catholiccalendar://day/2026-08-15');
      expect(target, isNotNull);
      expect(target!.month, const YearMonth(2026, 8));
      expect(target.day, 15);
      expect(target.location, '/2026/08/15');
    });

    test('한 자리 달도 두 자리로 채운다(라우터 경로 형식 유지)', () {
      expect(resolve('catholiccalendar://day/2027-01-05')!.location, '/2027/01/5');
    });

    test('그 달에 없는 날짜는 거부한다', () {
      // 2026-02는 28일까지다. 스냅샷이 오래되면 이런 값이 올 수 있다.
      expect(resolve('catholiccalendar://day/2026-02-30'), isNull);
      expect(resolve('catholiccalendar://day/2026-08-32'), isNull);
      expect(resolve('catholiccalendar://day/2026-08-00'), isNull);
    });

    test('윤년 2월 29일은 받는다', () {
      expect(resolve('catholiccalendar://day/2028-02-29')!.day, 29);
      expect(resolve('catholiccalendar://day/2027-02-29'), isNull);
    });

    test('달 범위를 벗어나면 거부한다', () {
      expect(resolve('catholiccalendar://day/2026-13-01'), isNull);
      expect(resolve('catholiccalendar://day/2026-00-01'), isNull);
    });

    test('형식이 다르면 거부한다', () {
      expect(resolve('catholiccalendar://day/2026-8-15'), isNull);
      expect(resolve('catholiccalendar://day/20260815'), isNull);
      expect(resolve('catholiccalendar://day/'), isNull);
      expect(resolve('catholiccalendar://day'), isNull);
    });
  });

  group('month', () {
    test('달만 있는 경로로 해석한다', () {
      final target = resolve('catholiccalendar://month/2027-09');
      expect(target, isNotNull);
      expect(target!.month, const YearMonth(2027, 9));
      expect(target.day, isNull);
      expect(target.location, '/2027/09');
    });

    test('형식이 다르면 거부한다', () {
      expect(resolve('catholiccalendar://month/2027-9'), isNull);
      expect(resolve('catholiccalendar://month/2027-13'), isNull);
      expect(resolve('catholiccalendar://month/2027-09-01'), isNull);
    });
  });

  group('위젯 링크가 아닌 것', () {
    test('공유 링크는 건드리지 않는다', () {
      // 같은 스킴이지만 host가 `e`다. share_link.dart가 처리해야 한다.
      expect(resolve('catholiccalendar://e/eyJ2IjoxfQ'), isNull);
      expect(resolve('https://kcc.sidore.org/e/eyJ2IjoxfQ'), isNull);
    });

    test('iOS 위젯의 기존 widgetURL은 무시한다(앱 기본 화면으로)', () {
      expect(resolve('catholiccalendar://today'), isNull);
    });

    test('다른 스킴은 무시한다', () {
      expect(resolve('https://example.com/day/2026-08-15'), isNull);
      expect(resolve('otherapp://day/2026-08-15'), isNull);
    });
  });
}
