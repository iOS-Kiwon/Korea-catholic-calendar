# 한국 가톨릭 전례력 월간 달력 (웹 + 앱) — 설계 문서

> 상태: 승인됨 (2026-07-02). 실행용 계획은 `~/.claude/plans/indexed-wondering-mountain.md`에도 보관.

## Context

한국 천주교 전례력(典禮曆)을 보여주는 **월간 달력**을 웹사이트와 모바일 앱으로 동시에 제공한다. **Flutter 단일 코드베이스**로 PC(웹/PWA)와 모바일(iOS/Android)을 대응한다.

### 조사로 확인된 제약
- 매일미사 독서/복음 **본문**은 CBCK 저작권 대상이며 공식 오픈 API가 없다 → 본문 전재 제외.
- 전례력 계산(시기·색·축일·순위·독서주기)은 알고리즘으로 **완전 오프라인 계산 가능**, 명칭은 사실이라 저작권 무관.
- romcal(JS)은 Dart 포트·한국 플러그인이 없고 pub.dev에도 전례력 패키지가 없다 → **순수 Dart 엔진 직접 구현** + 한국 고유 축일 큐레이션.
- calapi·romcal은 **테스트 오라클**로만 사용(런타임 의존성 아님).

## 확정 결정
1. 표시 범위: 전례시기·색 + 축일·기념일·성인 + 주일·전례일 명칭 + 독서주기(A/B/C, Ⅰ/Ⅱ) 라벨.
2. **독서 본문 제외**(사용자 확정). 독서주기 라벨은 본문이 아니므로 유지. 구절 참조+공식 링크는 Phase 2 선택.
3. 플랫폼: 웹(PWA)+iOS+Android 동시(단일 코드베이스), 데스크톱은 저비용 옵션.
4. 언어: 한국어 기본, 영어 확장 가능 구조.
5. 주 시작 요일: 일요일 기본.
6. **데이터 유연성**: 엔진 로직은 코드, 축일 데이터+한국 정책은 스키마화된 JSON(번들). base(일반 로마력)+overlay(한국)+adaptation(정책) 조립. 향후 원격 OTA·사용자 전례력 전환 확장.

## 아키텍처 — 2계층 + 데이터 구동

```
catholic-calendar/            # Flutter 앱 (표현 계층)
└─ packages/liturgical_calendar/   # 순수 Dart 엔진 (Flutter 의존성 0)
```
- 앱은 엔진을 path 의존성으로 소비, 공개 API만 사용.
- **로직·데이터·정책 분리**: 엔진(코드) = 부활절·시기·우선순위 알고리즘 + 스키마 + JSON 코덱 + 내장 기본 데이터셋. 데이터(JSON) = general/korea/adaptation. 앱 = 번들 자산 로딩→엔진 DI(향후 OTA).

## 엔진 (`packages/liturgical_calendar`)
- 모듈: model / core(computus, temporale, season_resolver, reading_cycle) / data(schema, default_dataset, sanctorale_repository) / resolve(precedence_resolver) / i18n(ko_kr) / calendar(facade).
- 공개 API: `LiturgicalCalendar.day/month/year/range`. 입력은 date-only 정규화.
- `LiturgicalDay`: date, season, seasonWeek?, color, alternativeColors, celebration, optionalMemorials, commemorations, sundayCycle, weekdayCycle, isHolyDayOfObligation, title.
- 계산: Meeus/Jones/Butcher 부활절; 이동 축일은 부활절/대림 앵커 오프셋; 시기·색 경계; 연중 주차는 그리스도왕(34주)에서 역산; 독서주기는 전례주년 기준(주일 %3, 평일 홀짝).
- 우선순위: 전례일표 정밀 코드 정렬 + MVP 이동/생략 규칙(주일 vs 대축일 이동, 12/8→12/9, 성주간 대축일 이동, 기념일 생략).
- 데이터: `CalendarDataset` 스키마 + `dart:convert` 코덱·검증, JSON DI, 내장 기본값 fallback.

### ⚠️ CBCK 검증 항목
공현·승천·성체성혈 주일 이동 여부, 한국 순교자(9/20) 등급, 한국 의무 축일 목록, 한국 고유 기념일 로스터/명칭, 순교자 색(홍). → 2025~2027 CBCK 전례력으로 golden 작성.

### 테스트
Golden(부활절 2020~2038+경계, 고정/이동 앵커, 한국 조정), 속성(1970~2100: 매일 1승자, 시기 무결, 색 도메인), 오라클 차등(calapi/romcal fixture).

## 앱 (표현 계층)
- 스택: Riverpod + go_router + 커스텀 월 그리드 + M3 테마(LiturgicalColors ThemeExtension) + intl/ARB + PWA. Flutter 3.27+/Dart 3.6+.
- 반응형: compact(<600 단일+스와이프) / medium(600~1024 sheet) / expanded(>1024 master-detail). `DayDetailView`는 pane/route/sheet 재사용.
- 라우팅/URL: `/`, `/:year/:month`, `/:year/:month/:day`. usePathUrlStrategy + SPA fallback.
- 테마: 6 전례색을 밝기별 토큰으로, 색 단독 신호 금지(WCAG 1.4.1). MVP는 사이드바/뱃지 악센트.
- i18n: ARB엔 UI chrome만, 전례 콘텐츠 문자열은 엔진이 한국어 반환.
- PWA/배포: manifest.json + service worker, 웹 정적 호스팅(Cloudflare/Firebase), iOS/Android 스토어.

## MVP vs Phase 2
- **MVP**: 월 그리드(한국어·오프라인·웹+iOS+Android), 이전/다음/오늘, 셀=날짜+전례색+명칭, 상세=시기·색·등급·성인·독서주기, URL, PWA, 다크모드, 번들 JSON 데이터셋.
- **Phase 2**: 원격 OTA 갱신, 사용자 전례력 전환, 설정, 구절 참조+공식 링크, 영어, 시각 디자인 정교화, 알림, 위젯, 공유·딥링크, 데스크톱.

## 검증(E2E)
`dart test`(엔진 golden/속성 + CBCK 대조), `flutter test`(위젯/golden), `integration_test`(월 이동/선택/딥링크), `flutter run -d chrome`/시뮬레이터 육안 대조, `flutter build web`.
