# 자체 서버 기반 앱 데이터와 개인 클라우드 백업 설계 검토

작성일: 2026-07-17

## 목적

현재 앱은 전례력 데이터 조회는 앱 내부 데이터와 Cloudflare Worker 캐시 게이트웨이를 사용하고,
사용자 일정/카테고리는 기기 로컬 `SharedPreferences`에만 저장한다. 이 문서는 향후 자체 서버를
중심으로 앱 기능용 공용 데이터를 관리하고, 사용자 개인 데이터는 iCloud/Google 계정의 앱 전용
저장소에 맡기는 큰 그림, 권장 구조, 구현 단계, 보안 주의사항을 정리한다.

## 현재 상태

- 앱 사용자 일정: 현재는 로컬 저장소에 JSON으로 저장
  - `events_v1`: 날짜별 사용자 일정
  - `categories_v1`: 사용자 카테고리
- 앱 삭제 후 재설치 시 사용자 일정/카테고리는 복원되지 않는다.
- 전례력 원격 데이터: Cloudflare Worker가 CBCK 데이터를 월 단위로 가져와 KV에 캐시한다.
- 앱은 원격 조회 실패 또는 미발행 시 번들 데이터/계산 엔진으로 폴백할 수 있는 구조를 갖고 있다.

## 목표 구조

핵심 원칙은 자체 서버가 사용자 개인 일정/메모를 저장하지 않는 것이다. 자체 서버는 전례력 데이터,
공지, 앱 설정, 원격 기능 플래그, 캐시 상태처럼 앱 기능에 필요한 공용/운영 데이터를 담당한다.
사용자 일정/카테고리 같은 개인 데이터는 각 플랫폼의 사용자 개인 클라우드 저장소를 사용한다.

```text
앱
  |
  | 전례력/앱 기능 데이터 1차 요청
  v
자체 서버(Mac mini M4)
  |
  | DB에 데이터 있음
  v
DB(PostgreSQL 권장)

자체 서버
  |
  | DB에 전례력 데이터 없음
  v
Cloudflare Worker
  |
  v
CBCK / Cloudflare KV 캐시

앱
  |
  | 사용자 일정/카테고리 백업 및 복원
  v
iOS: iCloud Key-Value Store 또는 CloudKit Private Database
Android: Android Auto Backup 또는 Google Drive appDataFolder
```

관리자는 별도 관리자 페이지를 통해 자체 서버와 DB에 접근하여 전례력 데이터, 앱 기능 데이터,
캐시 상태를 확인하고 필요한 데이터를 추가/수정/삭제한다. 관리자 페이지에서 사용자 개인 일정/메모를
조회하거나 수정하는 기능은 만들지 않는 것을 기본 원칙으로 둔다.

## 위치 검토: 집 Mac mini M4

집 Mac mini M4를 서버로 쓰는 것은 초기 비용과 통제권 측면에서 좋은 선택이다. 사용자가 많지 않은
초기 단계에서는 충분히 현실적인 운영 방식이다.

다만 자체 서버가 사용자 개인 데이터를 저장하지 않더라도, 외부에서 접근 가능한 운영 서버가 되는
순간 다음 운영 리스크를 반드시 관리해야 한다.

- 전원 장애, 인터넷 장애, 공유기 장애가 곧 서비스 장애가 된다.
- 집 인터넷의 업로드 대역폭과 지연 시간이 사용자 경험에 영향을 준다.
- 동적 IP, 포트포워딩, 방화벽 설정이 필요할 수 있다.
- OS/런타임/DB 보안 업데이트를 직접 책임져야 한다.
- 디스크 장애에 대비한 자동 백업과 복구 연습이 필요하다.
- 관리자 페이지가 외부에 노출되면 공격 표면이 크게 늘어난다.

## 권장 네트워크 구성

집 서버를 직접 인터넷에 노출하는 것보다 Cloudflare Tunnel 같은 터널 방식을 권장한다.

