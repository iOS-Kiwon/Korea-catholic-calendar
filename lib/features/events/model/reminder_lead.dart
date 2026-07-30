/// 일/주 단위 알림이 울리는 고정 시각(아침 9시).
const int kReminderDayHour = 9;

/// 일정 알림 리드타임. 분/시간 단위는 일정 시작 시각 기준, 일/주 단위는 해당 날 아침 9시.
enum ReminderLead {
  min5,
  min10,
  min30,
  hour1,
  hour2,
  day1,
  day2,
  week1;

  static ReminderLead? fromStorage(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  String get displayName => switch (this) {
    min5 => '5분 전',
    min10 => '10분 전',
    min30 => '30분 전',
    hour1 => '1시간 전',
    hour2 => '2시간 전',
    day1 => '1일 전',
    day2 => '2일 전',
    week1 => '1주일 전',
  };

  bool get isSubDay => switch (this) {
    min5 || min10 || min30 || hour1 || hour2 => true,
    day1 || day2 || week1 => false,
  };

  Duration get _subDayDuration => switch (this) {
    min5 => const Duration(minutes: 5),
    min10 => const Duration(minutes: 10),
    min30 => const Duration(minutes: 30),
    hour1 => const Duration(hours: 1),
    hour2 => const Duration(hours: 2),
    _ => Duration.zero,
  };

  int get _dayOffset => switch (this) {
    day1 => 1,
    day2 => 2,
    week1 => 7,
    _ => 0,
  };

  String get storageValue => name;

  /// 이 리드의 알림 시각. [date]=발생일(날짜만), [time]='HH:mm' 또는 null(종일).
  /// 분/시간 리드는 종일 일정엔 무의미하므로 null.
  DateTime? reminderTime(DateTime date, String? time) {
    if (isSubDay) {
      if (time == null) return null;
      final p = time.split(':');
      final h = int.tryParse(p[0]) ?? kReminderDayHour;
      final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
      final start = DateTime(date.year, date.month, date.day, h, m);
      return start.subtract(_subDayDuration);
    }
    return DateTime(
      date.year,
      date.month,
      date.day - _dayOffset,
      kReminderDayHour,
      0,
    );
  }
}
