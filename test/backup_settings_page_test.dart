import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:catholic_calendar/features/settings/presentation/backup_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AvailStore extends PersonalCloudBackupStore {
  _AvailStore(this._availability);
  final CloudBackupAvailability _availability;
  @override
  Future<CloudBackupAvailability> checkAvailability() async => _availability;
  @override
  Future<bool> saveSnapshotJson(String snapshotJson) async => true;
}

Future<void> _pump(
  WidgetTester tester,
  CloudBackupAvailability availability,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        personalCloudBackupStoreProvider.overrideWithValue(
          _AvailStore(availability),
        ),
      ],
      child: const MaterialApp(home: BackupSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
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
}
