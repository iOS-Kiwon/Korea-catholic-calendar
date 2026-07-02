// Dev-time importer for the official CBCK 매일미사 liturgical calendar.
//
// Fetches https://missa.cbck.or.kr/MissaLoad?start=..&end=.. for a range of
// years and writes a compact, offline dataset to
// assets/calendar/cbck_days.json. The app ships this static snapshot (works on
// web and mobile, no CORS, no runtime dependency) and falls back to the
// computed engine for dates outside the imported range.
//
// Only scripture *citations* (references) are stored — never reading text
// (copyright). Run:  dart run tool/import_cbck.dart 2025 2027
import 'dart:convert';
import 'dart:io';

const _base = 'https://missa.cbck.or.kr';

const _colorByTag = {
  '녹': 'green',
  '홍': 'red',
  '백': 'white',
  '자': 'violet',
  '장': 'rose',
  '흑': 'black',
};

String _stripTags(String s) =>
    s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(' ', ' ').trim();

String? _tagColor(String segment) {
  final m = RegExp(r'\[(.)\]').firstMatch(segment);
  return m == null ? null : _colorByTag[m.group(1)];
}

String _stripLeadingTag(String segment) =>
    segment.replaceFirst(RegExp(r'^\s*\[.\]\s*'), '').trim();

/// Removes a trailing mass qualifier (e.g. `- 밤 미사`, `- 전야 미사`) so the day
/// cell shows the clean celebration name.
String _cleanTitle(String s) =>
    s.replaceFirst(RegExp(r'\s*-\s*[^-]*(미사|성야)\s*$'), '').trim();

Map<String, dynamic> _parseEntry(Map<String, dynamic> e) {
  final titleHtml = (e['title_html'] as String? ?? e['title'] as String? ?? '');
  final segments = titleHtml.split('또는');
  final primary = _stripTags(segments.first);
  final title = _cleanTitle(_stripLeadingTag(primary));
  final color = _tagColor(primary) ?? 'green';

  final alternatives = <Map<String, String>>[];
  for (final seg in segments.skip(1)) {
    final cleaned = _stripTags(seg);
    if (cleaned.isEmpty) continue;
    alternatives.add({
      'name': _stripLeadingTag(cleaned),
      'color': _tagColor(cleaned) ?? 'white',
    });
  }

  final readings = <String>[
    for (final r in (e['goodnews'] as String? ?? '').split('<br />'))
      if (_stripTags(r).isNotEmpty) _stripTags(r),
  ];

  final special = (e['special'] as String? ?? '').trim();
  final url = (e['url'] as String? ?? '').trim();

  return {
    'date': e['start'],
    'color': color,
    'title': title,
    if (special.isNotEmpty) 'special': special,
    if (readings.isNotEmpty) 'readings': readings,
    if (alternatives.isNotEmpty) 'alternatives': alternatives,
    if (url.isNotEmpty) 'url': url.startsWith('http') ? url : '$_base$url',
  };
}

Future<List<dynamic>> _fetch(
  HttpClient client,
  String start,
  String end,
) async {
  final uri = Uri.parse('$_base/MissaLoad?start=$start&end=$end');
  final req = await client.getUrl(uri);
  req.headers.set('x-requested-with', 'XMLHttpRequest');
  req.headers.set('accept', 'application/json');
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  if (resp.statusCode != 200) {
    throw HttpException('HTTP ${resp.statusCode} for $uri');
  }
  return jsonDecode(body) as List<dynamic>;
}

Future<void> main(List<String> args) async {
  final startYear = args.isNotEmpty ? int.parse(args[0]) : 2025;
  final endYear = args.length > 1 ? int.parse(args[1]) : 2027;

  final client = HttpClient();
  final byDate = <String, Map<String, dynamic>>{};
  try {
    for (var y = startYear; y <= endYear; y++) {
      stdout.writeln('Fetching $y …');
      final entries = await _fetch(client, '$y-01-01', '$y-12-31');
      for (final e in entries.cast<Map<String, dynamic>>()) {
        final parsed = _parseEntry(e);
        // Keep the first entry per date (the day's own celebration; later
        // entries are anticipated/vigil masses).
        byDate.putIfAbsent(parsed['date'] as String, () => parsed);
      }
      stdout.writeln('  ${entries.length} entries');
    }
  } finally {
    client.close();
  }

  final days = byDate.values.toList()
    ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

  final out = {
    'source': 'missa.cbck.or.kr',
    'range': {'start': '$startYear-01-01', 'end': '$endYear-12-31'},
    'note': '전례일 명칭·전례색·특별 주일·성경 구절 참조(본문 아님)·매일미사 링크. 개발 시점 임포트 스냅샷.',
    'days': days,
  };

  final file = File('assets/calendar/cbck_days.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('Wrote ${days.length} days to ${file.path}');
}
