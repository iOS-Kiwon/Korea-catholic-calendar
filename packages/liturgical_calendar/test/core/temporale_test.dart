import 'package:liturgical_calendar/src/core/temporale.dart';
import 'package:test/test.dart';

void main() {
  group('adventFirstSunday', () {
    // First Sunday of Advent — begins the liturgical year in December of the
    // given civil year. Cross-checked against published calendars.
    const known = <int, (int, int)>{
      2022: (11, 27),
      2023: (12, 3),
      2024: (12, 1),
      2025: (11, 30),
      2026: (11, 29),
      2027: (11, 28),
    };
    known.forEach((year, md) {
      test('$year → ${md.$1}/${md.$2}', () {
        expect(adventFirstSunday(year), DateTime(year, md.$1, md.$2));
      });
    });

    test('is always a Sunday between Nov 27 and Dec 3', () {
      for (var y = 1970; y <= 2100; y++) {
        final d = adventFirstSunday(y);
        expect(d.weekday, DateTime.sunday);
        expect(d.isBefore(DateTime(y, 11, 27)), isFalse);
        expect(d.isAfter(DateTime(y, 12, 3)), isFalse);
      }
    });
  });

  group('Easter-relative movable feasts (2026, Easter = Apr 5)', () {
    test('재의 수요일 Ash Wednesday = Feb 18', () {
      expect(ashWednesday(2026), DateTime(2026, 2, 18));
    });
    test('주님 수난 성지 주일 Palm Sunday = Mar 29', () {
      expect(palmSunday(2026), DateTime(2026, 3, 29));
    });
    test('성목요일 Holy Thursday = Apr 2', () {
      expect(holyThursday(2026), DateTime(2026, 4, 2));
    });
    test('성금요일 Good Friday = Apr 3', () {
      expect(goodFriday(2026), DateTime(2026, 4, 3));
    });
    test('주님 승천(목) Ascension Thursday = May 14', () {
      expect(ascensionThursday(2026), DateTime(2026, 5, 14));
    });
    test('성령 강림 Pentecost = May 24', () {
      expect(pentecost(2026), DateTime(2026, 5, 24));
    });
    test('삼위일체 Trinity Sunday = May 31', () {
      expect(trinitySunday(2026), DateTime(2026, 5, 31));
    });
    test('성체 성혈(목) Corpus Christi Thursday = Jun 4', () {
      expect(corpusChristiThursday(2026), DateTime(2026, 6, 4));
    });
    test('예수 성심 Sacred Heart = Jun 12', () {
      expect(sacredHeart(2026), DateTime(2026, 6, 12));
    });
  });

  group('christTheKing', () {
    test('2026 → Nov 22 (Sunday before Advent I)', () {
      expect(christTheKing(2026), DateTime(2026, 11, 22));
      expect(christTheKing(2026).weekday, DateTime.sunday);
    });
    test('is exactly 7 days before Advent I', () {
      for (var y = 1970; y <= 2100; y++) {
        expect(
          christTheKing(y),
          adventFirstSunday(y).subtract(const Duration(days: 7)),
        );
      }
    });
  });

  group('movable feast invariants (1970–2100)', () {
    test('all keep their expected weekday', () {
      for (var y = 1970; y <= 2100; y++) {
        expect(ashWednesday(y).weekday, DateTime.wednesday);
        expect(palmSunday(y).weekday, DateTime.sunday);
        expect(holyThursday(y).weekday, DateTime.thursday);
        expect(goodFriday(y).weekday, DateTime.friday);
        expect(ascensionThursday(y).weekday, DateTime.thursday);
        expect(pentecost(y).weekday, DateTime.sunday);
        expect(trinitySunday(y).weekday, DateTime.sunday);
        expect(sacredHeart(y).weekday, DateTime.friday);
      }
    });
  });
}
