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

/// The fallback color for an event whose category has been deleted and which
/// was created before categories carried a color.
const int kDefaultEventColor = 0xFF455A64;

/// A user-created personal event stored on-device only.
///
/// The event's title is a **category** the user picked (categories are managed
/// separately). [categoryName]/[categoryColor] are a snapshot captured at save
/// time so the event survives category deletion; while the category still
/// exists its edits are propagated into this snapshot. [memo] is an optional
/// per-event note. Dates use the same `YYYY-MM-DD` key convention as the
/// liturgical calendar (`CalendarService`); a null [time] means all-day.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    this.categoryColor = kDefaultEventColor,
    this.memo,
    this.time,
    this.notify = true,
  });

  /// Stable local id (millis/micros-based; no external uuid dependency).
  final String id;

  /// The day the event belongs to, `YYYY-MM-DD`.
  final String date;

  /// The id of the category this event was created from (may be dangling if
  /// the category was later deleted).
  final String categoryId;

  /// Snapshot of the category name — the event's displayed title.
  final String categoryName;

  /// Snapshot of the category ARGB color.
  final int categoryColor;

  /// Optional free-form note.
  final String? memo;

  /// Optional time-of-day `HH:mm`; null = all-day.
  final String? time;

  /// Whether to schedule local reminders for this event.
  final bool notify;

  /// The event's display title (its category name).
  String get title => categoryName;

  /// True when the event has no specific time (all-day).
  bool get isAllDay => time == null;

  CalendarEvent copyWith({
    String? id,
    String? date,
    String? categoryId,
    String? categoryName,
    int? categoryColor,
    String? memo,
    String? time,
    bool? notify,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      memo: memo ?? this.memo,
      time: time ?? this.time,
      notify: notify ?? this.notify,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'categoryColor': categoryColor,
    if (memo != null) 'memo': memo,
    if (time != null) 'time': time,
    'notify': notify,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    date: json['date'] as String,
    // Fall back to a legacy free-text `title` if present (pre-category data).
    categoryId: json['categoryId'] as String? ?? '',
    categoryName:
        json['categoryName'] as String? ?? json['title'] as String? ?? '',
    categoryColor: (json['categoryColor'] as num?)?.toInt() ??
        kDefaultEventColor,
    memo: json['memo'] as String?,
    time: json['time'] as String?,
    notify: json['notify'] as bool? ?? true,
  );
}
