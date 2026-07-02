/// Shared enums (type vocabulary) for the liturgical calendar engine.
library;

/// 전례 시기 — the liturgical seasons.
enum Season {
  advent, // 대림 시기
  christmas, // 성탄 시기
  ordinaryTime, // 연중 시기
  lent, // 사순 시기
  paschalTriduum, // 파스카 성삼일
  easter, // 부활 시기
}

/// 전례색 — the liturgical colors.
enum LiturgicalColor {
  white, // 백색
  red, // 홍색
  green, // 녹색
  violet, // 자색
  rose, // 장미색
  black, // 흑색
}

/// 축일 등급/순위 — rank of a celebration.
///
/// Ordered from highest to lowest so that `Rank.compareTo` and `index` can be
/// used as a coarse ordering. Fine-grained precedence uses [PrecedenceCode].
enum Rank {
  solemnity, // 대축일
  feastOfTheLord, // 주님 축일 (연중 주일보다 우선)
  feast, // 축일
  sunday, // 주일
  obligatoryMemorial, // 의무 기념일
  optionalMemorial, // 선택 기념일
  privilegedFeria, // 특전 평일 (재의 수요일, 성주간, 대림 12/17~24, 부활 팔일 축제)
  feria, // 평일
}

/// 주일 독서 주기 — the three-year Sunday lectionary cycle (가/나/다해).
enum SundayCycle { a, b, c }

/// 평일 독서 주기 — the two-year weekday lectionary cycle (홀/짝해).
enum WeekdayCycle { i, ii }
