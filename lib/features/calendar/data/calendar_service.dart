import 'dart:convert';

import 'package:liturgical_calendar/liturgical_calendar.dart';

/// A parsed authoritative day from the CBCK snapshot.
class CbckDay {
  const CbckDay({
    required this.title,
    required this.color,
    this.special,
    this.url,
    this.readings = const [],
    this.alternatives = const [],
  });

  final String title;
  final LiturgicalColor color;
  final String? special;
  final String? url;
  final List<String> readings;
  final List<Celebration> alternatives;
}

const _colorByName = {
  'green': LiturgicalColor.green,
  'red': LiturgicalColor.red,
  'white': LiturgicalColor.white,
  'violet': LiturgicalColor.violet,
  'rose': LiturgicalColor.rose,
  'black': LiturgicalColor.black,
};

LiturgicalColor _color(String? name) =>
    _colorByName[name] ?? LiturgicalColor.green;

/// Serves liturgical days, preferring the authoritative CBCK snapshot and
/// falling back to the computed engine for dates the snapshot does not cover.
///
/// This is where the official data (exact 명칭·전례색·특별 주일·성경 구절 참조·
/// 매일미사 링크) is layered over the engine's structural output (전례 시기·주차·
/// 독서 주기·의무 축일), giving one enriched [LiturgicalDay].
class CalendarService {
  CalendarService({required this.engine, Map<String, CbckDay>? cbck})
    : _cbck = cbck ?? const {};

  final LiturgicalCalendar engine;
  final Map<String, CbckDay> _cbck;

  /// Whether the authoritative snapshot covers [date].
  bool hasAuthoritative(DateTime date) => _cbck.containsKey(_key(date));

  LiturgicalDay day(DateTime date) {
    final base = engine.day(date);
    final c = _cbck[_key(date)];
    if (c == null) return base;
    return base.copyWith(
      title: c.title,
      color: c.color,
      scriptureReadings: c.readings,
      specialDay: c.special,
      sourceUrl: c.url,
      optionalMemorials: c.alternatives.isNotEmpty
          ? c.alternatives
          : base.optionalMemorials,
    );
  }

  List<LiturgicalDay> month(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return [for (var i = 1; i <= last; i++) day(DateTime(year, month, i))];
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parses the `cbck_days.json` snapshot into a date-keyed map.
  static Map<String, CbckDay> parseSnapshot(String jsonStr) {
    final doc = jsonDecode(jsonStr) as Map<String, dynamic>;
    final days = (doc['days'] as List).cast<Map<String, dynamic>>();
    final map = <String, CbckDay>{};
    for (final d in days) {
      final alternatives = [
        for (final a in (d['alternatives'] as List? ?? const []))
          Celebration(
            id: 'cbck_alt',
            name: (a as Map<String, dynamic>)['name'] as String,
            rank: Rank.optionalMemorial,
            color: _color(a['color'] as String?),
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.optionalMemorial,
          ),
      ];
      map[d['date'] as String] = CbckDay(
        title: d['title'] as String,
        color: _color(d['color'] as String?),
        special: d['special'] as String?,
        url: d['url'] as String?,
        readings: (d['readings'] as List? ?? const []).cast<String>(),
        alternatives: alternatives,
      );
    }
    return map;
  }
}
