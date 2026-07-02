import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:liturgical_calendar/src/core/reading_cycle.dart';
import 'package:test/test.dart';

void main() {
  group('liturgicalYearEndingOn', () {
    test('a date before Advent I belongs to the year ending that civil year',
        () {
      // 2026-07-02 is before Advent I 2026 (Nov 29) → liturgical year 2025–26.
      expect(liturgicalYearEndingOn(DateTime(2026, 7, 2)), 2026);
    });
    test('Advent I itself starts the next liturgical year', () {
      // Advent I 2025 = Nov 30, 2025 → liturgical year 2025–26 (ends 2026).
      expect(liturgicalYearEndingOn(DateTime(2025, 11, 30)), 2026);
    });
    test('the day before Advent I still belongs to the ending year', () {
      expect(liturgicalYearEndingOn(DateTime(2025, 11, 29)), 2025);
    });
  });

  group('sundayCycle (가/나/다해)', () {
    // Verified anchors: 2023–24 = B, 2024–25 = C, 2025–26 = A.
    test('endYear 2024 → B', () => expect(sundayCycle(2024), SundayCycle.b));
    test('endYear 2025 → C', () => expect(sundayCycle(2025), SundayCycle.c));
    test('endYear 2026 → A', () => expect(sundayCycle(2026), SundayCycle.a));

    test('advances A→B→C each liturgical year', () {
      for (var end = 1970; end <= 2100; end++) {
        final next = sundayCycle(end + 1);
        final cur = sundayCycle(end);
        final expected = SundayCycle.values[(cur.index + 1) % 3];
        expect(next, expected,
            reason: 'cycle must advance by one from $end to ${end + 1}');
      }
    });
  });

  group('weekdayCycle (Ⅰ/Ⅱ)', () {
    // Verified anchors: 2023–24 = II, 2024–25 = I, 2025–26 = II.
    test(
        'endYear 2024 → II', () => expect(weekdayCycle(2024), WeekdayCycle.ii));
    test('endYear 2025 → I', () => expect(weekdayCycle(2025), WeekdayCycle.i));
    test(
        'endYear 2026 → II', () => expect(weekdayCycle(2026), WeekdayCycle.ii));
  });

  group('convenience: cycle on a date', () {
    test('2026-07-02 → Sunday A, Weekday II', () {
      final d = DateTime(2026, 7, 2);
      expect(sundayCycleOn(d), SundayCycle.a);
      expect(weekdayCycleOn(d), WeekdayCycle.ii);
    });
    test('cycle flips at Advent I, not at Jan 1', () {
      // Nov 29, 2025 (before Advent I) vs Nov 30, 2025 (Advent I).
      expect(sundayCycleOn(DateTime(2025, 11, 29)), SundayCycle.c); // 2024–25
      expect(sundayCycleOn(DateTime(2025, 11, 30)), SundayCycle.a); // 2025–26
    });
  });
}
