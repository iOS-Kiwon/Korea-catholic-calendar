import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/event_category.dart';

/// On-device persistence for the user's event categories.
///
/// Stored as an ordered JSON array under a single key; list order is the
/// user's chosen display order.
class CategoryRepository {
  CategoryRepository(this._prefs);

  final SharedPreferences _prefs;

  static const storageKey = 'categories_v1';
  static const seededStorageKey = 'categories_seeded_v1';

  /// Reads the ordered category list. Empty when nothing is stored or the
  /// stored value is unreadable.
  List<EventCategory> load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final c in list) EventCategory.fromJson(c as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Persists the ordered category list. An empty list clears the store.
  Future<void> save(List<EventCategory> categories) async {
    if (categories.isEmpty) {
      await _prefs.remove(storageKey);
      return;
    }
    await _prefs.setString(
      storageKey,
      jsonEncode([for (final c in categories) c.toJson()]),
    );
  }
}
