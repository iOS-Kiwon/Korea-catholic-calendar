/// Korean formatting of temporale (Proper of Time) day titles.
///
/// Produces the liturgical day name for Sundays and ferias, e.g.
/// `연중 제15주일`, `사순 제2주간 월요일`. Named celebrations from the sanctorale
/// carry their own proper names and do not use this formatter.
library;

import '../core/season_resolver.dart';
import '../model/enums.dart';

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// Korean weekday label for [date], e.g. `월요일`.
String koWeekday(DateTime date) => '${_weekdayNames[date.weekday - 1]}요일';

/// The temporale (Proper of Time) title for [date].
String koTemporalTitle(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final t = Temporale.containing(d);
  final info = t.resolve(d);
  final isSunday = d.weekday == DateTime.sunday;

  switch (info.season) {
    case Season.paschalTriduum:
      if (d == t.holyThursdayDate) return '주님 만찬 성목요일';
      if (d == t.goodFridayDate) return '주님 수난 성금요일';
      return '성토요일';

    case Season.christmas:
      // Named Christmas celebrations (성탄 대축일, 천주의 성모, 성가정, 공현, 세례)
      // come from the sanctorale/temporale data; this is a plain fallback.
      return isSunday ? '성탄 시기 주일' : '성탄 시기 평일';

    case Season.easter:
      if (info.week == 1) {
        // 부활 팔일 축제 (Easter octave); Easter Sunday itself is a solemnity.
        return isSunday ? '주님 부활 대축일' : '부활 팔일 축제 ${koWeekday(d)}';
      }
      return isSunday
          ? '부활 제${info.week}주일'
          : '부활 제${info.week}주간 ${koWeekday(d)}';

    case Season.lent:
      if (info.week == null) {
        // Thu–Sat after Ash Wednesday, before the First Sunday of Lent.
        return '재의 수요일 다음 ${koWeekday(d)}';
      }
      return isSunday
          ? '사순 제${info.week}주일'
          : '사순 제${info.week}주간 ${koWeekday(d)}';

    case Season.advent:
      return isSunday
          ? '대림 제${info.week}주일'
          : '대림 제${info.week}주간 ${koWeekday(d)}';

    case Season.ordinaryTime:
      return isSunday
          ? '연중 제${info.week}주일'
          : '연중 제${info.week}주간 ${koWeekday(d)}';
  }
}
