/// The public facade — assembles a fully resolved [LiturgicalDay] for any date.
library;

import 'core/reading_cycle.dart';
import 'core/season_resolver.dart';
import 'core/temporale.dart';
import 'data/default_dataset.dart';
import 'data/schema.dart';
import 'model/celebration.dart';
import 'model/enums.dart';
import 'model/liturgical_day.dart';
import 'model/precedence_code.dart';
import 'resolve/temporale_day.dart';

/// Computes the Korean Catholic liturgical calendar, fully offline.
///
/// Inject a [CalendarDataset] to use custom/updated data; when omitted the
/// built-in fallback dataset is used.
class LiturgicalCalendar {
  LiturgicalCalendar({CalendarDataset? dataset})
      : _dataset = dataset ?? buildDefaultDataset();

  final CalendarDataset _dataset;
  final Map<int, Map<DateTime, List<Celebration>>> _sanctoraleCache = {};

  /// The fully resolved liturgical day for [date] (time is ignored).
  LiturgicalDay day(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final t = Temporale.containing(d);
    final info = t.resolve(d);

    final temporaleCel = namedTemporaleCelebration(d, t, _dataset.adaptation) ??
        genericTemporaleCelebration(d, info);
    final sanctorale = _sanctoraleFor(d.year)[d] ?? const <Celebration>[];

    final candidates = <Celebration>[temporaleCel, ...sanctorale]
      ..sort((a, b) => a.precedence.index.compareTo(b.precedence.index));
    final winner = candidates.first;

    final optionalMemorials = [
      for (final c in candidates)
        if (!identical(c, winner) &&
            (c.precedence == PrecedenceCode.optionalMemorial ||
                c.precedence == PrecedenceCode.generalObligatoryMemorial ||
                c.precedence == PrecedenceCode.properObligatoryMemorial))
          c,
    ];

    final alternativeColors = <LiturgicalColor>[
      if (winner.kind == CelebrationKind.temporale &&
          winner.rank == Rank.sunday &&
          ((info.season == Season.advent && info.week == 3) ||
              (info.season == Season.lent && info.week == 4)))
        LiturgicalColor.rose,
    ];

    final isHolyDayOfObligation = d.weekday == DateTime.sunday ||
        _dataset.adaptation.holyDaysOfObligation.contains(winner.id);

    return LiturgicalDay(
      date: d,
      season: info.season,
      seasonWeek: info.week,
      color: winner.color,
      alternativeColors: alternativeColors,
      celebration: winner,
      optionalMemorials: optionalMemorials,
      sundayCycle: sundayCycleOn(d),
      weekdayCycle: weekdayCycleOn(d),
      isHolyDayOfObligation: isHolyDayOfObligation,
      title: winner.name,
    );
  }

  /// One [LiturgicalDay] per calendar day of [month] in [year] (1..last day).
  List<LiturgicalDay> month(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return [for (var i = 1; i <= last; i++) day(DateTime(year, month, i))];
  }

  /// Every day of the civil [year], Jan 1 – Dec 31.
  List<LiturgicalDay> year(int year) =>
      range(DateTime(year, 1, 1), DateTime(year, 12, 31));

  /// Every day in the inclusive range [from]..[to].
  List<LiturgicalDay> range(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final days = <LiturgicalDay>[];
    for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
      days.add(day(d));
    }
    return days;
  }

  // --- sanctorale placement (with solemnity transfers) ---

  Map<DateTime, List<Celebration>> _sanctoraleFor(int year) {
    return _sanctoraleCache.putIfAbsent(year, () {
      final map = <DateTime, List<Celebration>>{};
      for (final fc in _dataset.merged) {
        final observed = _placeSanctorale(fc, year);
        (map[observed] ??= []).add(fc.toCelebration());
      }
      return map;
    });
  }

  bool _isSolemnity(FixedCelebration fc) =>
      fc.precedence == PrecedenceCode.generalSolemnity ||
      fc.precedence == PrecedenceCode.properSolemnity;

  /// The date on which [fc] is actually observed in [year], applying the MVP
  /// transfer rules for solemnities that collide with a higher-precedence day.
  DateTime _placeSanctorale(FixedCelebration fc, int year) {
    final natural = fc.dateIn(year);
    final code = fc.precedence ?? PrecedenceCode.weekday;
    if (!_isSolemnity(fc)) return natural;

    final a = _dataset.adaptation;
    final t = Temporale.containing(natural);
    final palm = t.palmSundayDate;
    final octaveEnd = addDays(t.easter, 7); // 부활 제2주일

    // Holy Week or Easter octave → Monday after the Second Sunday of Easter.
    if (!natural.isBefore(palm) && !natural.isAfter(octaveEnd)) {
      return _nextFreeForSolemnity(addDays(t.easter, 8), code, a);
    }

    // Otherwise: if the day is outranked (privileged Sunday/season), bump on.
    final temporale = temporaleCelebrationOn(natural, a);
    if (temporale.precedence.outranks(code)) {
      return _nextFreeForSolemnity(addDays(natural, 1), code, a);
    }
    return natural;
  }

  DateTime _nextFreeForSolemnity(
      DateTime start, PrecedenceCode code, CalendarAdaptation a) {
    var d = start;
    for (var i = 0; i < 21; i++) {
      if (!temporaleCelebrationOn(d, a).precedence.outranks(code)) return d;
      d = addDays(d, 1);
    }
    return start;
  }
}
