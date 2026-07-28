import 'recurrence.dart';
import 'reminder_lead.dart';

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
const int kSaintFeastEventColor = 0xFF8D6E63;
const String kSaintFeastCategoryId = 'saint_feast';
const String kSaintFeastCategoryName = '축일';
const String kSaintFeastPrefix = '축일';
const String kLegacySaintFeastPrefix = '[축일]';

enum CalendarEventType {
  regular,
  saintFeast;

  static CalendarEventType fromJson(Object? value) {
    return switch (value) {
      'saintFeast' => CalendarEventType.saintFeast,
      _ => CalendarEventType.regular,
    };
  }
}

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
    this.endDate,
    this.memo,
    this.time,
    this.endTime,
    this.notify = true,
    this.type = CalendarEventType.regular,
    this.saintId,
    this.saintName,
    this.saintUrl,
    this.recurrence = RecurrenceType.none,
    this.feastId,
    this.reminders = const [ReminderLead.day1],
  });

  /// Stable local id (millis/micros-based; no external uuid dependency).
  final String id;

  /// The day the event belongs to, `YYYY-MM-DD`.
  final String date;

  /// Inclusive end day of a continuous event, `YYYY-MM-DD`.
  ///
  /// Null means the same day as [date], preserving old single-day data.
  final String? endDate;

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

  /// Optional end time-of-day `HH:mm`; null = all-day or unspecified.
  final String? endTime;

  /// Whether to schedule local reminders for this event.
  final bool notify;

  final CalendarEventType type;

  final int? saintId;
  final String? saintName;
  final String? saintUrl;

  /// 반복 규칙. [date]가 시작(앵커)이며 조회/알림/위젯에서 전개한다.
  final RecurrenceType recurrence;

  /// `yearlyFeast`일 때 매년 재계산의 기준이 되는 전례 축일 키(`celebration.id`).
  final String? feastId;

  /// 알림 리드타임 목록(최대 2). notify가 켜졌을 때만 예약된다. 기본 [1일 전].
  final List<ReminderLead> reminders;

  bool get isRecurring => recurrence != RecurrenceType.none;

  bool get isSaintFeast => type == CalendarEventType.saintFeast;

  /// The event's display title.
  String get title => isSaintFeast ? saintName ?? categoryName : categoryName;

  String get saintFeastDisplayText {
    final name = saintName?.trim();
    final displayName = name == null || name.isEmpty ? title : name;
    final trimmedMemo = memo?.trim();
    if (trimmedMemo != null && trimmedMemo.isNotEmpty) {
      return '$kSaintFeastPrefix $displayName $trimmedMemo';
    }
    return '$kSaintFeastPrefix $displayName';
  }

  /// True when the event has no specific time (all-day).
  bool get isAllDay => time == null;

  String get effectiveEndDate => endDate ?? date;

  bool get isMultiDay => effectiveEndDate != date;

  CalendarEvent copyWith({
    String? id,
    String? date,
    String? categoryId,
    String? categoryName,
    int? categoryColor,
    String? endDate,
    String? memo,
    String? time,
    String? endTime,
    bool? notify,
    CalendarEventType? type,
    int? saintId,
    String? saintName,
    String? saintUrl,
    RecurrenceType? recurrence,
    String? feastId,
    List<ReminderLead>? reminders,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      endDate: endDate ?? this.endDate,
      memo: memo ?? this.memo,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      notify: notify ?? this.notify,
      type: type ?? this.type,
      saintId: saintId ?? this.saintId,
      saintName: saintName ?? this.saintName,
      saintUrl: saintUrl ?? this.saintUrl,
      recurrence: recurrence ?? this.recurrence,
      feastId: feastId ?? this.feastId,
      reminders: reminders ?? this.reminders,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'categoryColor': categoryColor,
    if (endDate != null && endDate != date) 'endDate': endDate,
    if (memo != null) 'memo': memo,
    if (time != null) 'time': time,
    if (endTime != null && endTime != time) 'endTime': endTime,
    'notify': notify,
    'type': type.name,
    if (saintId != null) 'saintId': saintId,
    if (saintName != null) 'saintName': saintName,
    if (saintUrl != null) 'saintUrl': saintUrl,
    if (recurrence != RecurrenceType.none) 'recurrence': recurrence.name,
    if (feastId != null) 'feastId': feastId,
    'reminders': [for (final r in reminders) r.name],
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final rawType = CalendarEventType.fromJson(json['type']);
    final rawCategoryId = json['categoryId'] as String? ?? '';
    final rawCategoryName =
        json['categoryName'] as String? ?? json['title'] as String? ?? '';
    final saintId = (json['saintId'] as num?)?.toInt();
    final saintName = json['saintName'] as String?;
    final saintUrl = json['saintUrl'] as String?;
    final rawMemo = json['memo'] as String?;
    final legacySaintName = _legacySaintFeastName(rawCategoryName);
    final legacyCategorySaintName =
        rawType == CalendarEventType.regular &&
            _isSaintFeastCategoryName(rawCategoryName) &&
            _hasText(rawMemo)
        ? rawMemo!.trim()
        : null;
    final hasSaintPayload =
        saintId != null || _hasText(saintName) || _hasText(saintUrl);
    final isLegacySaintFeast =
        rawType == CalendarEventType.regular &&
        (rawCategoryId == kSaintFeastCategoryId ||
            hasSaintPayload ||
            legacySaintName != null ||
            _isSaintFeastCategoryName(rawCategoryName));
    final type = isLegacySaintFeast ? CalendarEventType.saintFeast : rawType;
    // 하위호환: recurrence 필드가 없으면, 축일은 매년 반복(yearlyDate)을 기본으로
    // 적용하고(사용자 의도 "축일 기본 매년 반복"), 일반 이벤트는 반복 없음으로 둔다.
    final RecurrenceType recurrence = json.containsKey('recurrence')
        ? RecurrenceType.fromJson(json['recurrence'])
        : (type == CalendarEventType.saintFeast
              ? RecurrenceType.yearlyDate
              : RecurrenceType.none);
    final remindersRaw = json['reminders'] as List?;
    final reminders = remindersRaw == null
        ? const [ReminderLead.day1]
        : (remindersRaw
                  .map((e) => ReminderLead.fromStorage(e as String?))
                  .whereType<ReminderLead>()
                  .toList());
    final safeReminders =
        reminders.isEmpty ? const [ReminderLead.day1] : reminders;
    return CalendarEvent(
      id: json['id'] as String,
      date: json['date'] as String,
      // Fall back to a legacy free-text `title` if present (pre-category data).
      categoryId: type == CalendarEventType.saintFeast
          ? kSaintFeastCategoryId
          : rawCategoryId,
      categoryName: type == CalendarEventType.saintFeast
          ? kSaintFeastCategoryName
          : rawCategoryName,
      categoryColor: type == CalendarEventType.saintFeast
          ? kSaintFeastEventColor
          : ((json['categoryColor'] as num?)?.toInt() ?? kDefaultEventColor),
      endDate: json['endDate'] as String?,
      memo: legacyCategorySaintName == null ? rawMemo : null,
      time: json['time'] as String?,
      endTime: json['endTime'] as String?,
      notify: json['notify'] as bool? ?? true,
      type: type,
      saintId: saintId,
      saintName: saintName ?? legacySaintName ?? legacyCategorySaintName,
      saintUrl: saintUrl,
      recurrence: recurrence,
      feastId: json['feastId'] as String?,
      reminders: safeReminders,
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

bool _isSaintFeastCategoryName(String value) =>
    value.trim() == kSaintFeastCategoryName;

String? _legacySaintFeastName(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith(kLegacySaintFeastPrefix)) return null;
  final name = trimmed.substring(kLegacySaintFeastPrefix.length).trim();
  return name.isEmpty ? null : name;
}
