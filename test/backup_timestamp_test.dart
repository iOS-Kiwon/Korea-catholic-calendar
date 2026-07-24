import 'package:catholic_calendar/features/events/application/category_providers.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/analytics/category_log_service.dart';
import 'package:catholic_calendar/features/events/data/backup_prefs.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotifications implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> areNotificationsEnabled() async => true;
  @override
  Future<void> openNotificationSettings() async {}
  @override
  Future<void> sync(Map<String, List<CalendarEvent>> events) async {}
}

class _RecordingBackupStore extends PersonalCloudBackupStore {
  int saveCount = 0;
  @override
  Future<bool> saveSnapshotJson(
    String snapshotJson, {
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async {
    saveCount += 1;
    return true;
  }
}

CalendarEvent _event() => const CalendarEvent(
  id: 'e1',
  date: '2026-07-16',
  categoryId: 'cat-1',
  categoryName: '미사',
  categoryColor: 0xFF2E7D32,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('backupNow가 성공하면 마지막 백업 시각을 기록한다', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        personalCloudBackupStoreProvider.overrideWithValue(
          _RecordingBackupStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(BackupPrefs.readInstant(prefs, BackupPrefs.lastBackupAtKey), isNull);
    await container.read(personalCloudBackupControllerProvider).backupNow();
    expect(
      BackupPrefs.readInstant(prefs, BackupPrefs.lastBackupAtKey),
      isNotNull,
    );
  });

  test('일정 추가는 더 이상 자동 백업을 호출하지 않는다', () async {
    final store = _RecordingBackupStore();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
        categoryLogServiceProvider.overrideWithValue(
          const NoopCategoryLogService(),
        ),
        personalCloudBackupStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(eventStoreProvider.future);

    await container.read(eventStoreProvider.notifier).add(_event());

    expect(store.saveCount, 0);
  });

  test('카테고리 추가도 자동 백업을 호출하지 않는다', () async {
    final store = _RecordingBackupStore();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
        categoryLogServiceProvider.overrideWithValue(
          const NoopCategoryLogService(),
        ),
        personalCloudBackupStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(categoriesProvider.future);

    await container.read(categoriesProvider.notifier).add('테스트', 0xFF2E7D32);

    expect(store.saveCount, 0);
  });
}
