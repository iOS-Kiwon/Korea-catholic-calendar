/// 개인 일정/축일의 반복 규칙 종류.
///
/// 저장은 반복 "규칙"만 하고(개별 인스턴스를 미리 만들지 않음), 조회/알림/위젯에서
/// 대상 날짜에 대해 전개(expand)한다. [CalendarEvent.date]가 시작(앵커) 날짜이며
/// 요일/일/월·일은 여기서 파생한다.
enum RecurrenceType {
  /// 반복 없음(단일 날짜).
  none,

  /// 매일.
  daily,

  /// 매주(앵커와 같은 요일).
  weekly,

  /// 매월(앵커와 같은 일. 그 달에 그 일이 없으면 그해 그달은 건너뜀).
  monthly,

  /// 매년 같은 월·일(2/29는 평년 건너뜀).
  yearlyDate,

  /// 매년 같은 전례 축일(부활절 등 이동 축일. `celebration.id` 기준으로 매년 날짜 재계산).
  yearlyFeast;

  static RecurrenceType fromJson(Object? value) {
    return switch (value) {
      'daily' => RecurrenceType.daily,
      'weekly' => RecurrenceType.weekly,
      'monthly' => RecurrenceType.monthly,
      'yearlyDate' => RecurrenceType.yearlyDate,
      'yearlyFeast' => RecurrenceType.yearlyFeast,
      _ => RecurrenceType.none,
    };
  }
}
