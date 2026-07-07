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
  - iOS 앱 `~4438618627` · 배너 `/3997553939`
  - Android 앱 `~2281981735` · 배너 `/6029655050`
  - release=실 광고, debug=테스트 광고(정책 준수). 웹은 광고 없음.
- 웹사이트 제공: 보류(결정 시 호스팅 연결 진행).

## ⏳ 남은 당신의 몫

- [ ] **AdMob 실기기 검증** — 시뮬레이터/에뮬레이터·실기기에서 배너 노출 확인. (iOS는 CocoaPods 설치 필요: `sudo gem install cocoapods`)
- [ ] (선택) iOS **App Tracking Transparency(ATT)**·SKAdNetwork·`app-ads.txt`·GDPR 동의(UMP) — 맞춤 광고/수익 최적화 및 정책 요건 필요 시. (현재는 기본 배너만)
- [ ] (선택) Android **적응형 아이콘(adaptive)** 전경/배경 이미지 — 최상의 안드로이드 표시를 원할 때. (현재는 레거시 아이콘으로 동작)
- [ ] 출시 전 **AdMob 정책 검토**(가이드 3번) — 배너 위치/클릭 유도 금지 등.

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
