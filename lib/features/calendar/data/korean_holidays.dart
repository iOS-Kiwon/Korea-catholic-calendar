import 'dart:convert';

/// 대한민국 관공서 공휴일 및 대체공휴일.
class KoreanHoliday {
  const KoreanHoliday({
    required this.id,
    required this.title,
    required this.isSubstitute,
    this.shortTitle,
  });

  final String id;
  final String title;
  final bool isSubstitute;
  final String? shortTitle;
}

/// `korean-holidays.snapshot.1900-2100.json`의 날짜별 공휴일 데이터를 읽는다.
Map<String, List<KoreanHoliday>> parseKoreanHolidays(String jsonString) {
  final document = jsonDecode(jsonString) as Map<String, dynamic>;
  final rawHolidays = document['holidays'] as Map<String, dynamic>? ?? {};
  final result = <String, List<KoreanHoliday>>{};

  for (final entry in rawHolidays.entries) {
    final items = entry.value as List? ?? const [];
    result[entry.key] = [
      for (final raw in items)
        if (raw is Map<String, dynamic>)
          KoreanHoliday(
            id: raw['id'] as String? ?? entry.key,
            title: raw['title'] as String? ?? '',
            isSubstitute: raw['isSubstitute'] as bool? ?? false,
            shortTitle: raw['shortTitle'] as String?,
          ),
    ];
  }

  return result;
}
