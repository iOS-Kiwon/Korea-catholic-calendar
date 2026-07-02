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

  bool get isSunday => date.weekday == DateTime.sunday;

  @override
  String toString() =>
      'LiturgicalDay(${date.toIso8601String().split('T').first}, '
      '$title, $season, $color)';
}
