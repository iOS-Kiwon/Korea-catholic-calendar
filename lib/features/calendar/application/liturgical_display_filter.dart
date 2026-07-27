import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../events/application/event_providers.dart' show sharedPreferencesProvider;

/// 달력 그리드에 전례일 텍스트를 얼마나 표시할지.
enum LiturgicalDisplayFilter {
  all, // 모든 전례일(평일 제외)
  feastsOnly, // 대축일/축일만(대축일 + 성인일)
  sundaysAndSolemnities, // 주일에 대축일만(모든 주일 + 대축일)
  none; // 표시 안함

  String get displayName => switch (this) {
    all => '모든 전례일',
    feastsOnly => '대축일/축일만',
    sundaysAndSolemnities => '주일에 대축일만',
    none => '표시 안함',
  };

  String get storageValue => name;

  static LiturgicalDisplayFilter? fromStorage(String? raw) {
    for (final v in LiturgicalDisplayFilter.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

final _sundayOrdinal = RegExp(r'^(연중|사순|부활|대림) 제(\d+)주일$');

/// 주일(id=sunday)의 "제N주일"에서 "주일"을 떼어 축약. 예: 연중 제17주일 -> 연중 제17.
/// 주일이 아니거나 패턴이 다르면 null.
String? sundayShortTitle(LiturgicalDay day) {
  if (day.celebration.id != 'sunday') return null;
  final m = _sundayOrdinal.firstMatch(day.title);
  if (m == null) return null;
  return '${m.group(1)} 제${m.group(2)}';
}

/// [filter]에서 [day]에 전례일 텍스트를 표시하는가.
bool showsLabelFor(LiturgicalDisplayFilter filter, LiturgicalDay day) {
  final rank = day.celebration.rank;
  switch (filter) {
    case LiturgicalDisplayFilter.none:
      return false;
    case LiturgicalDisplayFilter.all:
      return rank != Rank.feria;
    case LiturgicalDisplayFilter.feastsOnly:
      // 대축일 + 주님 축일(feastOfTheLord) + 성인일(sanctorale).
      // 성인 판정은 kind가 모든 연도에 안정적.
      return rank == Rank.solemnity ||
          rank == Rank.feastOfTheLord ||
          day.celebration.kind == CelebrationKind.sanctorale;
    case LiturgicalDisplayFilter.sundaysAndSolemnities:
      return day.date.weekday == DateTime.sunday || rank == Rank.solemnity;
  }
}

/// 그리드 셀에 실제로 보일 텍스트. 숨김이면 null.
/// 라벨: shortTitle -> 주일 축약 -> day.title 폴백.
String? gridLiturgicalLabel(
  LiturgicalDisplayFilter filter,
  String? shortTitle,
  LiturgicalDay day,
) {
  if (!showsLabelFor(filter, day)) return null;
  return shortTitle ?? sundayShortTitle(day) ?? day.title;
}

const _storageKey = 'liturgical_display_filter';

/// 전례일 표시 필터. SharedPreferences에 저장. 기본값 = 주일에 대축일만.
final liturgicalDisplayFilterProvider =
    NotifierProvider<LiturgicalDisplayFilterController, LiturgicalDisplayFilter>(
      LiturgicalDisplayFilterController.new,
    );

class LiturgicalDisplayFilterController
    extends Notifier<LiturgicalDisplayFilter> {
  @override
  LiturgicalDisplayFilter build() {
    _hydrate();
    return LiturgicalDisplayFilter.sundaysAndSolemnities;
  }

  Future<void> _hydrate() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!ref.mounted) return;
    final restored = LiturgicalDisplayFilter.fromStorage(
      prefs.getString(_storageKey),
    );
    if (restored != null && restored != state) state = restored;
  }

  Future<void> set(LiturgicalDisplayFilter value) async {
    state = value;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_storageKey, value.storageValue);
  }
}
