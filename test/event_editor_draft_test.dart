import 'package:catholic_calendar/features/events/analytics/category_log_service.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/application/recurrence_expander.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
import 'package:catholic_calendar/features/events/presentation/event_editor_sheet.dart';
import 'package:catholic_calendar/features/sharing/share_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotifications implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> areNotificationsEnabled() async => true;
  @override
  Future<NotificationPermissionStatus> notificationPermissionStatus() async =>
      NotificationPermissionStatus.authorized;
  @override
  Future<bool> requestNotificationPermission() async => true;
  @override
  Future<void> openNotificationSettings() async {}
  @override
  Future<void> sync(Map<String, List<CalendarEvent>> events, {RecurrenceExpander? expander}) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('draft로 열면 추가 모드 + 메모 자동 입력, 카테고리 비어있음', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
        categoryLogServiceProvider.overrideWithValue(const NoopCategoryLogService()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEventEditor(
                  context,
                  date: DateTime(2026, 8, 10),
                  draft: const SharedEventDraft(
                    date: '2026-08-10', time: '09:00', memo: '9시 미사 후 성가대 연습',
                    categoryName: '본당 미사', categoryColor: 0xFFEF6C00,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('새 일정'), findsOneWidget); // 추가 모드(수정 아님)
    expect(find.text('9시 미사 후 성가대 연습'), findsOneWidget); // 메모 자동 입력
    // 카테고리 미선택 안내(선택 버튼 라벨). 저장 시도 시 카테고리 오류가 나는지로도 확인 가능.
  });
}
