# 전례력 캐시 게이트웨이 (Cloudflare Worker)

앱과 CBCK(missa.cbck.or.kr) 사이의 **캐시 게이트웨이**. 전례력 데이터는 발행 후
불변이라, 한 연도당 CBCK를 사실상 **1회만** 호출하고 이후 요청은 KV 캐시에서
응답합니다. → CBCK 호출량이 사용자 수와 무관하게 최소화됩니다.

## 동작
- `GET /v1/calendar/:year` → `{ year, available, source?, days? }`
  - 캐시 있음 → 즉시 응답(`x-cache: HIT`)
  - 캐시 없음 → CBCK 1회 조회 → KV 저장(30일) → 응답(`MISS`)
  - CBCK 미발행(빈 결과) → `available:false` + 1일 네거티브 캐시 → 앱은 기기 엔진 폴백
- 매일 cron으로 인접 연도(작년~+2년) 프리워밍 → 사용자 요청이 CBCK를 건드리지 않음.
- 응답에 CORS 헤더 포함 → **Flutter 웹에서도 직접 호출 가능**(CBCK엔 CORS 없음).
- 응답 `days[]` 형태는 앱/`tool/import_cbck.dart`와 동일:
  `{ date, color, title, special?, readings?, alternatives?, url? }`

## 배포 (당신이 수행 — Cloudflare 계정 필요)
```bash
cd server
npm install                       # wrangler 설치
npx wrangler login                # Cloudflare 로그인
npx wrangler kv namespace create CAL   # 출력된 id를 wrangler.toml의 CAL id에 붙여넣기
npx wrangler deploy               # 배포 → https://catholic-calendar-cache.<계정>.workers.dev
# 확인:
curl https://<배포URL>/v1/calendar/2026 | head
```
- 커스텀 도메인을 붙이면 `app-ads.txt`도 같은 도메인 루트에 얹을 수 있습니다.

## 앱 연동 (다음 단계)
앱의 `CalendarDataRepository`에 이 Worker를 **원격 소스**로 추가:
현재 보는 연도를 `/(v1/calendar/:year)`에서 받아 기기에 캐시 → 실패/미발행 시
번들 스냅샷 + 계산 엔진으로 폴백. (배포 URL 확정 후 연결)
