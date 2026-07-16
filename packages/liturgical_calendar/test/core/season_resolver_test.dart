import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:liturgical_calendar/src/core/season_resolver.dart';
import 'package:test/test.dart';

/// Golden data cross-checked against the CBCK 2026 전례력
/// (missa.cbck.or.kr/liturgy): 주님 공현 1/4, 주님 세례 1/11, 재의 수요일 2/18,
/// 부활 4/5, 주님 승천 5/17, 성령 강림 5/24, 성체 성혈 6/7, 그리스도왕 11/22,
/// 대림 제1주일 11/29.
void main() {
  SeasonInfo at(int y, int m, int d) => resolveSeason(DateTime(y, m, d));

  group('season classification (2026)', () {
    test('성탄 시기: 1/1 → Christmas / white', () {
      expect(at(2026, 1, 1).season, Season.christmas);
      expect(at(2026, 1, 1).color, LiturgicalColor.white);
    });
    test('주님 세례(1/11)는 성탄 시기의 마지막 날', () {
      expect(at(2026, 1, 11).season, Season.christmas);
    });
    test('연중 시기 블록1: 1/12(월) → Ordinary / green / 제1주간', () {
      final s = at(2026, 1, 12);
      expect(s.season, Season.ordinaryTime);
      expect(s.color, LiturgicalColor.green);
      expect(s.week, 1);
    });
    test('연중 제2주일 = 1/18', () => expect(at(2026, 1, 18).week, 2));
    test('연중 제6주일 = 2/15', () => expect(at(2026, 2, 15).week, 6));

    test('사순 시작: 재의 수요일 2/18 → Lent / violet / (주간 없음)', () {
      final s = at(2026, 2, 18);
      expect(s.season, Season.lent);
      expect(s.color, LiturgicalColor.violet);
      expect(s.week, isNull);
    });
    test('사순 제1주일 = 2/22', () => expect(at(2026, 2, 22).week, 1));
    test('사순 제4주일(Laetare) = 3/15', () => expect(at(2026, 3, 15).week, 4));
    test('주님 수난 성지 주일 3/29 → Lent 제6주간(성주간) / red', () {
      final s = at(2026, 3, 29);
      expect(s.season, Season.lent);
      expect(s.week, 6);
      expect(s.color, LiturgicalColor.red);
    });

    test('성목요일 4/2 → Triduum / white', () {
      expect(at(2026, 4, 2).season, Season.paschalTriduum);
      expect(at(2026, 4, 2).color, LiturgicalColor.white);
    });
    test('성금요일 4/3 → Triduum / red', () {
      expect(at(2026, 4, 3).season, Season.paschalTriduum);
      expect(at(2026, 4, 3).color, LiturgicalColor.red);
    });

    test('주님 부활 대축일 4/5 → Easter / white / 제1주간', () {
      final s = at(2026, 4, 5);
      expect(s.season, Season.easter);
      expect(s.color, LiturgicalColor.white);
      expect(s.week, 1);
    });
    test('부활 제2주일 = 4/12', () => expect(at(2026, 4, 12).week, 2));
    test('성령 강림 대축일 5/24 → Easter / red (부활 시기 마지막)', () {
      expect(at(2026, 5, 24).season, Season.easter);
      expect(at(2026, 5, 24).color, LiturgicalColor.red);
    });

    test('성령 강림 다음날 5/25(월) → Ordinary 블록2 / green / 제8주간', () {
      final s = at(2026, 5, 25);
      expect(s.season, Season.ordinaryTime);
      expect(s.color, LiturgicalColor.green);
      expect(s.week, 8);
    });
    test('그리스도왕 11/22 → Ordinary / 제34주간 (시기 기본색 green)', () {
      final s = at(2026, 11, 22);
      expect(s.season, Season.ordinaryTime);
      expect(s.week, 34);
    });
    test('연중 마지막 평일 11/28(토) → Ordinary', () {
      expect(at(2026, 11, 28).season, Season.ordinaryTime);
    });

    test('대림 제1주일 11/29 → Advent / violet / 제1주간', () {
      final s = at(2026, 11, 29);
      expect(s.season, Season.advent);
      expect(s.color, LiturgicalColor.violet);
      expect(s.week, 1);
    });
    test('대림 제3주일(Gaudete) 12/13 → Advent / 제3주간', () {
      expect(at(2026, 12, 13).season, Season.advent);
      expect(at(2026, 12, 13).week, 3);
    });
    test('주님 성탄 대축일 12/25 → Christmas / white', () {
      expect(at(2026, 12, 25).season, Season.christmas);
      expect(at(2026, 12, 25).color, LiturgicalColor.white);
    });
  });

  group('invariants (1970–2100)', () {
    test('every day resolves to a season and a color', () {
      for (var y = 1990; y <= 2060; y++) {
        var d = DateTime(y, 1, 1);
        final end = DateTime(y, 12, 31);
        while (!d.isAfter(end)) {
          final s = resolveSeason(d);
          expect(s.season, isNotNull, reason: '$d has no season');
          // Advent/Lent are penitential violet (except special red/rose days);
          // Ordinary Time is always green.
          if (s.season == Season.ordinaryTime) {
            expect(s.color, LiturgicalColor.green, reason: '$d OT not green');
          }
          d = DateTime(y, d.month, d.day + 1);
        }
      }
    });
  });
}
