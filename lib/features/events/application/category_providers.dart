import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/category_log_service.dart';
import '../data/category_repository.dart';
import '../model/category_palette.dart';
import '../model/event_category.dart';
import 'event_providers.dart';

/// The user's ordered event categories (on-device only). Seeds a starter set on
/// first run. New categories persist immediately ([add]); edit-mode changes are
/// committed in one shot ([replaceAll]).
final categoriesProvider =
    AsyncNotifierProvider<CategoryStore, List<EventCategory>>(
      CategoryStore.new,
    );

class CategoryStore extends AsyncNotifier<List<EventCategory>> {
  late CategoryRepository _repo;
  late SharedPreferences _prefs;

  /// Marks that seeding has happened, so deleting every category does not
  /// re-seed the defaults.
  @override
  Future<List<EventCategory>> build() async {
    _prefs = await ref.watch(sharedPreferencesProvider.future);
    _repo = CategoryRepository(_prefs);
    var list = _repo.load();
    final seeded = _prefs.getBool(CategoryRepository.seededStorageKey) ?? false;
    if (!seeded && list.isEmpty) {
      list = [...kDefaultCategories];
      await _repo.save(list);
      await _prefs.setBool(CategoryRepository.seededStorageKey, true);
    }
    return list;
  }

  /// Adds a new category (immediate persist). Used by the picker's "add".
  Future<EventCategory> add(String name, int color) async {
    final category = EventCategory(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      color: color,
    );
    await _persist([...await future, category]);
    unawaited(
      ref
          .read(categoryLogServiceProvider)
          .logCategoryAdded(name: category.name, color: category.color),
    );
    return category;
  }

  /// Commits the full edited list at once (rename/recolor/reorder/delete):
  /// persists it, then propagates any name/color changes into existing events.
  Future<void> replaceAll(List<EventCategory> next) async {
    final prev = {for (final c in await future) c.id: c};
    await _persist(next);
    for (final c in next) {
      final old = prev[c.id];
      if (old != null && (old.name != c.name || old.color != c.color)) {
        await ref.read(eventStoreProvider.notifier).applyCategory(c);
      }
    }
  }

  Future<void> _persist(List<EventCategory> list) async {
    await _repo.save(list);
    await _prefs.setBool(CategoryRepository.seededStorageKey, true);
    state = AsyncData(list);
  }
}

/// Categories indexed by id, for quick lookup.
final categoryMapProvider = Provider<Map<String, EventCategory>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in list) c.id: c};
});

/// The set of category ids currently used by at least one event. Used to block
/// deletion of in-use categories.
final inUseCategoryIdsProvider = Provider<Set<String>>((ref) {
  final events = ref.watch(eventStoreProvider).value ?? const {};
  return {
    for (final list in events.values)
      for (final e in list) e.categoryId,
  };
});
