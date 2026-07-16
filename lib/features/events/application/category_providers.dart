import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/category_repository.dart';
import '../model/category_palette.dart';
import '../model/event_category.dart';
import 'event_providers.dart';

/// The user's ordered event categories (on-device only). Seeds a starter set on
/// first run; subsequent add/edit/delete/reorder persist immediately.
final categoriesProvider =
    AsyncNotifierProvider<CategoryStore, List<EventCategory>>(
      CategoryStore.new,
    );

class CategoryStore extends AsyncNotifier<List<EventCategory>> {
  late CategoryRepository _repo;
  late SharedPreferences _prefs;

  /// Marks that seeding has happened, so deleting every category does not
  /// re-seed the defaults.
  static const _seededKey = 'categories_seeded_v1';

  @override
  Future<List<EventCategory>> build() async {
    _prefs = await ref.watch(sharedPreferencesProvider.future);
    _repo = CategoryRepository(_prefs);
    var list = _repo.load();
    final seeded = _prefs.getBool(_seededKey) ?? false;
    if (!seeded && list.isEmpty) {
      list = [...kDefaultCategories];
      await _repo.save(list);
      await _prefs.setBool(_seededKey, true);
    }
    return list;
  }

  Future<EventCategory> add(String name, int color) async {
    final category = EventCategory(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      color: color,
    );
    await _persist([...await future, category]);
    return category;
  }

  Future<void> edit(String id, {required String name, required int color}) async {
    final list = [
      for (final c in await future)
        if (c.id == id) c.copyWith(name: name, color: color) else c,
    ];
    await _persist(list);
    // Propagate the rename/recolor into existing events' snapshots.
    await ref
        .read(eventStoreProvider.notifier)
        .applyCategory(EventCategory(id: id, name: name, color: color));
  }

  Future<void> delete(String id) async {
    await _persist([
      for (final c in await future)
        if (c.id != id) c,
    ]);
    // Events keep their snapshot (이름 보존) — no event mutation on delete.
  }

  /// Moves a category. [newIndex] is already adjusted for the removed item
  /// (called from `ReorderableListView.onReorderItem`).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...await future];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _persist(list);
  }

  Future<void> _persist(List<EventCategory> list) async {
    await _repo.save(list);
    await _prefs.setBool(_seededKey, true);
    state = AsyncData(list);
  }
}

/// Categories indexed by id, for quick lookup.
final categoryMapProvider = Provider<Map<String, EventCategory>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in list) c.id: c};
});
