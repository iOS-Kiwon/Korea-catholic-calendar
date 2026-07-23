import 'package:catholic_calendar/features/app_update/app_update_providers.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:catholic_calendar/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AvailStore extends PersonalCloudBackupStore {
  @override
  Future<CloudBackupAvailability> checkAvailability() async =>
      CloudBackupAvailability.available;
}

class _UnsupportedStore extends PersonalCloudBackupStore {
  @override
  Future<CloudBackupAvailability> checkAvailability() async =>
      CloudBackupAvailability.unsupported;
}

Future<void> _pump(
  WidgetTester tester, {
  required bool updateAvailable,
  PersonalCloudBackupStore? store,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
        personalCloudBackupStoreProvider.overrideWithValue(store ?? _AvailStore()),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: '가톨릭 달력',
            packageName: 'com.sidore.catholiccalendar',
            version: '1.4.0',
            buildNumber: '1400',
          ),
        ),
        appUpdateAvailableProvider.overrideWith((ref) async => updateAvailable),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('약관·정책 섹션에 개인정보 처리방침만 있다', (tester) async {
    await _pump(tester, updateAvailable: false);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
    expect(find.text('이용약관'), findsNothing);
  });

  testWidgets('버전 Footer를 표시한다', (tester) async {
    await _pump(tester, updateAvailable: false);
    expect(find.text('버전 1.4.0 (빌드 1400)'), findsOneWidget);
    expect(find.textContaining('새로운 기능을 만나보세요'), findsNothing);
  });

  testWidgets('업데이트가 있으면 안내 문구를 표시한다', (tester) async {
    await _pump(tester, updateAvailable: true);
    expect(find.textContaining('새로운 기능을 만나보세요'), findsOneWidget);
  });

  testWidgets('백업 미지원(unsupported)이면 백업 섹션을 숨긴다', (tester) async {
    await _pump(
      tester,
      updateAvailable: false,
      store: _UnsupportedStore(),
    );
    expect(find.text('Google 백업'), findsNothing);
    expect(find.text('iCloud 백업'), findsNothing);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
  });
}
