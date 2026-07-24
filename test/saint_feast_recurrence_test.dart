import 'package:catholic_calendar/features/events/analytics/category_log_service.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/application/recurrence_expander.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/recurrence.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
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
  Future<void> sync(
    Map<String, List<CalendarEvent>> events, {
    RecurrenceExpander? expander,
  }) async {}
}

CalendarEvent _feast(String date) => CalendarEvent(
  id: 'f1',
  date: date,
  categoryId: 'saint_feast',
  categoryName: '축일',
  categoryColor: kSaintFeastEventColor,
  type: CalendarEventType.saintFeast,
  saintName: '성 마르코',
  recurrence: RecurrenceType.yearlyDate,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
        categoryLogServiceProvider.overrideWithValue(
          const NoopCategoryLogService(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('축일(yearlyDate)은 매년 같은 월·일에 조회된다', () async {
    final c = container();
    await c.read(eventStoreProvider.future);
    await c.read(eventStoreProvider.notifier).add(_feast('2026-04-25'));

    expect(c.read(eventsForDateProvider(DateTime(2026, 4, 25))), hasLength(1));
    expect(c.read(eventsForDateProvider(DateTime(2027, 4, 25))), hasLength(1));
    expect(c.read(eventsForDateProvider(DateTime(2028, 4, 25))), hasLength(1));
    // 다른 날짜엔 안 뜬다.
    expect(c.read(eventsForDateProvider(DateTime(2027, 4, 24))), isEmpty);
  });

  test('하위호환: recurrence 없이 저장된 축일도 매년 반복으로 조회된다', () async {
    // 구버전(반복 필드 없음)으로 저장된 축일을 흉내낸 JSON.
    final legacy = CalendarEvent.fromJson({
      'id': 'legacy',
      'date': '2026-04-25',
      'categoryId': 'saint_feast',
      'categoryName': '축일',
      'type': 'saintFeast',
      'saintName': '성 마르코',
    });
    expect(legacy.recurrence, RecurrenceType.yearlyDate);

    final c = container();
    await c.read(eventStoreProvider.future);
    await c.read(eventStoreProvider.notifier).add(legacy);
    expect(c.read(eventsForDateProvider(DateTime(2027, 4, 25))), hasLength(1));
  });

  test('매년 반복 OFF(none)면 해당 연도 하루만 조회된다', () async {
    final c = container();
    await c.read(eventStoreProvider.future);
    await c
        .read(eventStoreProvider.notifier)
        .add(_feast('2026-04-25').copyWith(recurrence: RecurrenceType.none));
    expect(c.read(eventsForDateProvider(DateTime(2026, 4, 25))), hasLength(1));
    expect(c.read(eventsForDateProvider(DateTime(2027, 4, 25))), isEmpty);
  });

  test('편집으로 ON->OFF 끄면 다음 해부터 사라진다(올해는 유지)', () async {
    final c = container();
    await c.read(eventStoreProvider.future);
    final store = c.read(eventStoreProvider.notifier);
    await store.add(_feast('2026-04-25')); // 매년 반복 ON
    expect(c.read(eventsForDateProvider(DateTime(2027, 4, 25))), hasLength(1));

    // 편집: 같은 id로 매년 반복 OFF 저장.
    await store.updateEvent(
      _feast('2026-04-25').copyWith(recurrence: RecurrenceType.none),
    );
    expect(c.read(eventsForDateProvider(DateTime(2026, 4, 25))), hasLength(1));
    expect(c.read(eventsForDateProvider(DateTime(2027, 4, 25))), isEmpty);
  });
}
