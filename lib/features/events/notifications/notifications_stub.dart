import '../application/recurrence_expander.dart';
import '../model/calendar_event.dart';
import 'notification_service.dart';

/// Web/desktop: local notifications are unsupported, so everything is a no-op.
/// The rest of the app (add/edit/list events) works normally without reminders.
NotificationService createNotificationService() => _NoopNotificationService();

class _NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> sync(
    Map<String, List<CalendarEvent>> events, {
    RecurrenceExpander? expander,
  }) async {}
}
