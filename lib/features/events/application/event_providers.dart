import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/event_repository.dart';
import '../model/calendar_event.dart';
import '../model/event_category.dart';
import '../notifications/notifications.dart';

/// The device's [SharedPreferences] instance (loaded once).
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// The local-notification service (real on mobile, no-op on web/desktop).
/// Overridable in tests to avoid touching platform channels.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => createNotificationService(),
);

/// The on-device store of personal events, keyed by `YYYY-MM-DD`.
///
/// Loads from [SharedPreferences] on build and reconciles scheduled reminders.
/// Every mutation persists and re-syncs notifications so the OS schedule always
/// mirrors stored state.
final eventStoreProvider =
    AsyncNotifierProvider<EventStore, Map<String, List<CalendarEvent>>>(
      EventStore.new,
    );

class EventStore extends AsyncNotifier<Map<String, List<CalendarEvent>>> {
  late EventRepository _repo;
  late NotificationService _notifications;

  @override
  Future<Map<String, List<CalendarEvent>>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    _repo = EventRepository(prefs);
    _notifications = ref.read(notificationServiceProvider);
    final map = _repo.load();
    // Re-register reminders with the OS (e.g. after reinstall). Skip entirely
    // when there are no events so we don't prompt for permission unprompted.
    if (map.isNotEmpty) {
      await _notifications.sync(map);
    }
    return map;
  }

  /// Adds a new event.
  Future<void> add(CalendarEvent event) async {
    final map = await _mutableMap();
    map.update(
      event.date,
      (list) => [...list, event],
      ifAbsent: () => [event],
    );
    await _persistAndSync(map);
  }

  /// Replaces the event with the same id (its date may have changed).
  Future<void> updateEvent(CalendarEvent event) async {
    final map = await _mutableMap();
    for (final key in map.keys.toList()) {
      final next = map[key]!.where((e) => e.id != event.id).toList();
      if (next.isEmpty) {
        map.remove(key);
      } else {
        map[key] = next;
      }
    }
    map.update(
      event.date,
      (list) => [...list, event],
      ifAbsent: () => [event],
    );
    await _persistAndSync(map);
  }

  /// Removes an event.
  Future<void> delete(CalendarEvent event) async {
    final map = await _mutableMap();
    final list = map[event.date];
    if (list == null) return;
    final next = list.where((e) => e.id != event.id).toList();
    if (next.isEmpty) {
      map.remove(event.date);
    } else {
      map[event.date] = next;
    }
    await _persistAndSync(map);
  }

  /// Propagates a category rename/recolor into the snapshot of every event that
  /// references it, so live category edits reflect in existing events. (Deleted
  /// categories are left untouched → events keep their last snapshot.)
  Future<void> applyCategory(EventCategory category) async {
    final map = await _mutableMap();
    var changed = false;
    for (final list in map.values) {
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (e.categoryId == category.id &&
            (e.categoryName != category.name ||
                e.categoryColor != category.color)) {
          list[i] = e.copyWith(
            categoryName: category.name,
            categoryColor: category.color,
          );
          changed = true;
        }
      }
    }
    if (changed) await _persistAndSync(map);
  }

  /// A deep-enough (per-date list) mutable copy of the current state, waiting
  /// for [build] to finish first so [_repo]/[_notifications] are ready.
  Future<Map<String, List<CalendarEvent>>> _mutableMap() async {
    final current = await future;
    return {for (final e in current.entries) e.key: [...e.value]};
  }

  Future<void> _persistAndSync(Map<String, List<CalendarEvent>> map) async {
    await _repo.save(map);
    state = AsyncData(map);
    await _notifications.sync(map);
  }
}

int _compareEvents(CalendarEvent a, CalendarEvent b) {
  if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1; // 종일 먼저
  if (a.isAllDay && b.isAllDay) return 0;
  return a.time!.compareTo(b.time!);
}

/// The events on [date], all-day first then by time.
final eventsForDateProvider = Provider.family<List<CalendarEvent>, DateTime>((
  ref,
  date,
) {
  final map = ref.watch(eventStoreProvider).value ?? const {};
  final list = [...?map[eventDateKey(date)]];
  list.sort(_compareEvents);
  return list;
});

/// The set of date keys (`YYYY-MM-DD`) that have at least one event, for grid
/// markers.
final datesWithEventsProvider = Provider<Set<String>>((ref) {
  final map = ref.watch(eventStoreProvider).value ?? const {};
  return {
    for (final entry in map.entries)
      if (entry.value.isNotEmpty) entry.key,
  };
});
