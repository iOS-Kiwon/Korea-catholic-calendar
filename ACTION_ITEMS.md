# 사용자 확인·작업 목록 (ACTION ITEMS)

당신이 **직접 전달/결정/검토**해야 할 항목. (⚠️ = 반드시 확인)
_최종 갱신: 2026-07-02 — 앱 이름·번들 ID·계정 확정 반영._

---

## ✅ 확정·완료된 결정 (당신이 답해주신 것)

- CBCK 데이터 이용: 별도 약관 없음 → 그대로 사용.
- 앱 이름: **"가톨릭 달력"** (앱·웹·플랫폼 전체 반영 완료).
- 번들 ID: **com.sidore.catholiccalendar** (Android `applicationId`/`namespace`/Kotlin 패키지, iOS `PRODUCT_BUNDLE_IDENTIFIER` 반영 완료).
- 주 시작 요일: 일요일 고정.
- 계정: Apple Developer / Google Play 모두 보유.

## ✅ 최근 확정·완료

- 디자인 시안(현대 절충 1c) 반영 완료.
- **앱 아이콘 적용 완료** — 전달해 주신 아이콘으로 iOS/Android/웹 아이콘 생성(`assets/icon/app_icon.png` 원본). 수정본 주시면 `dart run flutter_launcher_icons` 재실행으로 교체.
- **다크 모드 미지원 확정** — 항상 라이트 테마.
- **AdMob 배너 통합 완료** — 모든 화면 하단(SafeArea.bottom 바로 위). iOS/Android 실 ID 반영:
  - iOS 앱 `~9692360017` · 배너 `/5415157947`
  - Android 앱 `~2281981735` · 배너 `/6029655050`
  - release=실 광고, debug=테스트 광고(정책 준수). 웹은 광고 없음.
- 웹사이트 제공: 보류(결정 시 호스팅 연결 진행).

## ✅ 최근 추가 (ATT · SKAdNetwork · UMP · app-ads.txt)

- iOS **ATT** 프롬프트 + `NSUserTrackingUsageDescription`, **SKAdNetworkItems**(Google 공식 50개), **UMP 동의(GDPR)** 흐름(동의→ATT→SDK init), `web/app-ads.txt`(`pub-5980133283002959`) 코드/설정 완료.

## ✅ 최근 추가 (로컬 개인 일정 + 로컬 알림)

- **일정 추가 기능**: 화면 우하단 **플로팅 버튼(FAB, 현재 월 전례색)** → 편집 시트.
  - 필드: 날짜(필수)·제목(필수)·메모(선택)·시간(종일 또는 `HH:mm`)·알림 토글.
  - **기기 내부(`shared_preferences`)에만 저장** — 클라우드/기기 캘린더 연동 없음.
  - 하단 정보영역 요약 + 상세 "내 일정" 목록(수정/삭제) + 달력 그리드 마커(전례색 점과 구분되는 우상단 점).
- **로컬 알림(서버 없음)**: `flutter_local_notifications` + `timezone`.
  - **전날 21:00 + 당일**(시간 지정 시 그 시각, 종일은 09:00) 예약. 일정별 알림 토글(기본 켜짐).
  - iOS/Android만 동작(웹은 조건부 import 로 알림 없이 나머지 기능 정상).
  - 부정확 예약(inexact) 사용 → Android 정확 알람 특별 권한 불필요. 재부팅/앱 재설치 후 재등록(boot 리시버 + 앱 실행 시 재동기화).
- **일정 = 카테고리 선택 방식** (제목 직접 입력 없음): 사용자가 자기 카테고리를 만들고, 일정 추가 시 **카테고리를 클릭**해 등록. 메모만 부가 설명으로 직접 입력.
  - 카테고리: **이름 + 색상**. 관리 화면에서 **추가/편집/삭제/순서변경**. 진입: 달력 상단 카테고리 아이콘 + 편집 시트의 '관리' 링크 + 편집 시트 안 '추가' 칩.
  - **첫 실행 시 기본 카테고리 시드**: 본당 행사·교구 행사·성당 청소·모임·연령회·초상 (모두 편집/삭제 가능).
  - 카테고리 **이름/색 변경 → 기존 일정에도 반영**. **삭제해도 기존 일정은 이름 보존**(데이터 손실 없음).
