/// The Table of Liturgical Days (전례일표) — the precedence codes used to decide
/// which celebration wins when two or more coincide on the same date.
///
/// Declared from highest precedence (lowest ordinal) to lowest, so that
/// `PrecedenceCode.index` gives a total order: a smaller index outranks a
/// larger one. `Rank` alone is not enough to resolve collisions — e.g. a Feast
/// of the Lord and an Ordinary Time Sunday need distinct codes — so every
/// celebration carries a [PrecedenceCode].
library;

enum PrecedenceCode {
  // I — highest
  /// 1.1 파스카 성삼일 (Easter Triduum).
  triduum,

  /// 1.2 주님 성탄·공현·승천·성령 강림 대축일; 대림·사순·부활 주일; 재의 수요일;
  /// 성주간 월~목; 부활 팔일 축제 평일.
  privilegedSolemnity,

  /// 1.3 주님·복되신 동정 마리아·성인 대축일(일반 전례력); 위령의 날.
  generalSolemnity,

  /// 1.4 고유 대축일 (본당 주보·봉헌·명칭).
  properSolemnity,

  // II
  /// 2.5 주님의 축일 (일반 전례력) — 연중 주일보다 우선.
  feastOfTheLord,

  /// 2.6 성탄·연중 주일.
  sunday,

  /// 2.7 복되신 동정 마리아·성인 축일 (일반 전례력).
  generalFeast,

  /// 2.8 고유 축일.
  properFeast,

  /// 2.9 대림 12/17~24 평일; 성탄 팔일 축제 평일; 사순 평일.
  privilegedWeekday,

  // III
  /// 3.10 의무 기념일 (일반 전례력).
  generalObligatoryMemorial,

  /// 3.11 고유 의무 기념일.
  properObligatoryMemorial,

  /// 3.12 선택 기념일.
  optionalMemorial,

  /// 3.13 그 밖의 평일.
  weekday,
}

extension PrecedenceCodeOrder on PrecedenceCode {
  /// True if this code outranks (takes precedence over) [other].
  bool outranks(PrecedenceCode other) => index < other.index;
}
