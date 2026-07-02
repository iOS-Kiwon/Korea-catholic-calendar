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

## ⏳ 당신이 전달/결정 대기 중

- [ ] **디자인 시안 전달 예정** → 받으면 테마·전례색·셀/상세 레이아웃을 시안에 맞춰 조정. (현재는 임시 M3 + 전례색 사이드바)
- [ ] **웹사이트 제공 여부** → 보류. 연결하기로 결정되면 그때 호스팅(Cloudflare/Firebase 등) 선택 + SPA fallback 설정 진행.
- [ ] **앱 아이콘 이미지** → 현재 Flutter 기본 아이콘. 시안과 함께 로고/아이콘 주시면 교체.

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
