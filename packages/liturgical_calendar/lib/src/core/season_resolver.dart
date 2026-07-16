/// Season resolver — classifies a date into its liturgical season, week number
/// and the season's default color.
///
/// Uses the Korean national adaptation for the Christmas/Epiphany boundary:
/// 주님 공현 대축일 (Epiphany) is celebrated on the Sunday between Jan 2–8, and
/// 주님 세례 축일 (Baptism of the Lord) — the last day of Christmas Time — is the
/// following Sunday (or the Monday after, when Epiphany falls on Jan 7/8).
/// Verified against the CBCK 2026 전례력.
library;

import '../model/enums.dart';
import 'computus.dart';
import 'temporale.dart';

/// The season, week and default color resolved for a single date.
class SeasonInfo {
  const SeasonInfo(this.season, this.week, this.color);

  final Season season;

  /// Week number within the season, or `null` where numbering does not apply
  /// (Christmas Time, and the ferial days between Ash Wednesday and Lent I).
  final int? week;

  /// The default color of the season for this day, before any celebration
  /// override. Special days (성지 주일·성금요일·성령 강림) carry red.
  final LiturgicalColor color;

  @override
  String toString() => 'SeasonInfo($season, week=$week, $color)';
}

/// The Sunday on or before [date] (Sunday if [date] is a Sunday).
DateTime _sundayOnOrBefore(DateTime date) => addDays(date, -(date.weekday % 7));

/// The set of movable anchor dates for one liturgical year, applying the Korean
/// national adaptations. Identified by [adventYear] — the civil year in which
/// its First Sunday of Advent falls.
class Temporale {
  Temporale(this.adventYear);

  /// The liturgical year that contains [date].
  factory Temporale.containing(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return Temporale(
        d.isBefore(adventFirstSunday(d.year)) ? d.year - 1 : d.year);
  }

  /// Civil year in which this liturgical year's Advent begins.
  final int adventYear;

  /// Civil year in which most of the year (Christmas → Advent) falls.
  int get _y => adventYear + 1;

  DateTime get firstSundayOfAdvent => adventFirstSunday(adventYear);
  DateTime get christmas => DateTime(adventYear, 12, 25);

  /// 주님 공현 대축일 — the Sunday between Jan 2 and Jan 8 (Korean adaptation).
  DateTime get epiphany {
    final jan2 = DateTime(_y, 1, 2);
    return addDays(jan2, (7 - (jan2.weekday % 7)) % 7);
  }

  /// 주님 세례 축일 — Sunday after Epiphany; the Monday after if Epiphany is on
  /// Jan 7 or 8. Last day of Christmas Time.
  DateTime get baptismOfTheLord {
    final e = epiphany;
    return (e.day >= 7) ? addDays(e, 1) : addDays(e, 7);
  }

  DateTime get ashWednesdayDate => ashWednesday(_y);
  DateTime get easter => gregorianEaster(_y);
  DateTime get palmSundayDate => palmSunday(_y);
  DateTime get holyThursdayDate => holyThursday(_y);
  DateTime get goodFridayDate => goodFriday(_y);
  DateTime get pentecostDate => pentecost(_y);

  /// First Sunday of Lent (Ash Wednesday + 4 days).
  DateTime get firstSundayOfLent => addDays(ashWednesdayDate, 4);

  /// 그리스도왕 대축일 — last Sunday of this liturgical year, before the next
  /// year's Advent.
  DateTime get christTheKingDate => christTheKing(_y);

  /// The First Sunday of Advent that begins the *next* liturgical year and ends
  /// this one.
  DateTime get nextAdvent => adventFirstSunday(_y);

  bool _onOrAfter(DateTime a, DateTime b) => !a.isBefore(b);
  bool _before(DateTime a, DateTime b) => a.isBefore(b);

  /// Resolves [date] (assumed to belong to this liturgical year).
  SeasonInfo resolve(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);

    // 대림 Advent: [Advent I, Christmas)
    if (_onOrAfter(d, firstSundayOfAdvent) && _before(d, christmas)) {
      final week =
          (_sundayOnOrBefore(d).difference(firstSundayOfAdvent).inDays ~/ 7) +
              1;
      return SeasonInfo(Season.advent, week, LiturgicalColor.violet);
    }

    // 성탄 Christmas: [Christmas, Baptism of the Lord]
    if (_onOrAfter(d, christmas) && _onOrAfter(baptismOfTheLord, d)) {
      return const SeasonInfo(Season.christmas, null, LiturgicalColor.white);
    }

    // 파스카 성삼일 Triduum: [Holy Thursday, Easter)
    if (_onOrAfter(d, holyThursdayDate) && _before(d, easter)) {
      final color =
          (d == goodFridayDate) ? LiturgicalColor.red : LiturgicalColor.white;
      return SeasonInfo(Season.paschalTriduum, null, color);
    }

    // 사순 Lent: (Baptism, Holy Thursday)
    if (_before(baptismOfTheLord, d) && _before(d, holyThursdayDate)) {
      if (_onOrAfter(d, ashWednesdayDate)) {
        final int? week = _before(d, firstSundayOfLent)
            ? null
            : (_sundayOnOrBefore(d).difference(firstSundayOfLent).inDays ~/ 7) +
                1;
        final color = (d == palmSundayDate)
            ? LiturgicalColor.red
            : LiturgicalColor.violet;
        return SeasonInfo(Season.lent, week, color);
      }
      // 연중 시기 (블록 1): (Baptism, Ash Wednesday)
      final week =
          (_sundayOnOrBefore(d).difference(baptismOfTheLord).inDays ~/ 7) + 1;
      return SeasonInfo(Season.ordinaryTime, week, LiturgicalColor.green);
    }

    // 부활 Easter: [Easter, Pentecost]
    if (_onOrAfter(d, easter) && _onOrAfter(pentecostDate, d)) {
      final color =
          (d == pentecostDate) ? LiturgicalColor.red : LiturgicalColor.white;
      final week = (_sundayOnOrBefore(d).difference(easter).inDays ~/ 7) + 1;
      return SeasonInfo(Season.easter, week, color);
    }

    // 연중 시기 (블록 2): (Pentecost, next Advent) — numbered backward from
    // 그리스도왕 = 제34주간.
    final weeksToCtk =
        christTheKingDate.difference(_sundayOnOrBefore(d)).inDays ~/ 7;
    return SeasonInfo(
        Season.ordinaryTime, 34 - weeksToCtk, LiturgicalColor.green);
  }
}

/// Resolves the liturgical season, week and default color for [date].
SeasonInfo resolveSeason(DateTime date) =>
    Temporale.containing(date).resolve(date);
