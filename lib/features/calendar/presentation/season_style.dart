import 'package:liturgical_calendar/liturgical_calendar.dart';

/// Korean season label, e.g. `연중 시기`.
String seasonLabel(Season s) {
  switch (s) {
    case Season.advent:
      return '대림 시기';
    case Season.christmas:
      return '성탄 시기';
    case Season.ordinaryTime:
      return '연중 시기';
    case Season.lent:
      return '사순 시기';
    case Season.paschalTriduum:
      return '파스카 성삼일';
    case Season.easter:
      return '부활 시기';
  }
}

/// A day is "notable" (gets a colored accent + name in the grid) when it is more
/// than a plain ferial weekday — a Sunday, solemnity, feast, memorial or a
/// privileged feria (재의 수요일·성주간 등).
bool isNotableDay(LiturgicalDay d) => d.celebration.rank != Rank.feria;

/// The default color of a season (for the header), independent of any saint.
LiturgicalColor seasonColor(Season s) {
  switch (s) {
    case Season.advent:
    case Season.lent:
      return LiturgicalColor.violet;
    case Season.christmas:
    case Season.paschalTriduum:
    case Season.easter:
      return LiturgicalColor.white;
    case Season.ordinaryTime:
      return LiturgicalColor.green;
  }
}
