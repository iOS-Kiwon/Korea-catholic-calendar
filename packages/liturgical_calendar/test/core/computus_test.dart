import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:test/test.dart';

/// Known Gregorian Easter Sunday dates (Western/Roman computus).
/// Sources: cross-checked against published liturgical calendars.
const _knownEasters = <int, (int, int)>{
  2015: (4, 5),
  2016: (3, 27),
  2017: (4, 16),
  2018: (4, 1),
  2019: (4, 21),
  2020: (4, 12),
  2021: (4, 4),
  2022: (4, 17),
  2023: (4, 9),
  2024: (3, 31),
  2025: (4, 20),
  2026: (4, 5),
  2027: (3, 28),
  2028: (4, 16),
  2029: (4, 1),
  2030: (4, 21),
  2035: (3, 25),
  // Extreme boundary cases:
  2038: (4, 25), // latest possible date for Easter
  1943: (4, 25), // latest possible (historical)
  2285: (3, 22), // earliest possible date for Easter
  1818: (3, 22), // earliest possible (historical)
};

void main() {
  group('gregorianEaster', () {
    _knownEasters.forEach((year, md) {
      test('Easter $year is ${md.$1}/${md.$2}', () {
        final easter = gregorianEaster(year);
        expect(easter, DateTime(year, md.$1, md.$2));
      });
    });

    test('always returns a Sunday', () {
      for (var year = 1970; year <= 2100; year++) {
        expect(gregorianEaster(year).weekday, DateTime.sunday,
            reason: 'Easter $year must be a Sunday');
      }
    });

    test('always falls between March 22 and April 25 inclusive', () {
      for (var year = 1970; year <= 2100; year++) {
        final e = gregorianEaster(year);
        final earliest = DateTime(year, 3, 22);
        final latest = DateTime(year, 4, 25);
        expect(e.isBefore(earliest), isFalse,
            reason: 'Easter $year ($e) is before Mar 22');
        expect(e.isAfter(latest), isFalse,
            reason: 'Easter $year ($e) is after Apr 25');
      }
    });
  });
}