```text
앱 / 관리자 브라우저
  |
  v
Cloudflare DNS / TLS / WAF / Rate Limit
  |
  v
Cloudflare Tunnel
  |
  v
집 Mac mini 서버
```

권장 이유:

- 공유기 포트포워딩을 최소화할 수 있다.
- TLS 인증서 관리를 단순화할 수 있다.
- Cloudflare의 기본 DDoS 완화, WAF, 접근 제어, Rate Limit을 앞단에 둘 수 있다.
- 관리자 페이지를 Cloudflare Access 뒤에 숨길 수 있다.

## DB 선택

### 권장: PostgreSQL

전례력 데이터, 앱 공용 설정, 공지, 감사 로그, 관리자 작업 이력을 함께 다루려면 PostgreSQL이
가장 무난하다.

장점:

- 트랜잭션과 제약조건이 강하다.
- 날짜/시간/JSONB 처리에 강하다.
- 백업/복구 도구가 성숙하다.
- 작은 서버에서도 충분히 가볍게 운영 가능하다.

초기에는 Docker Compose로 `app server + PostgreSQL + reverse proxy`를 묶어 운영하고, 추후
트래픽이나 운영 부담이 커지면 DB만 관리형 서비스로 옮기는 전략이 좋다.

### SQLite 검토

전례력 캐시만 저장한다면 SQLite도 가능하다. 하지만 관리자 페이지, 감사 로그, 공지/원격 설정까지
고려하면 PostgreSQL로 시작하는 편이 향후 변경 비용이 낮다.

## 서버 역할 분리

자체 서버는 다음 책임을 가진다.

- 앱 API 제공
  - 전례력 월별 조회
  - 앱 기능용 공용 설정 조회
  - 공지, 원격 설정, 데이터 버전 정보 조회
- 전례력 캐시 관리
  - DB에 있으면 DB 응답
  - 없으면 Cloudflare Worker 조회 후 DB 저장
  - Worker도 실패하면 앱이 로컬 폴백 가능하도록 `available:false` 또는 명확한 오류 응답
- 관리자 API 제공
  - 전례력 데이터 추가/수정/삭제
  - 캐시 상태 확인
  - 앱 기능용 공용 데이터 관리
- 운영 기능
  - 헬스체크
  - 로그
  - 백업
  - 모니터링

## 앱 API 초안

공개 API 기본 경로:

```text
https://api.sidore.org/kcc/v1/{service}
```

백오피스 기본 경로:

```text
https://admin.sidore.org/kcc
```

- `kcc`: Korea Catholic Calendar 서비스 식별자
- `v1`: API 버전. 응답 구조나 인증 방식이 깨지는 변경이 생기면 `v2`를 새로 둔다.
- `{service}`: API 성격별 서비스 이름

서비스 이름 초안:

- `/calendar`: 전례력/달력 공용 데이터
- `/health`: 서버 상태 확인
- `/user`: 향후 예약. 사용자 개인 일정/메모 저장용으로는 사용하지 않는다.

전례력:

- `GET /kcc/v1/calendar/:year/:month`
  - 자체 DB에 있으면 `source: "server-db"`
  - Cloudflare Worker에서 가져와 저장했으면 `source: "cloudflare"`
  - 미발행/실패 시 `available:false`

사용자 데이터:

- 자체 서버에는 만들지 않는다.
- 앱 내부에서 iCloud/Google 계정의 앱 전용 저장소와 동기화한다.
- 서버 API에는 사용자 일정/메모/카테고리 업로드 엔드포인트를 두지 않는다.
- `/kcc/v1/user` 계열은 향후 앱 계정/설정 같은 비개인 일정 기능이 필요할 때까지 예약만 해둔다.

이 구조를 유지하면 자체 서버가 사용자 개인 일정/메모의 보관자가 되지 않는다. 개인정보 처리 범위와
보안 책임이 줄어들고, 관리자 페이지에서도 사용자 개인 데이터를 다루지 않게 된다.

## 사용자 개인 데이터 저장소 전략

