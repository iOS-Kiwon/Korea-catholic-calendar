import '../application/recurrence_expander.dart';
import '../model/calendar_event.dart';

/// Schedules on-device (local) reminders for personal events.
///
/// "Local" means the OS itself fires the notification at the scheduled time —
/// no push server, no network, no APNs/FCM. Mobile-only; web/desktop use a
/// no-op implementation (see [createNotificationService]).
abstract class NotificationService {
  /// Prepares the platform plugin, timezone database and permissions.
  /// Safe to call more than once.
  Future<void> init();

  /// Whether the app can currently display notifications.
  Future<bool> areNotificationsEnabled();

  /// Opens this app's system notification/settings screen when available.
  Future<void> openNotificationSettings();

  /// Reconciles all scheduled reminders with [events]: cancels everything and
  /// re-schedules future reminders (day-before 21:00 + day-of). Called on
  /// startup and after every add/update/delete so the OS schedule always
  /// mirrors stored state.
  ///
  /// 반복 일정은 [expander]로 다음 몇 회차만 전개해 예약한다(무한 반복 대응).
  /// [expander]가 없으면 전례 축일(yearlyFeast) 반복은 이번 예약에서 생략된다
  /// (다른 반복 유형은 캘린더 없이도 전개됨).
  Future<void> sync(
    Map<String, List<CalendarEvent>> events, {
    RecurrenceExpander? expander,
  });
}
