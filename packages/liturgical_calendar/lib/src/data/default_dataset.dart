/// A minimal built-in dataset so the engine works standalone (tests, CLI) with
/// no external assets. Applications ship the full curated dataset as JSON assets
/// and inject it; this is only the offline day-1 fallback.
library;

import 'schema.dart';

/// General Roman Calendar — fixed solemnities and a few feasts (fallback set).
const String defaultGeneralJson = '''
{
  "id": "general_roman_fallback",
  "locale": "ko",
  "celebrations": [
    {"id":"mary_mother_of_god","month":1,"day":1,"name":"천주의 성모 마리아 대축일","rank":"solemnity","color":"white"},
    {"id":"joseph","month":3,"day":19,"name":"복되신 동정 마리아의 배필 성 요셉 대축일","rank":"solemnity","color":"white"},
    {"id":"annunciation","month":3,"day":25,"name":"주님 탄생 예고 대축일","rank":"solemnity","color":"white"},
    {"id":"john_baptist_birth","month":6,"day":24,"name":"성 요한 세례자 탄생 대축일","rank":"solemnity","color":"white"},
    {"id":"peter_and_paul","month":6,"day":29,"name":"성 베드로와 성 바오로 사도 대축일","rank":"solemnity","color":"red"},
    {"id":"assumption","month":8,"day":15,"name":"성모 승천 대축일","rank":"solemnity","color":"white"},
    {"id":"all_saints","month":11,"day":1,"name":"모든 성인 대축일","rank":"solemnity","color":"white"},
    {"id":"all_souls","month":11,"day":2,"name":"위령의 날","rank":"feast","color":"violet","precedence":"generalSolemnity"},
    {"id":"immaculate_conception","month":12,"day":8,"name":"원죄 없이 잉태되신 복되신 동정 마리아 대축일","rank":"solemnity","color":"white"},
    {"id":"christmas","month":12,"day":25,"name":"주님 성탄 대축일","rank":"solemnity","color":"white","precedence":"privilegedSolemnity"}
  ]
}
''';

/// Korean proper overlay (fallback set). ⚠️ Ranks/names to be verified against
/// the official CBCK 전례력.
const String defaultKoreaJson = '''
{
  "id": "korea_proper_fallback",
  "locale": "ko",
  "celebrations": [
    {"id":"korean_martyrs","month":9,"day":20,"name":"성 김대건 안드레아 사제와 성 정하상 바오로와 동료 순교자 대축일","rank":"solemnity","color":"red","properToKorea":true,"titles":["순교자"]}
  ]
}
''';

/// National adaptation policy (fallback). Korea transfers 공현·승천·성체 성혈 to
/// Sunday; holy days of obligation are Sundays plus 성탄·천주의 성모 마리아.
const String defaultAdaptationJson = '''
{
  "epiphanyOnSunday": true,
  "ascensionOnSunday": true,
  "corpusChristiOnSunday": true,
  "holyDaysOfObligation": ["christmas","mary_mother_of_god"]
}
''';

/// The built-in fallback dataset.
CalendarDataset buildDefaultDataset() => CalendarDataset.fromJson(
      baseJson: defaultGeneralJson,
      overlayJson: defaultKoreaJson,
      adaptationJson: defaultAdaptationJson,
    );