- 브랜치: `feat/local-events` (커밋 완료). 검증: `flutter analyze` 클린, `flutter test` 27개 통과, `flutter build web` 성공.

## ✅ CBCK 캐시 게이트웨이 (배포·연동 완료)

- Cloudflare Worker 배포됨: **`https://catholic-calendar.sidore.workers.dev`** (KV 캐시 + 매일 cron 프리워밍, 월 단위·브라우저 헤더).
- 앱이 현재 보는 **달**을 게이트웨이에서 받아 사용(`monthServiceProvider`), 실패/미발행/오프라인 시 **번들 스냅샷 + 계산 엔진 폴백**.
- 검증: 2026/7=31일, 2050/1=available:false, CORS 헤더 확인.
- (선택) 나중에 커스텀 도메인 연결 시 그 도메인 루트에 `app-ads.txt`도 함께 서빙 가능.
- 참고: 게이트웨이는 호출 완화책일 뿐, 근본적으로는 **CBCK 사용 허가/제휴**가 정답.

## ⏳ 남은 당신의 몫

- [ ] **AdMob 콘솔에서 동의/개인정보 메시지 생성** — AdMob → 개인정보 보호 및 메시지(Privacy & messaging)에서 **GDPR(유럽) 동의 메시지**(및 원하면 IDFA/ATT 사전 설명 메시지)를 만들어 게시해야 UMP 동의 폼이 실제로 표시됩니다. (코드는 준비됨)
- [ ] **`app-ads.txt` 호스팅** — App Store/Play 개발자 프로필에 등록한 **웹사이트 도메인 루트**(`https://<도메인>/app-ads.txt`)에 올려야 인증됩니다. 웹 배포 도메인이 정해지면 `web/app-ads.txt`가 자동 서빙되거나, 해당 도메인 루트에 파일을 두세요.
- [ ] **AdMob 실기기 검증** — 배너 노출 + (EEA 시뮬레이션 시) 동의 폼 + iOS ATT 프롬프트 확인. (iOS는 CocoaPods 필요: `sudo gem install cocoapods`)
- [ ] (선택) Android **적응형 아이콘(adaptive)** 전경/배경 이미지.
- [ ] 출시 전 **AdMob 정책 검토**.
- [ ] **일정 알림 실기기 검증** — 실제 iOS/Android 기기에서: (1) 첫 일정 추가 시 알림 권한 허용, (2) 가까운 시각 일정을 만들어 **전날/당일 알림 수신** 확인. (시뮬레이터/에뮬레이터에서도 예약 시각을 몇 분 뒤로 잡아 테스트 가능)
- [ ] (선택) 알림 아이콘 — 현재 런처 아이콘(`@mipmap/ic_launcher`) 사용. Android 상태바에서 더 또렷하게 하려면 흰색 실루엣 전용 아이콘을 주면 교체 가능.
- [ ] (선택) `feat/local-events` 브랜치를 `master`로 병합할지 결정(원하면 PR 생성).

## 📌 데이터 유지보수 (주기적)

- [ ] **CBCK 연도 확장**: 새 해 전례력이 공식 공개되면 `dart run tool/import_cbck.dart 2025 2028` 재실행 → `cbck_days.json` 갱신 후 재배포. (현재 2025~2026 수록, 2027년~ 는 엔진 자동 폴백)
- [ ] (선택) 엔진 폴백 연도(2027년~) 정확도가 중요하면 `assets/calendar/general.json`의 선택 기념일 로스터 보완.

## 📄 참고 (지금 조치 불필요)

- 독서/복음 **본문은 embed 안 함** — 구절 참조 + "매일미사에서 전문 보기" 링크로 대체(저작권 안전).
- 남은 개발(제가 이어서 가능): 통합 테스트, 설정 화면, 영어, 원격 OTA, 알림/위젯, 스토어 배포 CI.

## 검증
```bash
dart test packages/liturgical_calendar   # 엔진 110개
flutter test                             # 앱 4개
flutter run -d chrome                    # 실제 확인 (2025~2026 공식 데이터)
```

_설계: `docs/superpowers/specs/2026-07-02-...-design.md` · CBCK 임포터: `tool/import_cbck.dart`_
