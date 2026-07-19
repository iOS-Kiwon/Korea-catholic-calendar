import 'dart:convert';

import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/data/category_repository.dart';
import 'package:catholic_calendar/features/events/data/event_repository.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/event_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePersonalCloudBackupStore extends PersonalCloudBackupStore {
  FakePersonalCloudBackupStore({this.remoteSnapshotJson});

  String? remoteSnapshotJson;
  String? savedSnapshotJson;

  @override
  Future<String?> loadSnapshotJson() async => remoteSnapshotJson;

  @override
  Future<bool> saveSnapshotJson(String snapshotJson) async {
    savedSnapshotJson = snapshotJson;
    return true;
  }
}

CalendarEvent _event({required String id, required String date}) =>
    CalendarEvent(
      id: id,
      date: date,
      categoryId: 'cat-1',
      categoryName: '미사',
      categoryColor: 0xFF2E7D32,
    );

void main() {
  test('backs up the local personal-data snapshot to cloud storage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await EventRepository(prefs).save({
      '2026-07-19': [_event(id: '1', date: '2026-07-19')],
    });
    await CategoryRepository(
      prefs,
    ).save(const [EventCategory(id: 'cat-1', name: '미사', color: 0xFF2E7D32)]);
    await prefs.setBool(CategoryRepository.seededStorageKey, true);

    final fakeStore = FakePersonalCloudBackupStore();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        personalCloudBackupStoreProvider.overrideWithValue(fakeStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(personalCloudBackupControllerProvider).backupNow();

    final saved =
        jsonDecode(fakeStore.savedSnapshotJson!) as Map<String, dynamic>;
    expect(saved['schemaVersion'], 1);
    expect(
      (saved['events'] as Map<String, dynamic>)['2026-07-19'],
      hasLength(1),
    );
    expect(saved['categoriesSeeded'], isTrue);
  });

  test('restores a cloud snapshot into local personal-data storage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final remoteSnapshot = jsonEncode({
      'schemaVersion': 1,
      'exportedAt': '2026-07-19T00:00:00.000Z',
      'events': {
        '2026-07-19': [_event(id: 'remote-1', date: '2026-07-19').toJson()],
      },
      'categories': [
        const EventCategory(
          id: 'cat-1',
          name: '미사',
          color: 0xFF2E7D32,
        ).toJson(),
      ],
      'categoriesSeeded': true,
    });

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        personalCloudBackupStoreProvider.overrideWithValue(
          FakePersonalCloudBackupStore(remoteSnapshotJson: remoteSnapshot),
        ),
      ],
    );
    addTearDown(container.dispose);

    final restored = await container
        .read(personalCloudBackupControllerProvider)
        .restoreIfAvailable();

    expect(restored, isTrue);
    expect(EventRepository(prefs).load()['2026-07-19'], hasLength(1));
    expect(CategoryRepository(prefs).load().single.name, '미사');
    expect(prefs.getBool(CategoryRepository.seededStorageKey), isTrue);
  });
}
