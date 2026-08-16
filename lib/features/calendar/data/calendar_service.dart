import 'dart:convert';

import 'package:liturgical_calendar/liturgical_calendar.dart';

import 'liturgical_short_titles.dart';
import 'korean_holidays.dart';

/// A parsed authoritative day from the CBCK snapshot / gateway.
class CbckDay {
  const CbckDay({
    required this.title,
    required this.color,
    this.rank,
    this.special,
    this.url,
    this.saintInfoUrl,
    this.shortTitle,
    this.displayType,
    this.readings = const [],
    this.alternatives = const [],
  });

  final String title;
  final LiturgicalColor color;
  final Rank? rank;
  final String? special;
  final String? url;
  final String? saintInfoUrl;
  final String? shortTitle;
  final LiturgicalDisplayType? displayType;
  final List<String> readings;
  final List<Celebration> alternatives;

  CbckDay copyWith({
    String? title,
    LiturgicalColor? color,
    Rank? rank,
    String? special,
    String? url,
    String? saintInfoUrl,
    String? shortTitle,
    LiturgicalDisplayType? displayType,
    List<String>? readings,
    List<Celebration>? alternatives,
  }) {
    return CbckDay(
      title: title ?? this.title,
      color: color ?? this.color,
      rank: rank ?? this.rank,
      special: special ?? this.special,
      url: url ?? this.url,
      saintInfoUrl: saintInfoUrl ?? this.saintInfoUrl,
      shortTitle: shortTitle ?? this.shortTitle,
      displayType: displayType ?? this.displayType,
      readings: readings ?? this.readings,
      alternatives: alternatives ?? this.alternatives,
    );
  }

  CbckDay withFallbackDisplayFrom(CbckDay fallback) {
    return copyWith(
      shortTitle: shortTitle ?? fallback.shortTitle,
      displayType: displayType ?? fallback.displayType,
      alternatives: [
        for (var i = 0; i < alternatives.length; i++)
          alternatives[i].displayType == null
              ? alternatives[i].copyWith(
                  displayType: _fallbackAlternativeDisplayType(
                    fallback.alternatives,
                    i,
                    alternatives[i].name,
                  ),
                )
              : alternatives[i],
      ],
    );
  }
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
  CalendarService({
    required this.engine,
    Map<String, CbckDay>? cbck,
    Map<String, String>? shortTitles,
    Map<String, List<KoreanHoliday>>? koreanHolidays,
  }) : _cbck = {...?cbck},
       _shortTitles = {...kDefaultLiturgicalShortTitles, ...?shortTitles},
       _koreanHolidays = {...?koreanHolidays} {
    _recomputeMonths();
  }

  final LiturgicalCalendar engine;
  final Map<String, CbckDay> _cbck;
  final Map<String, String> _shortTitles;
  final Map<String, List<KoreanHoliday>> _koreanHolidays;
  final Set<String> _months = {}; // 'YYYY-MM' loaded
  final Map<String, DateTime?> _feastDateCache = {}; // 'id@year' -> date

  String? shortTitleFor(LiturgicalDay day) {
    final remote = _cbck[_key(day.date)]?.shortTitle?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return liturgicalShortTitleFromMap(_shortTitles, day);
  }

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

  /// 해당 날짜가 대한민국 국가 공휴일 또는 대체공휴일인지 여부.
  bool isKoreanHoliday(DateTime date) =>
      _koreanHolidays.containsKey(_key(date));

  /// 해당 국가 공휴일의 대표 제목. 공휴일이 없거나 제목이 비어 있으면 null.
  String? koreanHolidayTitleFor(DateTime date) {
    final holidays = _koreanHolidays[_key(date)];
    for (final holiday in holidays ?? const <KoreanHoliday>[]) {
      if (holiday.title.trim().isNotEmpty) return holiday.title;
    }
    return null;
  }

  /// Merges additional authoritative days (e.g. fetched from the gateway).
  void merge(Map<String, CbckDay> more) {
    if (more.isEmpty) return;
    for (final entry in more.entries) {
      final existing = _cbck[entry.key];
      _cbck[entry.key] = existing == null
          ? entry.value
          : entry.value.withFallbackDisplayFrom(existing);
    }
    _recomputeMonths();
  }

