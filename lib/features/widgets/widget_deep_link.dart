import '../../core/date/year_month.dart';

/// 홈 위젯이 앱을 열 때 쓰는 딥링크의 스킴. 공유 링크와 같은 스킴을 쓰고 host로
/// 구분한다(`e` = 공유 일정, `day`/`month` = 위젯).
const kWidgetLinkScheme = 'catholiccalendar';

/// 위젯이 열어달라고 요청한 화면.
///
/// - `catholiccalendar://day/2026-08-15` → 8월 달력에서 15일이 선택된 상태
/// - `catholiccalendar://month/2027-09`  → 2027년 9월 달력 (선택 날짜 없음)
///
/// 후자는 4x4 위젯이 스냅샷 범위를 벗어난 달에서 보여주는 안내의
/// `[앱으로 이동하기]` 버튼이 쓴다. 그 달은 위젯이 그릴 수 없어도 앱은 그릴 수 있다.
class WidgetLinkTarget {
  const WidgetLinkTarget({required this.month, this.day});

  final YearMonth month;

  /// 선택할 날짜(1-based). null이면 달만 열고 선택은 앱 기본값에 맡긴다.
  final int? day;

  /// go_router 경로.
  String get location => day == null ? _monthPath : '$_monthPath/$day';

  String get _monthPath =>
      '/${month.year}/${month.month.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is WidgetLinkTarget && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);

  @override
  String toString() => 'WidgetLinkTarget($location)';
}

final _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _monthPattern = RegExp(r'^(\d{4})-(\d{2})$');

/// 위젯 딥링크를 해석한다. 위젯 링크가 아니거나 형식이 틀리면 null.
///
/// 잘못된 값으로 앱이 엉뚱한 화면을 열지 않도록 달(1~12)과 일(그 달의 마지막 날)을
/// 모두 검사한다. 위젯 스냅샷이 오래돼 존재하지 않는 날짜를 보낼 수 있다.
WidgetLinkTarget? resolveWidgetLink(Uri uri) {
  if (uri.scheme != kWidgetLinkScheme) return null;

  // host 뒤의 첫 경로 조각을 값으로 쓴다.
  final value = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  if (value.isEmpty) return null;

  switch (uri.host) {
    case 'day':
      final m = _dayPattern.firstMatch(value);
      if (m == null) return null;
      final month = _monthOf(m.group(1)!, m.group(2)!);
      if (month == null) return null;
      final day = int.parse(m.group(3)!);
      if (day < 1 || day > month.daysInMonth) return null;
      return WidgetLinkTarget(month: month, day: day);
    case 'month':
      final m = _monthPattern.firstMatch(value);
      if (m == null) return null;
      final month = _monthOf(m.group(1)!, m.group(2)!);
      if (month == null) return null;
      return WidgetLinkTarget(month: month);
    default:
      return null;
  }
}

YearMonth? _monthOf(String year, String month) {
  final y = int.parse(year);
  final mo = int.parse(month);
  if (mo < 1 || mo > 12) return null;
  return YearMonth(y, mo);
}
