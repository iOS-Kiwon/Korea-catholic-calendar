import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/application/event_providers.dart'
    show sharedPreferencesProvider;

const _storageKey = 'show_liturgical_year_cycle';

/// 메인 월 제목에 가해/나해/다해를 표시할지 여부.
/// 기본값은 기존 UI를 유지하도록 false다.
final showLiturgicalYearCycleProvider =
    NotifierProvider<LiturgicalYearCycleDisplayController, bool>(
      LiturgicalYearCycleDisplayController.new,
    );

class LiturgicalYearCycleDisplayController extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!ref.mounted) return;
    state = prefs.getBool(_storageKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_storageKey, value);
  }
}
