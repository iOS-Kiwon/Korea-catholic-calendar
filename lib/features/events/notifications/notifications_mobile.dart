import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../model/calendar_event.dart';
import 'notification_service.dart';

/// iOS/Android: real on-device reminders via `flutter_local_notifications`.
/// (On desktop — also `dart.library.io` — everything is a safe no-op.)
NotificationService createNotificationService() => _LocalNotificationService();

/// The OS caps the number of pending scheduled notifications (iOS allows 64).
/// We never register more than this many, always the soonest ones.
const _maxScheduled = 60;

/// All-day reminders fire at 09:00 on the day, and 21:00 the evening before.
const _dayOfHour = 9;
const _dayBeforeHour = 21;

const _channelId = 'personal_events';
const _channelName = '일정 알림';
const _channelDescription = '내가 추가한 개인 일정 알림';
const _settingsChannel = MethodChannel('com.sidore.catholiccalendar/settings');

bool get _supported => Platform.isAndroid || Platform.isIOS;

class _LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  @override
  Future<void> init() async {
    await _ensureReady();
    await _requestPermissions();
  }

  Future<void> _ensureReady() async {
    if (!_supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Korean Catholic calendar → a sensible fallback if the device tz lookup
      // fails.
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      // We request permission explicitly in _requestPermissions().
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
    );
    _ready = true;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (!_supported) return false;
    if (!_ready) await _ensureReady();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<void> openNotificationSettings() async {
    if (!_supported) return;
    try {
      await _settingsChannel.invokeMethod<void>('openNotificationSettings');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to open notification settings: $e');
    }
  }

  @override
  Future<void> sync(Map<String, List<CalendarEvent>> events) async {
    if (!_supported) return;
    if (!_ready) await _ensureReady();

    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    final reminders = <_Reminder>[];
    for (final list in events.values) {
      for (final e in list) {
        if (!e.notify) continue;
        reminders.addAll(_remindersFor(e, now));
      }
    }
    reminders.sort((a, b) => a.when.compareTo(b.when));
    if (reminders.isEmpty) return;

    await _requestPermissions();
    if (!await areNotificationsEnabled()) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    var id = 0;
    for (final r in reminders.take(_maxScheduled)) {
      try {
        await _plugin.zonedSchedule(
          id: id++,
          title: r.title,
          body: r.body,
          scheduledDate: r.when,
          notificationDetails: details,
          // Inexact avoids requiring the Android 12+ SCHEDULE_EXACT_ALARM
          // permission; day-before/day-of reminders don't need second precision.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to schedule reminder: $e');
      }
    }
  }

  /// The future reminders for a single event: evening-before + day-of.
  Iterable<_Reminder> _remindersFor(CalendarEvent e, tz.TZDateTime now) {
    final date = parseEventDate(e.date);
    final int hour;
    final int minute;
    if (e.isAllDay) {
      hour = _dayOfHour;
      minute = 0;
    } else {
      final parts = e.time!.split(':');
      hour = int.tryParse(parts[0]) ?? _dayOfHour;
      minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    }

    final timeLabel = e.isAllDay ? '종일' : e.time!;
    final suffix = (e.memo != null && e.memo!.trim().isNotEmpty)
        ? ' · ${e.memo!.trim()}'
        : '';

    final dayOf = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final dayBefore = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day - 1,
      _dayBeforeHour,
      0,
    );

    final typeLabel = e.isSaintFeast ? '축일' : '일정';

    return [
      if (dayBefore.isAfter(now))
        _Reminder(dayBefore, '내일 $typeLabel · ${e.title}', '$timeLabel$suffix'),
      if (dayOf.isAfter(now))
        _Reminder(dayOf, '오늘 $typeLabel · ${e.title}', '$timeLabel$suffix'),
    ];
  }
}

class _Reminder {
  const _Reminder(this.when, this.title, this.body);
  final tz.TZDateTime when;
  final String title;
  final String body;
}
