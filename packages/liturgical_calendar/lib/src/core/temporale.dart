/// Temporale — the movable dates of the Proper of Time.
///
/// Every celebration here derives from one of two anchors: the date of Easter
/// (see [gregorianEaster]) or the First Sunday of Advent. All arithmetic is
/// done in whole calendar days via [addDays], which is immune to DST because it
/// goes through the `DateTime` constructor rather than adding a `Duration`.
library;

import 'computus.dart';

/// Adds [days] calendar days to [date], returning a date-only value.
///
/// Uses the `DateTime` constructor (which normalizes overflow) so the result is
/// unaffected by daylight-saving transitions.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// The First Sunday of Advent that begins the liturgical year in December of
/// [civilYear].
///
/// The Fourth Sunday of Advent is the Sunday on or before December 24; Advent I
/// is 21 days earlier. Always falls between Nov 27 and Dec 3.
DateTime adventFirstSunday(int civilYear) {
  final christmas = DateTime(civilYear, 12, 25);
  // weekday: Mon=1 … Sun=7. Days back to the Sunday on/before Dec 24.
  final dec24Weekday = DateTime(civilYear, 12, 24).weekday % 7; // Sun=0 … Sat=6
  final fourthAdventSunday =
      addDays(DateTime(civilYear, 12, 24), -dec24Weekday);
  // Guard: fourthAdventSunday must be < Christmas (it always is by construction).
  assert(fourthAdventSunday.isBefore(christmas));
  return addDays(fourthAdventSunday, -21);
}

/// 재의 수요일 — Ash Wednesday, start of Lent (46 days before Easter).
DateTime ashWednesday(int easterYear) =>
    addDays(gregorianEaster(easterYear), -46);

/// 주님 수난 성지 주일 — Palm Sunday (7 days before Easter).
DateTime palmSunday(int easterYear) => addDays(gregorianEaster(easterYear), -7);

/// 주님 만찬 성목요일 — Holy Thursday (3 days before Easter).
DateTime holyThursday(int easterYear) =>
    addDays(gregorianEaster(easterYear), -3);

/// 주님 수난 성금요일 — Good Friday (2 days before Easter).
DateTime goodFriday(int easterYear) => addDays(gregorianEaster(easterYear), -2);

/// 주님 승천 대축일 (목요일 기준) — Ascension on its traditional Thursday
/// (39 days after Easter). Some regions transfer it to the following Sunday;
/// that transfer is a national adaptation applied elsewhere.
DateTime ascensionThursday(int easterYear) =>
    addDays(gregorianEaster(easterYear), 39);

/// 성령 강림 대축일 — Pentecost (49 days after Easter); ends the Easter season.
DateTime pentecost(int easterYear) => addDays(gregorianEaster(easterYear), 49);

/// 삼위일체 대축일 — Trinity Sunday (56 days after Easter).
DateTime trinitySunday(int easterYear) =>
    addDays(gregorianEaster(easterYear), 56);

/// 지극히 거룩하신 그리스도의 성체 성혈 대축일 (목요일 기준) — Corpus Christi on its
/// traditional Thursday (60 days after Easter). Frequently transferred to the
/// following Sunday as a national adaptation.
DateTime corpusChristiThursday(int easterYear) =>
    addDays(gregorianEaster(easterYear), 60);

/// 예수 성심 대축일 — The Most Sacred Heart of Jesus (68 days after Easter,
/// the Friday after the Second Sunday after Pentecost).
DateTime sacredHeart(int easterYear) =>
    addDays(gregorianEaster(easterYear), 68);

/// 온 누리의 임금 예수 그리스도왕 대축일 — Christ the King, the last Sunday of
/// Ordinary Time, i.e. the Sunday before the First Sunday of Advent of
/// [civilYear].
DateTime christTheKing(int civilYear) =>
    addDays(adventFirstSunday(civilYear), -7);
