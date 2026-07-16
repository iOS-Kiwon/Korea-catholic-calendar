/// The fully resolved liturgical information for a single calendar day —
/// the primary value returned by the engine to the UI.
library;

import 'package:meta/meta.dart';

import 'celebration.dart';
import 'enums.dart';

@immutable
class LiturgicalDay {
  const LiturgicalDay({
    required this.date,
    required this.season,
    required this.seasonWeek,
    required this.color,
    required this.celebration,
    required this.title,
    required this.sundayCycle,
    required this.weekdayCycle,
    this.alternativeColors = const [],
    this.optionalMemorials = const [],
    this.commemorations = const [],
    this.isHolyDayOfObligation = false,
    this.scriptureReadings = const [],
    this.specialDay,
    this.sourceUrl,
  });

  /// Date-only value (time normalized away).
  final DateTime date;

  final Season season;

  /// Week number within the season, or `null` where numbering does not apply.
  final int? seasonWeek;

  /// Resolved color of the winning celebration for this day.
  final LiturgicalColor color;

  /// Additional permitted colors (e.g. 장미색 on Gaudete/Laetare, 흑색 on 위령의 날).
  final List<LiturgicalColor> alternativeColors;

  /// The highest-precedence celebration observed on this day.
  final Celebration celebration;

  /// Optional memorials that may be celebrated instead (선택 기념일).
  final List<Celebration> optionalMemorials;

  /// Celebrations suppressed by precedence but still commemorated.
  final List<Celebration> commemorations;

  final SundayCycle sundayCycle;
  final WeekdayCycle weekdayCycle;

  /// Whether this is a holy day of obligation in Korea (Sundays + a short list).
  final bool isHolyDayOfObligation;

  /// Display title for the day (the winning celebration's name).
  final String title;

  /// Scripture reading citations for the day (e.g. `마태 5,1-12`), when known.
  /// References only — never the reading text (copyright). Empty when the engine
  /// computes the day without an authoritative source.
  final List<String> scriptureReadings;

  /// Special observance overlaid on the day (e.g. `교황 주일`, `농민 주일`), if any.
  final String? specialDay;

  /// Deep link to the authoritative source for this day (매일미사), if any.
  final String? sourceUrl;

  bool get isSunday => date.weekday == DateTime.sunday;

  LiturgicalDay copyWith({
    LiturgicalColor? color,
    List<LiturgicalColor>? alternativeColors,
    Celebration? celebration,
    List<Celebration>? optionalMemorials,
    String? title,
    List<String>? scriptureReadings,
    String? specialDay,
    String? sourceUrl,
  }) {
    return LiturgicalDay(
      date: date,
      season: season,
      seasonWeek: seasonWeek,
      color: color ?? this.color,
      alternativeColors: alternativeColors ?? this.alternativeColors,
      celebration: celebration ?? this.celebration,
      optionalMemorials: optionalMemorials ?? this.optionalMemorials,
      commemorations: commemorations,
      sundayCycle: sundayCycle,
      weekdayCycle: weekdayCycle,
      isHolyDayOfObligation: isHolyDayOfObligation,
      title: title ?? this.title,
      scriptureReadings: scriptureReadings ?? this.scriptureReadings,
      specialDay: specialDay ?? this.specialDay,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  @override
  String toString() =>
      'LiturgicalDay(${date.toIso8601String().split('T').first}, '
      '$title, $season, $color)';
}
