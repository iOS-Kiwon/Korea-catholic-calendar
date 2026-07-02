/// Computus — the calculation of the date of Easter Sunday.
///
/// The date of Easter anchors every movable celebration of the liturgical
/// year, so this is the foundation of the whole engine.
library;

/// Returns the date of Easter Sunday in the Gregorian calendar for [year].
///
/// Uses the "anonymous Gregorian algorithm" (Meeus/Jones/Butcher), which is
/// integer-only, table-free and valid for every Gregorian year. Easter always
/// falls between March 22 and April 25 inclusive.
DateTime gregorianEaster(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31; // 3 = March, 4 = April
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}
