import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:catholic_calendar/features/settings/presentation/backup_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AvailStore extends PersonalCloudBackupStore {
  _AvailStore(this._availability, {this.setupSucceeds = false});
  CloudBackupAvailability _availability;
  final bool setupSucceeds;
  bool? lastPromptIfNeeded;

  @override
  Future<CloudBackupAvailability> checkAvailability() async => _availability;

  @override
  Future<bool> promptSetup() async {
    if (setupSucceeds) {
      _availability = CloudBackupAvailability.available;
    }
    return setupSucceeds;
  }

  @override
  Future<bool> saveSnapshotJson(
    String snapshotJson, {
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async {
    lastPromptIfNeeded = promptIfNeeded;
    return true;
  }
}

Future<_AvailStore> _pump(
  WidgetTester tester,
  CloudBackupAvailability availability, {
  bool setupSucceeds = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = _AvailStore(availability, setupSucceeds: setupSucceeds);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        personalCloudBackupStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: BackupSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('설정 필요 상태면 [설정하기]를 보여준다', (tester) async {
    await _pump(tester, CloudBackupAvailability.notConfigured);
    expect(find.text('설정하기'), findsOneWidget);
  });

  testWidgets('연결된 상태면 지금 백업/복원을 보여준다', (tester) async {
    await _pump(tester, CloudBackupAvailability.available);
    expect(find.text('지금 백업'), findsOneWidget);
    expect(find.text('복원'), findsOneWidget);
  });

  testWidgets('설정 완료 후 명시적 권한 요청으로 백업한다', (tester) async {
    final store = await _pump(
      tester,
      CloudBackupAvailability.notConfigured,
      setupSucceeds: true,
    );

    await tester.tap(find.text('설정하기'));
    await tester.pumpAndSettle();

    expect(store.lastPromptIfNeeded, isTrue);
    expect(find.text('지금 백업'), findsOneWidget);
  });
}
