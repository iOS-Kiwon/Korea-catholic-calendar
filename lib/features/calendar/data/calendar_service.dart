import 'dart:convert';

import 'package:liturgical_calendar/liturgical_calendar.dart';

/// A parsed authoritative day from the CBCK snapshot / gateway.
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

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Serves liturgical days, preferring authoritative CBCK data (bundled snapshot
/// and/or fetched from the gateway) and falling back to the computed engine.
///
/// CBCK data can be merged in per month at runtime ([merge]); [hasMonth] lets
/// callers avoid re-fetching a month that is already loaded.
class CalendarService {
  CalendarService({required this.engine, Map<String, CbckDay>? cbck})
    : _cbck = {...?cbck} {
    _recomputeMonths();
  }

  final LiturgicalCalendar engine;
  final Map<String, CbckDay> _cbck;
  final Set<String> _months = {}; // 'YYYY-MM' loaded
  final Map<String, DateTime?> _feastDateCache = {}; // 'id@year' -> date

  /// 전례 축일 키([celebrationId], 예: `'easter'`)에 해당하는 [year]의 날짜.
  /// 이동 축일 매년 반복(yearlyFeast) 전개에 쓰인다. 없으면 null. 결과는 캐시한다
  /// (위젯이 여러 해를 반복 조회하므로 필수).
  ///
  /// CBCK 데이터는 `title/color` 등만 덮어쓰고 `celebration.id`는 유지하므로,
  /// 엔진 계산 연도(폴백)든 공식 데이터 연도든 동일하게 동작한다.
  DateTime? feastDateInYear(String celebrationId, int year) {
    final key = '$celebrationId@$year';
    if (_feastDateCache.containsKey(key)) return _feastDateCache[key];
    DateTime? found;
    for (final d in engine.year(year)) {
      if (d.celebration.id == celebrationId) {
        found = DateTime(d.date.year, d.date.month, d.date.day);
        break;
      }
    }
    _feastDateCache[key] = found;
    return found;
  }

  void _recomputeMonths() {
    _months.clear();
    for (final k in _cbck.keys) {
      _months.add(k.substring(0, 7));
    }
  }

  /// Whether authoritative data for [year]/[month] is already loaded.
  bool hasMonth(int year, int month) =>
      _months.contains('$year-${_pad2(month)}');

  /// Merges additional authoritative days (e.g. fetched from the gateway).
  void merge(Map<String, CbckDay> more) {
    if (more.isEmpty) return;
    _cbck.addAll(more);
    _recomputeMonths();
  }

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
      '${_pad2(d.month)}-${_pad2(d.day)}';

  /// Parses the bundled `cbck_days.json` snapshot into a date-keyed map.
  static Map<String, CbckDay> parseSnapshot(String jsonStr) {
    final doc = jsonDecode(jsonStr) as Map<String, dynamic>;
    return parseDays(doc['days'] as List? ?? const []);
  }

  /// Parses a `days` array (bundled snapshot or gateway response) into a map.
  static Map<String, CbckDay> parseDays(List<dynamic> days) {
    final map = <String, CbckDay>{};
    for (final raw in days) {
      final d = raw as Map<String, dynamic>;
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
