/// Reading cycles — the Sunday (가/나/다해) and weekday (Ⅰ/Ⅱ) lectionary cycles.
///
/// Both cycles change at the First Sunday of Advent (the start of the
/// liturgical year), so they are keyed to the *liturgical* year rather than the
/// civil year. The engine returns only the cycle label, never reading text.
library;

import '../model/enums.dart';
import 'temporale.dart';

/// The civil year in which the liturgical year containing [date] ends.
///
/// A date on or after the First Sunday of Advent belongs to the liturgical year
/// that ends the following civil year; otherwise it ends in the current one.
int liturgicalYearEndingOn(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final adventStart = adventFirstSunday(d.year);
  return d.isBefore(adventStart) ? d.year : d.year + 1;
}

/// The Sunday lectionary cycle for a liturgical year ending in [endYear].
///
/// endYear % 3 → 1 = A(가), 2 = B(나), 0 = C(다).
SundayCycle sundayCycle(int endYear) {
  switch (endYear % 3) {
    case 1:
      return SundayCycle.a;
    case 2:
      return SundayCycle.b;
    default:
      return SundayCycle.c;
  }
}

/// The weekday lectionary cycle for a liturgical year ending in [endYear].
///
/// Odd end year = Ⅰ, even = Ⅱ.
WeekdayCycle weekdayCycle(int endYear) =>
    endYear.isOdd ? WeekdayCycle.i : WeekdayCycle.ii;

/// The Sunday cycle in effect on [date].
SundayCycle sundayCycleOn(DateTime date) =>
    sundayCycle(liturgicalYearEndingOn(date));

/// The weekday cycle in effect on [date].
WeekdayCycle weekdayCycleOn(DateTime date) =>
    weekdayCycle(liturgicalYearEndingOn(date));
