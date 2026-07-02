/// Builds the Proper-of-Time [Celebration] for a date: the movable solemnities
/// and feasts (with the Korean Sunday transfers) plus the generic Sunday/feria.
library;

import '../core/season_resolver.dart';
import '../core/temporale.dart';
import '../data/schema.dart';
import '../i18n/ko_kr.dart';
import '../model/celebration.dart';
import '../model/enums.dart';
import '../model/precedence_code.dart';

Celebration _temporale(
  String id,
  String name,
  Rank rank,
  LiturgicalColor color,
  PrecedenceCode precedence,
) =>
    Celebration(
      id: id,
      name: name,
      rank: rank,
      color: color,
      kind: CelebrationKind.temporale,
      precedence: precedence,
    );

/// The named movable solemnity or feast on [d], or `null` if [d] is an ordinary
/// Sunday/feria. [a] controls the Korean Sunday transfers.
Celebration? namedTemporaleCelebration(
    DateTime d, Temporale t, CalendarAdaptation a) {
  final easter = t.easter;
  final epiphanyDate =
      a.epiphanyOnSunday ? t.epiphany : DateTime(t.adventYear + 1, 1, 6);
  final ascensionDate =
      a.ascensionOnSunday ? addDays(easter, 42) : addDays(easter, 39);
  final corpusDate =
      a.corpusChristiOnSunday ? addDays(easter, 63) : addDays(easter, 60);

  if (d == epiphanyDate) {
    return _temporale('epiphany', '주님 공현 대축일', Rank.solemnity,
        LiturgicalColor.white, PrecedenceCode.privilegedSolemnity);
  }
  if (d == t.baptismOfTheLord) {
    return _temporale('baptism_of_the_lord', '주님 세례 축일', Rank.feastOfTheLord,
        LiturgicalColor.white, PrecedenceCode.feastOfTheLord);
  }
  if (d == _holyFamily(t)) {
    return _temporale('holy_family', '예수, 마리아, 요셉의 성가정 축일', Rank.feastOfTheLord,
        LiturgicalColor.white, PrecedenceCode.feastOfTheLord);
  }
  if (d == t.ashWednesdayDate) {
    return _temporale('ash_wednesday', '재의 수요일', Rank.privilegedFeria,
        LiturgicalColor.violet, PrecedenceCode.privilegedSolemnity);
  }
  if (d == t.palmSundayDate) {
    return _temporale('palm_sunday', '주님 수난 성지 주일', Rank.sunday,
        LiturgicalColor.red, PrecedenceCode.privilegedSolemnity);
  }
  if (d == t.holyThursdayDate) {
    return _temporale('holy_thursday', '주님 만찬 성목요일', Rank.privilegedFeria,
        LiturgicalColor.white, PrecedenceCode.triduum);
  }
  if (d == t.goodFridayDate) {
    return _temporale('good_friday', '주님 수난 성금요일', Rank.privilegedFeria,
        LiturgicalColor.red, PrecedenceCode.triduum);
  }
  if (d == addDays(easter, -1)) {
    return _temporale('holy_saturday', '성토요일', Rank.privilegedFeria,
        LiturgicalColor.white, PrecedenceCode.triduum);
  }
  if (d == easter) {
    return _temporale('easter', '주님 부활 대축일', Rank.solemnity,
        LiturgicalColor.white, PrecedenceCode.privilegedSolemnity);
  }
  if (d == ascensionDate) {
    return _temporale('ascension', '주님 승천 대축일', Rank.solemnity,
        LiturgicalColor.white, PrecedenceCode.privilegedSolemnity);
  }
  if (d == t.pentecostDate) {
    return _temporale('pentecost', '성령 강림 대축일', Rank.solemnity,
        LiturgicalColor.red, PrecedenceCode.privilegedSolemnity);
  }
  if (d == addDays(easter, 56)) {
    return _temporale('trinity', '삼위일체 대축일', Rank.solemnity,
        LiturgicalColor.white, PrecedenceCode.generalSolemnity);
  }
  if (d == corpusDate) {
    return _temporale('corpus_christi', '지극히 거룩하신 그리스도의 성체 성혈 대축일',
        Rank.solemnity, LiturgicalColor.white, PrecedenceCode.generalSolemnity);
  }
  if (d == addDays(easter, 68)) {
    return _temporale('sacred_heart', '예수 성심 대축일', Rank.solemnity,
        LiturgicalColor.white, PrecedenceCode.generalSolemnity);
  }
  if (d == t.christTheKingDate) {
    return _temporale('christ_the_king', '온 누리의 임금 예수 그리스도왕 대축일',
        Rank.solemnity, LiturgicalColor.white, PrecedenceCode.generalSolemnity);
  }
  return null;
}

/// 성가정 축일 — the Sunday within the Christmas octave (Dec 26–31), or Dec 30
/// when Christmas Day is itself a Sunday (no such Sunday exists).
DateTime _holyFamily(Temporale t) {
  final christmas = t.christmas;
  if (christmas.weekday == DateTime.sunday) {
    return DateTime(t.adventYear, 12, 30);
  }
  // First Sunday strictly after Christmas.
  return addDays(christmas, 7 - (christmas.weekday % 7));
}

/// The generic Sunday or ferial celebration for [d], used when no named
/// celebration applies.
Celebration genericTemporaleCelebration(DateTime d, SeasonInfo info) {
  final isSunday = d.weekday == DateTime.sunday;
  final title = koTemporalTitle(d);

  if (isSunday) {
    final privileged = info.season == Season.advent ||
        info.season == Season.lent ||
        info.season == Season.easter;
    return _temporale(
      'sunday',
      title,
      Rank.sunday,
      info.color,
      privileged ? PrecedenceCode.privilegedSolemnity : PrecedenceCode.sunday,
    );
  }

  // Privileged ferias: late Advent (Dec 17–24), Lenten weekdays, Easter octave.
  final privilegedFeria = (info.season == Season.advent && d.day >= 17) ||
      info.season == Season.lent ||
      (info.season == Season.easter && info.week == 1);
  return _temporale(
    'feria',
    title,
    privilegedFeria ? Rank.privilegedFeria : Rank.feria,
    info.color,
    privilegedFeria ? PrecedenceCode.privilegedWeekday : PrecedenceCode.weekday,
  );
}

/// The Proper-of-Time celebration on [d] (named solemnity/feast, else generic).
Celebration temporaleCelebrationOn(DateTime d, CalendarAdaptation adaptation) {
  final t = Temporale.containing(d);
  return namedTemporaleCelebration(d, t, adaptation) ??
      genericTemporaleCelebration(d, t.resolve(d));
}
