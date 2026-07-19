import 'package:shared_preferences/shared_preferences.dart';

import '../model/calendar_event.dart';
import '../model/event_category.dart';
import 'category_repository.dart';
import 'event_repository.dart';

class PersonalDataSnapshot {
  const PersonalDataSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required this.events,
    required this.categories,
    required this.categoriesSeeded,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, List<CalendarEvent>> events;
  final List<EventCategory> categories;
  final bool categoriesSeeded;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'events': {
      for (final entry in events.entries)
        entry.key: [for (final event in entry.value) event.toJson()],
    },
    'categories': [for (final category in categories) category.toJson()],
    'categoriesSeeded': categoriesSeeded,
  };

  factory PersonalDataSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion != 1) {
      throw const FormatException('unsupported_personal_data_schema');
    }

    final eventsJson = json['events'] as Map<String, dynamic>? ?? const {};
    return PersonalDataSnapshot(
      schemaVersion: schemaVersion,
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      events: {
        for (final entry in eventsJson.entries)
          entry.key: [
            for (final raw in (entry.value as List? ?? const []))
              CalendarEvent.fromJson(raw as Map<String, dynamic>),
          ],
      },
      categories: [
        for (final raw in (json['categories'] as List? ?? const []))
          EventCategory.fromJson(raw as Map<String, dynamic>),
      ],
      categoriesSeeded: json['categoriesSeeded'] as bool? ?? false,
    );
  }
}

class PersonalDataBackupRepository {
  PersonalDataBackupRepository(this._prefs)
    : _events = EventRepository(_prefs),
      _categories = CategoryRepository(_prefs);

  final SharedPreferences _prefs;
  final EventRepository _events;
  final CategoryRepository _categories;

  PersonalDataSnapshot exportSnapshot() {
    return PersonalDataSnapshot(
      schemaVersion: 1,
      exportedAt: DateTime.now().toUtc(),
      events: _events.load(),
      categories: _categories.load(),
      categoriesSeeded:
          _prefs.getBool(CategoryRepository.seededStorageKey) ?? false,
    );
  }

  Future<void> restoreSnapshot(PersonalDataSnapshot snapshot) async {
    await _events.save(snapshot.events);
    await _categories.save(snapshot.categories);
    await _prefs.setBool(
      CategoryRepository.seededStorageKey,
      snapshot.categoriesSeeded,
    );
  }
}