사용자 데이터 복원을 하려면 “재설치 후에도 같은 사용자의 개인 클라우드 저장소를 다시 읽는 방법”이
필요하다. 자체 서버 계정 대신 플랫폼 계정을 활용한다.

### iOS

선택지:

- iCloud Key-Value Store
  - 현재 데이터 구조처럼 작은 JSON 몇 개를 저장하기 쉽다.
  - Apple 기준 앱당 사용자별 총 1MB, 최대 1024개 키 제한이 있다.
  - 자주 변하는 대량 데이터보다는 설정/작은 앱 상태 저장에 적합하다.
  - 현재 일정/카테고리 규모가 작다면 1차 MVP로 가장 단순하다.
- CloudKit Private Database
  - 사용자 iCloud 계정의 private database에 저장한다.
  - 사용자만 접근 가능하고 개발자 포털에서도 private DB 내용은 보이지 않는다.
  - 일정이 많아지거나, 레코드 단위 동기화/충돌 처리가 필요해지면 더 적합하다.
  - 구현량은 Key-Value Store보다 크다.

권장:

- 1차: iCloud Key-Value Store로 `events_v1`, `categories_v1`, `categories_seeded_v1` 백업/복원
- 2차: 데이터 증가나 다중 기기 충돌 문제가 커지면 CloudKit Private Database로 전환

### Android / Google

선택지:

- Android Auto Backup
  - Android 6.0 이상에서 앱 데이터를 사용자의 Google Drive 백업 영역에 자동 백업한다.
  - 기본적으로 `SharedPreferences`가 백업 대상에 포함된다.
  - 앱당 사용자별 25MB 제한이 있다.
  - 사용자가 기기 설정에서 백업을 켜야 하며, 즉시 동기화 API라기보다는 OS 백업/복원 기능이다.
  - 현재 로컬 저장 방식과 가장 잘 맞고 구현 부담이 가장 작다.
- Google Drive `appDataFolder`
  - 앱 전용 숨김 폴더에 설정/앱 데이터를 저장한다.
  - `drive.appdata` OAuth scope가 필요하다.
  - 앱만 접근할 수 있고 일반 Drive UI에는 보이지 않는다.
  - 앱이 직접 업로드/다운로드 타이밍을 제어할 수 있다.
  - Google Sign-In/OAuth 구현 부담이 있다.

권장:

- 1차: Android Auto Backup으로 `SharedPreferences` 복원을 활용
- 2차: 사용자가 명시적으로 Google 계정 동기화를 기대하는 UX가 필요하면 Google Drive `appDataFolder`

### 공통 앱 동작

- 로컬 저장소는 계속 유지한다.
- iCloud/Google 저장소는 백업 및 복원 계층으로 둔다.
- 앱 시작 시 원격 개인 저장소에서 최신 백업을 확인한다.
- 로컬 데이터가 있고 원격이 비어 있으면 원격에 업로드한다.
- 로컬이 비어 있고 원격이 있으면 원격에서 복원한다.
- 둘 다 있으면 `updatedAt` 또는 백업 버전 기준으로 병합한다.

## 자체 서버 데이터 모델 초안

자체 서버에는 사용자 개인 일정/메모/카테고리를 저장하지 않는다. 모델은 앱 기능과 운영 데이터에
한정한다.

```text
calendar_months
  year
  month
  available
  source                -- cbck/cloudflare/manual
  payload_json
  fetched_at
  updated_at

app_config
  key
  value_json
  description
  updated_at

notices
  id
  title
  body
  starts_at
  ends_at
  created_at
  updated_at

admin_audit_logs
  id
  admin_user_id
  action
  target_type
  target_id
  ip
  user_agent
  created_at
```

전례력 데이터와 공지처럼 관리자 수정이 가능한 데이터는 처음부터 수정 이력 또는 감사 로그를 남기는
것이 좋다. 실수 복구와 운영 추적에 유리하다.

## 개인 데이터 백업/복원 정책

초기 버전은 단순 정책으로 시작한다. 여기서 말하는 원격 저장소는 자체 서버가 아니라 iCloud 또는
Google 계정의 앱 전용 저장소다.

