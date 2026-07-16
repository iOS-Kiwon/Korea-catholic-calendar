import 'package:liturgical_calendar/src/i18n/ko_kr.dart';
import 'package:test/test.dart';

void main() {
  String title(int y, int m, int d) => koTemporalTitle(DateTime(y, m, d));

  group('koTemporalTitle (2026)', () {
    test('연중 주일', () => expect(title(2026, 7, 12), '연중 제15주일'));
    test('연중 평일', () => expect(title(2026, 7, 15), '연중 제15주간 수요일'));

    test('대림 주일', () => expect(title(2026, 11, 29), '대림 제1주일'));
    test('대림 평일', () => expect(title(2026, 11, 30), '대림 제1주간 월요일'));

    test('사순 주일', () => expect(title(2026, 2, 22), '사순 제1주일'));
    test('사순 평일', () => expect(title(2026, 2, 23), '사순 제1주간 월요일'));
    test('재의 수요일 다음 평일', () => expect(title(2026, 2, 19), '재의 수요일 다음 목요일'));

    test('부활 팔일 축제 평일', () => expect(title(2026, 4, 6), '부활 팔일 축제 월요일'));
    test('부활 주일', () => expect(title(2026, 4, 12), '부활 제2주일'));
    test('부활 평일', () => expect(title(2026, 4, 13), '부활 제2주간 월요일'));

    test('성삼일: 성목요일', () => expect(title(2026, 4, 2), '주님 만찬 성목요일'));
    test('성삼일: 성금요일', () => expect(title(2026, 4, 3), '주님 수난 성금요일'));
    test('성삼일: 성토요일', () => expect(title(2026, 4, 4), '성토요일'));
  });
}
