import '../../calendar/data/calendar_service.dart';
import '../model/calendar_event.dart';
import '../model/recurrence.dart';

/// 반복 규칙을 특정 날짜에 대해 전개(expand)하는 중앙 헬퍼.
///
/// 개별 인스턴스를 미리 만들지 않고, 조회/알림/위젯이 이 헬퍼로 "그 날짜에
/// 발생하는가"를 판정한다. [CalendarEvent.date]가 시작(앵커) 날짜이며, 반복은
/// 앵커 이후(포함)에만 발생한다.
class RecurrenceExpander {
  const RecurrenceExpander(this._calendar);

  /// 이동 축일(yearlyFeast) 해석용. null이면(캘린더 미로딩/웹) yearlyFeast는
  /// 전개하지 않는다(다른 반복 유형은 캘린더 없이 동작).
  final CalendarService? _calendar;

  /// [event]가 [date](날짜만)에 발생하는가?
  bool occursOn(CalendarEvent event, DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final anchor = parseEventDate(event.date);
    if (target.isBefore(anchor)) return false;
    switch (event.recurrence) {
      case RecurrenceType.none:
        return target == anchor;
      case RecurrenceType.daily:
        return true; // 이미 target >= anchor
      case RecurrenceType.weekly:
        return target.weekday == anchor.weekday;
      case RecurrenceType.monthly:
        // 그 달에 앵커의 '일'이 없으면(예: 31일) target.day가 그 값일 수 없어 자연히 건너뜀.
        return target.day == anchor.day;
      case RecurrenceType.yearlyDate:
        // 2/29는 평년에 그런 날짜가 없어 자연히 건너뜀.
        return target.month == anchor.month && target.day == anchor.day;
      case RecurrenceType.yearlyFeast:
        final id = event.feastId;
        final cal = _calendar;
        if (id == null || cal == null) return false;
        return cal.feastDateInYear(id, target.year) == target;
    }
  }

  /// [all](날짜키 맵 전체)에서 [date]에 발생하는 이벤트들. 정렬은 호출부가 한다.
  List<CalendarEvent> eventsOn(
    Map<String, List<CalendarEvent>> all,
    DateTime date,
  ) {
    final result = <CalendarEvent>[];
    for (final list in all.values) {
      for (final e in list) {
        if (occursOn(e, date)) result.add(e);
      }
    }
    return result;
  }

  /// [from](포함) 이후 [event]의 발생일 최대 [count]개(날짜만, 오름차순).
  /// 무한 반복을 상한 안에서 열거한다(알림 예약용).
  List<DateTime> nextOccurrences(CalendarEvent event, DateTime from, int count) {
    final result = <DateTime>[];
    if (count <= 0) return result;
    final anchor = parseEventDate(event.date);
    var start = DateTime(from.year, from.month, from.day);
    if (start.isBefore(anchor)) start = anchor;
    // 무한 루프 방지 + 연간 반복이 count년 안에 커버되도록 넉넉히.
    final maxDays = 366 * (count + 1) + 40;
    for (var i = 0; i < maxDays && result.length < count; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      if (occursOn(event, d)) result.add(d);
    }
    return result;
  }
}