- 앱 시작 시 iCloud/Google 저장소에서 사용자 데이터 백업 확인
- 로컬에만 데이터가 있고 원격 개인 저장소가 비어 있으면 원격에 업로드
- 로컬이 비어 있고 원격 개인 저장소가 있으면 복원
- 양쪽 모두 있으면 백업 문서의 `updatedAt` 또는 `schemaVersion` 기준으로 병합
- 같은 일정 ID가 양쪽에서 수정되었으면 최신 수정 시각 기준으로 통일

사용자 입장에서는 “앱 삭제 후 재설치하면 같은 iCloud/Google 계정에서 복원”이 가장 중요하므로,
최초 버전은 완전한 실시간 동기화보다 백업/복원 안정성을 우선한다.

## 관리자 페이지

관리자 페이지는 별도 Next.js 또는 SvelteKit 같은 웹 앱으로 두고, 서버 API를 통해 DB를 조작하는
구조를 권장한다. DB에 직접 접속하는 관리자 도구만 사용하는 것은 빠르지만, 실수와 권한 관리에
취약하다.

필수 기능:

- 로그인 및 관리자 권한 확인
- 전례력 월별 데이터 조회
- 전례력 데이터 수동 추가/수정/삭제
- Cloudflare Worker에서 특정 월 재동기화
- 앱 버전별 요청량, 캐시 hit/miss, 최근 오류 확인
- 서버 헬스체크와 DB 연결 상태 확인
- 관리자 작업 감사 로그 조회

주의:

- 관리자 페이지에는 사용자 일정/메모 조회 기능을 만들지 않는다.
- 사용자 개인 데이터가 서버에 없다는 원칙을 깨는 임시 기능도 만들지 않는다.
- 삭제/대량 수정은 확인 단계와 감사 로그를 둔다.

## 보안 체크리스트

### 서버 노출

- 직접 포트포워딩보다 Cloudflare Tunnel 사용
- 관리자 페이지는 Cloudflare Access 또는 별도 2FA 뒤에 배치
- 공개 API와 관리자 API 도메인 분리 권장
- `/admin` 경로를 단순히 숨기는 방식에 의존하지 않기

### 인증/인가

- 공개 앱 API는 읽기 전용을 기본으로 한다.
- 관리자 권한은 일반 사용자 권한과 분리
- 관리자 작업은 감사 로그 저장
- 관리자 세션은 짧게 유지하고 2FA 또는 Cloudflare Access를 사용

### 입력 검증

- 날짜는 `YYYY-MM-DD`만 허용
- 시간은 `HH:mm`만 허용
- 공지 제목/본문, 원격 설정 값 길이 제한
- JSON payload 크기 제한
- 서버에서 모든 입력 재검증

### 개인정보

- 자체 서버에는 사용자 일정/메모/카테고리를 저장하지 않는다.
- 운영 로그에 IP, User-Agent 등 접속 로그가 남을 수 있으므로 보관 기간을 정한다.
- 앱 개인정보 처리방침에는 개인 일정이 iCloud/Google 계정의 앱 전용 저장소에 저장될 수 있음을 명시한다.
- 내 서버에 저장되는 항목과 플랫폼 개인 클라우드에 저장되는 항목을 명확히 구분해서 고지한다.
- 서버 로그에 토큰, 개인 일정 JSON, 메모가 남지 않도록 로깅 필터를 둔다.

### DB

- 매일 자동 백업
- 백업 파일 암호화
- 백업을 서버 외부 위치에도 보관
- 복구 리허설 정기 수행
- DB 계정은 앱용/관리자용/백업용 분리
- 앱 서버 DB 계정에는 필요한 권한만 부여

### 운영

- 서버 헬스체크
- 디스크 사용량 알림
- DB 백업 실패 알림
- API 오류율/응답시간 모니터링
- OS와 런타임 보안 업데이트
- `.env`와 비밀키를 Git에 커밋하지 않기

## 장애 대응

