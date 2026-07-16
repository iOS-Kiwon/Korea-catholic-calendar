String _pad2(int n) => n.toString().padLeft(2, '0');

/// The `YYYY-MM-DD` key for a date, matching the liturgical calendar's keys.
/// Normalizes away any time component.
String eventDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

/// Parses a `YYYY-MM-DD` key into a date at midnight local time.
DateTime parseEventDate(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// A user-created personal event stored on-device only.
///
/// Dates use the same `YYYY-MM-DD` key convention as the liturgical calendar
/// (`CalendarService`). [time] is an optional `HH:mm`; a null time means the
/// event is all-day.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.date,
    required this.title,
    this.memo,
    this.time,
    this.notify = true,
  });

  /// Stable local id (millis/micros-based; no external uuid dependency).
  final String id;

  /// The day the event belongs to, `YYYY-MM-DD`.
  final String date;

  /// Required, user-visible title.
  final String title;

  /// Optional free-form note.
  final String? memo;

  /// Optional time-of-day `HH:mm`; null = all-day.
  final String? time;

  /// Whether to schedule local reminders for this event.
  final bool notify;

  /// True when the event has no specific time (all-day).
  bool get isAllDay => time == null;

  CalendarEvent copyWith({
    String? id,
    String? date,
    String? title,
    String? memo,
    String? time,
    bool? notify,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      time: time ?? this.time,
      notify: notify ?? this.notify,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'title': title,
    if (memo != null) 'memo': memo,
    if (time != null) 'time': time,
    'notify': notify,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    date: json['date'] as String,
    title: json['title'] as String,
    memo: json['memo'] as String?,
    time: json['time'] as String?,
    notify: json['notify'] as bool? ?? true,
  );
}
