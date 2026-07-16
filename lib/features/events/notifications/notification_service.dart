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

  /// Reconciles all scheduled reminders with [events]: cancels everything and
  /// re-schedules future reminders (day-before 21:00 + day-of). Called on
  /// startup and after every add/update/delete so the OS schedule always
  /// mirrors stored state.
  Future<void> sync(Map<String, List<CalendarEvent>> events);
}