전례력 데이터는 앱에 로컬 폴백이 있으므로 서버 장애 시에도 기본 달력은 동작할 수 있다.
사용자 개인 데이터 백업/복원은 iCloud/Google 저장소 장애 시 로컬 저장을 유지하고, 저장소가 복구되면
재시도하는 방식이 좋다.

권장 장애 흐름:

- 자체 서버 응답 성공: 서버 데이터 사용
- 자체 서버 장애: 전례력은 기존 Cloudflare Worker 또는 앱 로컬 데이터로 폴백
- iCloud/Google 업로드 실패: 로컬에 변경사항 보관 후 다음 실행/네트워크 복구 시 재시도
- 원격 개인 저장소와 로컬 충돌: `updatedAt` 또는 명시적 병합 정책 적용

## 구현 단계 제안

운영 절차와 자동화 스크립트 설계는 `docs/self-hosted-operations-guide.md`를 함께 따른다.

### 1단계: 자체 서버 뼈대

- Mac mini에 Docker Compose 기반 서버 구성
- PostgreSQL 추가
- `GET /kcc/v1/health` 구현
- `GET /kcc/v1/calendar/:year/:month` 구현
- DB miss 시 기존 Cloudflare Worker로 조회 후 DB 저장

### 2단계: 관리자 페이지 MVP

- 관리자 로그인
- 전례력 월별 조회
- 특정 월 재동기화
- 수동 수정 기능
- 감사 로그 저장

### 3단계: 플랫폼 개인 클라우드 백업/복원

- iOS: iCloud Key-Value Store 백업/복원 구현
- Android: Auto Backup 설정 검증
- 필요 시 Android Google Drive `appDataFolder` 구현 검토
- 앱 삭제 후 재설치 복원 테스트
- 로컬 데이터와 iCloud/Google 저장소 데이터 병합 정책 구현

### 4단계: 안정화

- 자동 백업
- 모니터링/알림
- Rate Limit
- 관리자 2FA
- 플랫폼 개인 클라우드 데이터 초기화 기능
- 개인정보 처리방침 업데이트

### 5단계: 확장

- iOS CloudKit Private Database 전환 검토
- Android Google Drive `appDataFolder` 명시적 동기화 검토
- 여러 기기 충돌 처리 개선
- 푸시 알림 연동 검토
- 필요 시 DB 또는 전체 서버를 관리형 클라우드로 이전

## 결론

제안한 큰 방향은 타당하다. 특히 기존 Cloudflare Worker를 버리지 않고, 자체 서버의 DB miss fallback으로
활용하는 구조는 안정성과 개발 속도 사이의 균형이 좋다.

수정된 방향처럼 자체 서버에 사용자 개인 일정/메모를 저장하지 않으면, 자체 서버가 “개인 데이터
보관 시스템”이 되는 위험을 상당히 줄일 수 있다. 대신 iCloud/Google 저장소 연동 실패, 플랫폼별
복원 UX 차이, 충돌 처리 정책은 앱 안에서 책임져야 한다.

초기에는 다음 순서로 작게 검증하는 것을 권장한다.

1. 자체 서버가 전례력 캐시 프록시 역할을 안정적으로 수행하는지 확인
2. 관리자 페이지로 전례력 데이터를 안전하게 관리
3. iOS iCloud Key-Value Store 기반 백업/복원 추가
4. Android Auto Backup 동작 검증
5. 백업, 모니터링, 개인정보 정책까지 운영 체계 완성

가장 중요한 설계 원칙은 “자체 서버는 앱 기능용 공용 데이터만 담당하고, 사용자 개인 데이터는
플랫폼 개인 클라우드에 둔다”는 경계를 유지하는 것이다.

## 참고 공식 문서

- Apple iCloud Key-Value Store: https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForKey-ValueDataIniCloud.html
- Apple CloudKit Private Database: https://developer.apple.com/documentation/CloudKit/CKContainer/privateCloudDatabase
- Android Auto Backup: https://developer.android.com/identity/data/autobackup
- Google Drive appDataFolder: https://developers.google.com/workspace/drive/api/guides/appdata
