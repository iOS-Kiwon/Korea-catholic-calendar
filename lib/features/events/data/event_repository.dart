import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/calendar_event.dart';

/// On-device persistence for personal events.
///
/// Everything lives under a single [SharedPreferences] key as a JSON object of
/// `{ "YYYY-MM-DD": [event, ...] }`. The dataset is small, so we read/write the
/// whole map at once. No cloud, no device-calendar sync.
class EventRepository {
  EventRepository(this._prefs);

  final SharedPreferences _prefs;

  static const storageKey = 'events_v1';

  /// Reads the full date-keyed event map. Empty when nothing is stored or the
  /// stored value is unreadable.
  Map<String, List<CalendarEvent>> load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<CalendarEvent>>{};
      doc.forEach((date, list) {
        result[date] = [
          for (final e in (list as List))
            CalendarEvent.fromJson(e as Map<String, dynamic>),
        ];
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Persists the full date-keyed event map. An empty map clears the store.
  Future<void> save(Map<String, List<CalendarEvent>> map) async {
    if (map.isEmpty) {
      await _prefs.remove(storageKey);
      return;
    }
    final doc = <String, dynamic>{
      for (final entry in map.entries)
        entry.key: [for (final e in entry.value) e.toJson()],
    };
    await _prefs.setString(storageKey, jsonEncode(doc));
  }
}
