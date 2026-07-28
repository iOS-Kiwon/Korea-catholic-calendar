import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../application/recurrence_expander.dart';
import '../model/calendar_event.dart';
import 'notification_service.dart';

/// iOS/Android: real on-device reminders via `flutter_local_notifications`.
/// (On desktop — also `dart.library.io` — everything is a safe no-op.)
NotificationService createNotificationService() => _LocalNotificationService();

/// The OS caps the number of pending scheduled notifications (iOS allows 64).
/// We never register more than this many, always the soonest ones.
const _maxScheduled = 60;

/// 반복 일정은 무한이므로 이벤트당 "다음 몇 회차"만 예약한다(앱 실행 시 리필).
/// 회차×2건(전날+당일)이라 이벤트 하나가 슬롯을 독점하지 않게 낮게 유지.
const _maxOccurrencesPerEvent = 4;

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
  Future<void> sync(
    Map<String, List<CalendarEvent>> events, {
    RecurrenceExpander? expander,
  }) async {
    if (!_supported) return;
    if (!_ready) await _ensureReady();

    await _plugin.cancelAll();

    // expander가 없으면 캘린더 없는 전개(전례 축일 반복은 생략, 나머지는 정상).
    final exp = expander ?? const RecurrenceExpander(null);
    final now = tz.TZDateTime.now(tz.local);
    final reminders = <_Reminder>[];
    for (final list in events.values) {
      for (final e in list) {
        if (!e.notify) continue;
        reminders.addAll(_remindersFor(e, now, exp));
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

  /// 이벤트의 미래 알림들. 각 발생일(회차) x 선택된 리드마다 시각을 계산한다.
  Iterable<_Reminder> _remindersFor(
    CalendarEvent e,
    tz.TZDateTime now,
    RecurrenceExpander expander,
  ) {
    final timeLabel = e.isAllDay ? '종일' : e.time!;
    final suffix = (e.memo != null && e.memo!.trim().isNotEmpty)
        ? ' · ${e.memo!.trim()}'
        : '';
    final typeLabel = e.isSaintFeast ? '축일' : '일정';
    final title = '$typeLabel · ${e.title}';
    final body = '$timeLabel$suffix';

    // 발생일: 비반복은 앵커 1개, 반복은 오늘 이후 다음 K회차.
    final List<DateTime> occurrences = e.isRecurring
        ? expander.nextOccurrences(
            e,
            DateTime(now.year, now.month, now.day),
            _maxOccurrencesPerEvent,
          )
        : [parseEventDate(e.date)];

    final reminders = <_Reminder>[];
    for (final date in occurrences) {
      for (final lead in e.reminders) {
        final when = lead.reminderTime(date, e.time);
        if (when == null) continue; // 종일 + 분/시간 리드
        final tzWhen = tz.TZDateTime(
          tz.local,
          when.year,
          when.month,
          when.day,
          when.hour,
          when.minute,
        );
        if (tzWhen.isAfter(now)) reminders.add(_Reminder(tzWhen, title, body));
      }
    }
    return reminders;
  }
}

class _Reminder {
  const _Reminder(this.when, this.title, this.body);
  final tz.TZDateTime when;
  final String title;
  final String body;
}
