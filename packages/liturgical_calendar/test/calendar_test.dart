import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:test/test.dart';

void main() {
  final cal = LiturgicalCalendar();

  group('ordinary day', () {
    final d = cal.day(DateTime(2026, 7, 15));
    test('연중 평일 title/season/color', () {
      expect(d.title, '연중 제15주간 수요일');
      expect(d.season, Season.ordinaryTime);
      expect(d.seasonWeek, 15);
      expect(d.color, LiturgicalColor.green);
    });
    test('reading cycles A / II', () {
      expect(d.sundayCycle, SundayCycle.a);
      expect(d.weekdayCycle, WeekdayCycle.ii);
    });
    test('weekday is not a holy day of obligation', () {
      expect(d.isHolyDayOfObligation, isFalse);
    });
  });

  group('temporale solemnities & Korean transfers (2026)', () {
    test('주님 공현 대축일 = 1/4 (주일 이동)', () {
      expect(cal.day(DateTime(2026, 1, 4)).title, '주님 공현 대축일');
    });
    test('주님 부활 대축일 = 4/5', () {
      expect(cal.day(DateTime(2026, 4, 5)).title, '주님 부활 대축일');
    });
    test('주님 수난 성지 주일 = 3/29 / red', () {
      final d = cal.day(DateTime(2026, 3, 29));
      expect(d.title, '주님 수난 성지 주일');
      expect(d.color, LiturgicalColor.red);
    });
    test('주님 승천 대축일 = 5/17 (주일 이동)', () {
      expect(cal.day(DateTime(2026, 5, 17)).title, '주님 승천 대축일');
    });
    test('성체 성혈 대축일 = 6/7 (주일 이동)', () {
      expect(cal.day(DateTime(2026, 6, 7)).title, '지극히 거룩하신 그리스도의 성체 성혈 대축일');
    });
    test('그리스도왕 대축일 = 11/22', () {
      expect(cal.day(DateTime(2026, 11, 22)).title, '온 누리의 임금 예수 그리스도왕 대축일');
    });
  });

  group('sanctorale', () {
    test('주님 성탄 대축일 12/25 / white / 의무 축일', () {
      final d = cal.day(DateTime(2026, 12, 25));
      expect(d.title, '주님 성탄 대축일');
      expect(d.color, LiturgicalColor.white);
      expect(d.isHolyDayOfObligation, isTrue);
    });
    test('천주의 성모 마리아 대축일 1/1', () {
      expect(cal.day(DateTime(2026, 1, 1)).title, '천주의 성모 마리아 대축일');
    });
    test('성모 승천 대축일 8/15', () {
      expect(cal.day(DateTime(2026, 8, 15)).title, '성모 승천 대축일');
    });
    test('한국 순교자 대축일 9/20 (proper solemnity, red) — 주일보다 우선', () {
      final d = cal.day(DateTime(2026, 9, 20));
      expect(d.celebration.id, 'korean_martyrs');
      expect(d.color, LiturgicalColor.red);
      expect(d.celebration.isProperToKorea, isTrue);
    });
  });

  group('solemnity transfer', () {
    test('원죄 없이 잉태되신 대축일: 2024 대림 2주일(12/8) → 12/9로 이동', () {
      // Dec 8, 2024 is the Second Sunday of Advent.
      expect(cal.day(DateTime(2024, 12, 8)).title, '대림 제2주일');
      expect(cal.day(DateTime(2024, 12, 9)).title, '원죄 없이 잉태되신 복되신 동정 마리아 대축일');
    });
  });

  group('month() / range()', () {
    test('month returns one entry per day', () {
      expect(cal.month(2026, 7).length, 31);
      expect(cal.month(2026, 2).length, 28);
    });
    test('every day has a season and a non-empty title (whole 2026)', () {
      for (final d in cal.year(2026)) {
        expect(d.title, isNotEmpty);
      }
    });
  });
}