  LiturgicalDay day(DateTime date) {
    final base = engine.day(date);
    final c = _cbck[_key(date)];
    if (c == null) return base;
    final celebration = c.rank == null
        ? base.celebration.copyWith(
            name: c.title,
            color: c.color,
            displayType: c.displayType,
          )
        : base.celebration.copyWith(
            name: c.title,
            rank: c.rank,
            color: c.color,
            kind: _kindForCbckTitle(c.title, base.celebration.kind),
            precedence: _precedenceForRank(c.rank!),
            displayType: c.displayType,
          );
    return base.copyWith(
      title: c.title,
      color: c.color,
      celebration: celebration,
      scriptureReadings: c.readings,
      specialDay: c.special,
      sourceUrl: c.url,
      saintInfoUrl: c.saintInfoUrl,
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
            rank:
                _rank(a['rank'] as String?, a['name'] as String) ??
                Rank.optionalMemorial,
            color: _color(a['color'] as String?),
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.optionalMemorial,
            displayType: _displayType(a['displayType'] as String?),
          ),
      ];
      map[d['date'] as String] = CbckDay(
        title: d['title'] as String,
        color: _color(d['color'] as String?),
        rank: _rank(d['rank'] as String?, d['title'] as String),
        special: d['special'] as String?,
        url: d['url'] as String?,
        saintInfoUrl: d['saintInfoUrl'] as String?,
        shortTitle: d['shortTitle'] as String?,
        displayType: _displayType(d['displayType'] as String?),
        readings: (d['readings'] as List? ?? const []).cast<String>(),
        alternatives: alternatives,
      );
    }
    return map;
  }

  /// Applies `assets/calendar/liturgical_display_YYYY.json` rows to parsed CBCK
  /// days. Matching is date + source + sourceIndex based, so titles can still
  /// be used for human review without becoming the app's runtime heuristic.
  static Map<String, CbckDay> applyDisplayDataset(
    Map<String, CbckDay> cbck,
    String jsonStr,
  ) {
    final doc = jsonDecode(jsonStr) as Map<String, dynamic>;
    final result = {...cbck};
    for (final raw in doc['entries'] as List? ?? const []) {
      final entry = raw as Map<String, dynamic>;
      final date = entry['date'] as String?;
      if (date == null) continue;
      final day = result[date];
      if (day == null) continue;
      final displayType = _displayType(entry['displayType'] as String?);
      if (displayType == null) continue;

      switch (entry['source']) {
        case 'primary':
          result[date] = day.copyWith(displayType: displayType);
        case 'alternative':
          final index = entry['sourceIndex'] as int? ?? -1;
          if (index < 0 || index >= day.alternatives.length) continue;
          final alternatives = [...day.alternatives];
          alternatives[index] = alternatives[index].copyWith(
            displayType: displayType,
          );
          result[date] = day.copyWith(alternatives: alternatives);
      }
    }
    return result;
  }
}

LiturgicalDisplayType? _fallbackAlternativeDisplayType(
  List<Celebration> alternatives,
  int index,
  String name,
) {
  if (index >= 0 &&
      index < alternatives.length &&
      alternatives[index].name == name) {
    return alternatives[index].displayType;
  }
  for (final alternative in alternatives) {
    if (alternative.name == name) return alternative.displayType;
  }
  return null;
}

LiturgicalDisplayType? _displayType(String? raw) {
  switch (raw) {
    case 'liturgy':
      return LiturgicalDisplayType.liturgy;
    case 'saintFeast':
      return LiturgicalDisplayType.saintFeast;
    case 'review':
      return LiturgicalDisplayType.review;
  }
  return null;
}

Rank? _rank(String? raw, String title) {
  switch (raw) {
    case 'solemnity':
      return Rank.solemnity;
    case 'feastOfTheLord':
      return Rank.feastOfTheLord;
    case 'feast':
      return Rank.feast;
    case 'sunday':
      return Rank.sunday;
    case 'obligatoryMemorial':
      return Rank.obligatoryMemorial;
    case 'optionalMemorial':
      return Rank.optionalMemorial;
    case 'privilegedFeria':
      return Rank.privilegedFeria;
    case 'feria':
      return Rank.feria;
  }
  return _inferRankFromTitle(title);
}

Rank? _inferRankFromTitle(String title) {
  if (title.contains('대축일')) return Rank.solemnity;
  if (_isFeastOfTheLordTitle(title)) return Rank.feastOfTheLord;
  if (title.contains('축일')) return Rank.feast;
  if (title.contains('주일')) return Rank.sunday;
  if (title.contains('기념일')) return Rank.obligatoryMemorial;
  if (_looksLikeSaintTitle(title)) return Rank.optionalMemorial;
  if (_isPrivilegedFeriaTitle(title)) return Rank.privilegedFeria;
  return null;
}

bool _isFeastOfTheLordTitle(String title) {
  return (title.contains('주님') && title.contains('축일')) ||
      title.contains('예수, 마리아, 요셉의 성가정 축일') ||
      title.contains('라테라노 대성전 봉헌 축일');
}

bool _isPrivilegedFeriaTitle(String title) {
  return title == '재의 수요일' ||
      title.startsWith('성주간 ') ||
      title.contains('팔일 축제') ||
      RegExp(r'^12월 (1[7-9]|2[0-4])일$').hasMatch(title);
}

CelebrationKind _kindForCbckTitle(String title, CelebrationKind fallback) {
  if (_looksLikeSaintTitle(title) ||
      title.contains('복되신 동정 마리아') ||
      title.contains('모든 성인')) {
    return CelebrationKind.sanctorale;
  }
  return fallback;
}

bool _looksLikeSaintTitle(String title) {
  return title.startsWith('성 ') ||
      title.startsWith('성녀 ') ||
      title.startsWith('성인 ') ||
      title.startsWith('복자 ') ||
      title.startsWith('복녀 ') ||
      title.contains(' 성 ') ||
      title.contains(' 성녀 ') ||
      title.contains(' 복자 ') ||
      title.contains(' 복녀 ');
}

PrecedenceCode _precedenceForRank(Rank rank) {
  switch (rank) {
    case Rank.solemnity:
      return PrecedenceCode.generalSolemnity;
    case Rank.feastOfTheLord:
      return PrecedenceCode.feastOfTheLord;
    case Rank.feast:
      return PrecedenceCode.generalFeast;
    case Rank.sunday:
      return PrecedenceCode.sunday;
    case Rank.obligatoryMemorial:
      return PrecedenceCode.generalObligatoryMemorial;
    case Rank.optionalMemorial:
      return PrecedenceCode.optionalMemorial;
    case Rank.privilegedFeria:
      return PrecedenceCode.privilegedWeekday;
    case Rank.feria:
      return PrecedenceCode.weekday;
  }
}
