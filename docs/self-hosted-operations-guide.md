# Mac mini 자체 서버 운영 가이드 초안

작성일: 2026-07-17

## 목적

이 문서는 서버 지식이 많지 않아도 Mac mini에서 자체 서버와 백오피스 웹사이트를 빌드, 설정, 실행,
재시작, 자동 기동할 수 있도록 하기 위한 운영 가이드 초안이다.

현재 저장소에는 Flutter 앱, Cloudflare Worker 캐시 게이트웨이, Mac mini에서 구동할 자체 API 서버와
백오피스 첫 버전이 있다. 이 문서는 현재 구현된 API 서버와 백오피스 운영 방법, 앞으로 보완할 권장
구조를 함께 정리한다.

## 현재 구현 상태

현재 구현으로 Mac mini용 자체 API 서버 뼈대, 운영 스크립트, 전례력 월별 DB 캐시, 백오피스 첫
버전이 추가되었다.

현재 포함된 것:

- `server-app/`: Node.js 기반 자체 API 서버
- `backoffice/`: Node.js 기반 백오피스 웹사이트
- `GET /kcc/v1/health`: 서버 상태 확인
- `GET /kcc/v1/calendar/:year/:month`: PostgreSQL 월별 캐시를 먼저 조회하고, 없으면 기존 Cloudflare
  Worker에서 가져와 저장 후 응답
- `GET /kcc`: 캐시된 전례력 월 목록 조회, JSON 수정, 수정 이력 확인, 되돌리기, 삭제, 재갱신
- `ops/docker-compose.yml`: API 서버와 PostgreSQL 컨테이너 구성
- `ops/.env.example`: 운영 설정 예시
- `scripts/server-*.sh`: 빌드, 시작, 중지, 재시작, 상태 확인, 로그, 백업 스크립트

아직 포함되지 않은 것:

- 앱 공지/설정 관리 화면
- 관리자별 계정/권한
- Cloudflare Tunnel 실제 설정
- launchd 실제 설치 파일

현재 단계에서는 API 서버가 전례력 월별 응답을 `calendar_months` 테이블에 캐시하고, 백오피스에서
캐시 목록 조회, JSON 수정, 수정 이력 확인, 되돌리기, 삭제, 재갱신을 수행할 수 있다.

## 전제

- Mac mini M4를 상시 켜두는 운영 서버로 사용한다.
- 자체 서버에는 사용자 개인 일정/메모/카테고리를 저장하지 않는다.
- 자체 서버는 전례력 데이터, 앱 공용 설정, 공지, 캐시 상태, 관리자 기능만 담당한다.
- 사용자 개인 데이터 백업/복원은 iCloud 또는 Google 계정의 앱 전용 저장소를 사용한다.
- 외부 접속은 직접 포트포워딩보다 Cloudflare Tunnel을 우선 검토한다.

## 권장 디렉터리 구조

향후 자체 서버와 백오피스를 추가한다면 다음 구조를 권장한다.

```text
server-app/                 # Mac mini에서 구동할 API 서버
  package.json
  src/
  Dockerfile

backoffice/                 # 관리자 웹사이트
  package.json
  src/
  Dockerfile

ops/
  docker-compose.yml
  .env.example
  launchd/
    com.sidore.catholic-calendar-server.plist

scripts/
  server-build.sh
  server-start.sh
  server-stop.sh
  server-restart.sh
  server-status.sh
  server-logs.sh
  server-backup.sh
  server-restore.sh
```

앱 빌드용 기존 `./build.sh`와 헷갈리지 않도록 서버 운영 스크립트는 `scripts/server-*.sh`로 분리하는
편이 좋다. 원한다면 루트에 `./server.sh start`, `./server.sh restart`처럼 명령을 모으는 래퍼를
둘 수 있다.

## 운영 방식 선택

### 권장: Docker Compose

서버 지식이 부족한 상태에서는 Docker Compose가 가장 관리하기 쉽다.

장점:

- API 서버, 백오피스, PostgreSQL, reverse proxy를 한 파일에서 관리할 수 있다.
- 재시작 정책을 `restart: unless-stopped`로 설정할 수 있다.
- Mac mini 재부팅 후에도 launchd가 Docker Compose를 다시 올리게 만들 수 있다.
- 서버 앱을 업데이트할 때 “빌드 → 컨테이너 교체 → 로그 확인” 흐름을 표준화하기 쉽다.

### 대안: macOS 직접 실행

Node.js/Swift/Vapor/Go 등을 macOS에서 직접 실행하고 launchd로 관리할 수도 있다. 하지만 런타임 버전,
환경 변수, 로그, DB 연결, 재시작 정책이 흩어지기 쉬워 초반 운영 난이도가 높다.

## 서버 설정

서버 설정은 코드에 직접 쓰지 말고 `.env` 파일로 분리한다.

예시:

```bash
APP_ENV=production
API_PORT=8080
HOST_API_PORT=18080
BACKOFFICE_HOST=0.0.0.0
BACKOFFICE_PORT=3000
HOST_BACKOFFICE_PORT=13000
BACKOFFICE_BASE_PATH=/kcc
PUBLIC_API_BASE_URL=https://api.sidore.org/kcc/v1
BACKOFFICE_BASE_URL=https://admin.sidore.org/kcc
API_INTERNAL_BASE_URL=http://api:8080/kcc/v1

POSTGRES_DB=catholic_calendar
POSTGRES_USER=catholic_calendar
POSTGRES_PASSWORD=change-this-long-random-password
POSTGRES_HOST=db
POSTGRES_PORT=5432
# DATABASE_URL=postgres://catholic_calendar:change-this-long-random-password@db:5432/catholic_calendar

CLOUDFLARE_WORKER_BASE_URL=https://catholic-calendar.sidore.workers.dev

ADMIN_SESSION_SECRET=change-this-long-random-secret
ADMIN_TOKEN=change-this-admin-token
BACKUP_DIR=/var/backups/catholic-calendar
```

주의:

- 실제 `.env`는 Git에 커밋하지 않는다.
- `.env.example`만 커밋한다.
- 비밀번호, 세션 secret, `ADMIN_TOKEN`은 길고 랜덤한 값으로 만든다.
- 운영 서버에서 `.env` 권한은 가능하면 소유자만 읽을 수 있게 둔다.

## Docker Compose 구성 초안

최종적으로는 아래처럼 `api`, `backoffice`, `db`를 함께 운영하는 구조를 목표로 한다.

```yaml
services:
  api:
    build:
      context: ../server-app
    env_file:
      - .env
    depends_on:
      - db
    restart: unless-stopped
    ports:
      - "127.0.0.1:${HOST_API_PORT:-8080}:${API_PORT:-8080}"

  backoffice:
    build:
      context: ../backoffice
    env_file:
      - .env
    depends_on:
      - api
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"

  db:
    image: postgres:16
    env_file:
      - .env
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

현재 `ops/docker-compose.yml`에는 1단계 범위에 맞춰 `api`와 `db`만 들어 있다. 백오피스가 구현되면
`backoffice` 서비스를 추가한다.

중요한 점:

- 포트는 `127.0.0.1`에만 바인딩한다.
- `API_PORT`는 컨테이너 내부 Node 서버 포트이고, `HOST_API_PORT`는 Mac mini에서 접근하는 포트다.
- 외부 공개는 Cloudflare Tunnel 또는 reverse proxy가 담당한다.
- DB 포트는 외부에 공개하지 않는다.
- 모든 서비스에 `restart: unless-stopped`를 둔다.

## 서버 빌드

예상 명령:

```bash
./scripts/server-build.sh
```

스크립트가 할 일:

1. Docker가 실행 중인지 확인
2. `ops/.env` 존재 여부 확인
3. API 서버 이미지 빌드
4. 백오피스 이미지 빌드
5. 설정 파일 문법 확인

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

test -f ops/.env || {
  echo "ops/.env 파일이 없습니다. ops/.env.example을 복사해 설정하세요."
  exit 1
}

docker compose -f ops/docker-compose.yml --env-file ops/.env build
```

현재 저장소에는 이 흐름을 실행하는 `scripts/server-build.sh`가 추가되어 있다.

## 서버 구동/실행

예상 명령:

```bash
./scripts/server-start.sh
```

스크립트가 할 일:

1. Docker가 실행 중인지 확인
2. DB 컨테이너 실행
3. API 서버 실행
4. 백오피스 실행
5. 헬스체크 수행

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f ops/docker-compose.yml --env-file ops/.env up -d
docker compose -f ops/docker-compose.yml ps
curl -fsS http://127.0.0.1:18080/kcc/v1/health
```

현재 저장소에는 이 흐름을 실행하는 `scripts/server-start.sh`가 추가되어 있다.

## 서버 중지

예상 명령:

```bash
./scripts/server-stop.sh
```

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f ops/docker-compose.yml --env-file ops/.env down
```

현재 저장소에는 이 흐름을 실행하는 `scripts/server-stop.sh`가 추가되어 있다.

주의:

- `down -v`는 DB 볼륨까지 지울 수 있으므로 운영 스크립트에서 쓰지 않는다.
- DB를 초기화해야 하는 특수 상황은 별도 수동 절차로 둔다.

## 서버 재시작

예상 명령:

```bash
./scripts/server-restart.sh
```

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f ops/docker-compose.yml --env-file ops/.env up -d --build
docker compose -f ops/docker-compose.yml ps
curl -fsS http://127.0.0.1:18080/kcc/v1/health
```

현재 저장소에는 이 흐름을 실행하는 `scripts/server-restart.sh`가 추가되어 있다.

## 상태 확인

예상 명령:

```bash
./scripts/server-status.sh
```

확인 항목:

- Docker 컨테이너 상태
- API `/kcc/v1/health` 응답
- DB 연결 상태
- 디스크 사용량
- 최근 오류 로그

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f ops/docker-compose.yml ps
curl -fsS http://127.0.0.1:18080/kcc/v1/health
df -h
```

현재 저장소에는 이 흐름을 실행하는 `scripts/server-status.sh`가 추가되어 있다.

## 로그 확인

예상 명령:

```bash
./scripts/server-logs.sh
./scripts/server-logs.sh api
./scripts/server-logs.sh backoffice
./scripts/server-logs.sh db
```

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SERVICE="${1:-}"
docker compose -f ops/docker-compose.yml logs -f --tail=200 $SERVICE
```

현재 저장소에는 이 흐름을 실행하는 `scripts/server-logs.sh`가 추가되어 있다.

## Mac mini 재부팅 후 자동 실행

Docker Compose의 `restart: unless-stopped`만으로는 Docker Desktop 또는 Docker 자체가 먼저 떠 있어야
한다. macOS에서는 launchd를 사용해 부팅/로그인 후 서버 시작 스크립트를 실행하도록 두는 것이 좋다.

### 1. Docker 자동 시작

Docker Desktop을 사용한다면:

1. Docker Desktop 설정에서 “Start Docker Desktop when you sign in”을 켠다.
2. Mac mini가 정전 후 자동 부팅되도록 macOS 전원 설정을 확인한다.
3. 가능하면 UPS를 사용해 갑작스러운 전원 차단을 줄인다.

서버 용도로는 Docker Desktop보다 Colima 또는 OrbStack 같은 대안도 가능하지만, 초보 운영에서는
가장 익숙한 도구 하나로 고정하는 것이 좋다.

### 2. launchd plist

`ops/launchd/com.sidore.catholic-calendar-server.plist` 예시:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.sidore.catholic-calendar-server</string>

  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOUR_USER/Git/Korea-catholic-calendar/scripts/server-start.sh</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/YOUR_USER/Git/Korea-catholic-calendar</string>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <false/>

  <key>StandardOutPath</key>
  <string>/tmp/catholic-calendar-server-launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>/tmp/catholic-calendar-server-launchd.err.log</string>
</dict>
</plist>
```

설치:

```bash
cp ops/launchd/com.sidore.catholic-calendar-server.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.sidore.catholic-calendar-server.plist
launchctl start com.sidore.catholic-calendar-server
```

수정 후 재적용:

```bash
launchctl unload ~/Library/LaunchAgents/com.sidore.catholic-calendar-server.plist
launchctl load ~/Library/LaunchAgents/com.sidore.catholic-calendar-server.plist
```

확인:

```bash
launchctl list | grep catholic-calendar
./scripts/server-status.sh
```

주의:

- `ProgramArguments`의 경로는 실제 Mac mini repo 위치로 바꿔야 한다.
- launchd는 로그인 사용자 환경의 PATH를 그대로 쓰지 않는다. 스크립트 안에서 필요한 PATH를 명시한다.
- Docker가 완전히 뜨기 전에 스크립트가 실행될 수 있으므로 `server-start.sh`에 Docker 대기 로직을
  넣는 것이 좋다.

## Docker 대기 로직

`server-start.sh`에 다음과 같은 대기 로직을 넣으면 재부팅 직후 실패 가능성을 줄일 수 있다.

```bash
wait_for_docker() {
  for i in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    echo "Docker 시작 대기 중... $i/60"
    sleep 2
  done
  echo "Docker가 준비되지 않았습니다."
  return 1
}

wait_for_docker
```

## 백오피스 웹사이트 빌드

백오피스 첫 버전은 `backoffice/`의 Node.js 서버로 구현되어 있고, Docker 이미지 빌드 안에서 필요한
의존성을 설치한다.

예상 흐름:

```bash
./scripts/server-build.sh
./scripts/server-restart.sh
```

백오피스 설정 예시:

```bash
BACKOFFICE_BASE_URL=https://admin.sidore.org/kcc
BACKOFFICE_BASE_PATH=/kcc
BACKOFFICE_PORT=3000
HOST_BACKOFFICE_PORT=13000
API_INTERNAL_BASE_URL=http://api:8080/kcc/v1
ADMIN_SESSION_SECRET=change-this-long-random-secret
ADMIN_TOKEN=change-this-admin-token
```

Mac mini 로컬 확인 URL:

```text
http://127.0.0.1:13000/kcc
```

`ADMIN_TOKEN`이 설정되어 있으면 브라우저의 Basic Auth 로그인 창에 사용자 이름 `admin`, 비밀번호
`ADMIN_TOKEN` 값을 입력한다.

백오피스 첫 버전에서 가능한 작업:

- 월별 캐시 목록 조회
- 월별 JSON 직접 수정
- 월별 수정 이력 확인
- 이전 버전으로 되돌리기
- 월별 캐시 삭제
- 월별 캐시 재갱신
- 관리자 변경 작업 감사 로그 조회

JSON 수정으로 저장한 월은 `source = manual`로 표시된다. 이후 같은 월에서 `재갱신`을 누르면 수동 수정
내용이 외부 데이터로 덮어써질 수 있으므로 주의한다.

JSON 수정은 바로 저장되지 않고 다음 흐름을 따른다.

1. 수정 화면에서 JSON 입력
2. JSON 문법 검증
3. 이전 값과 수정 값의 diff 확인
4. 최종 저장 버튼으로 DB 반영

JSON 파싱이 실패하면 diff 확인 단계로 넘어가지 않고 DB에도 반영되지 않는다.

수동 수정, 삭제, 재갱신, 되돌리기를 실행하기 전에는 기존 월별 JSON이 `calendar_month_revisions`
테이블에 자동 저장된다. 백오피스의 `이력` 화면에서 이전 JSON을 확인하고 해당 버전으로 되돌릴 수
있다. 되돌리기 자체도 현재 상태를 다시 이력으로 저장한 뒤 반영한다.

수동 수정, 삭제, 재갱신, 되돌리기가 성공하면 별도로 `admin_audit_logs` 테이블에 관리자 작업 로그가
저장된다. 백오피스의 `감사 로그` 화면에서 최근 200건의 작업 시각, 작업 종류, 대상 월, 접속 IP,
User-Agent, 세부 JSON을 확인할 수 있다. JSON 검증 실패나 diff 확인 단계처럼 DB 변경이 없는 작업은
감사 로그에 남기지 않는다.

주의:

- 백오피스는 공개 앱 API와 다른 도메인을 쓰는 편이 좋다.
- Cloudflare Access 또는 2FA를 앞단에 둔다.
- 현재 첫 버전은 Cloudflare Access와 Basic Auth를 전제로 한다.
- 다음 단계에서는 관리자 로그인 실패 횟수 제한, 관리자별 계정/권한을 둔다.
- 장기적으로는 DB에 직접 붙는 구조보다 API 서버의 관리자 API를 통해 수정하도록 한다.

## Cloudflare Tunnel 설정

권장 도메인:

```text
api.sidore.org      -> http://127.0.0.1:18080
admin.sidore.org    -> http://127.0.0.1:13000
```

권장 정책:

- `admin.sidore.org/kcc`는 Cloudflare Access로 보호
- `api.sidore.org`는 공개하되 Rate Limit 적용
- 관리자 페이지와 API 서버를 같은 origin에 섞지 않는다.
- 백오피스 앱은 `/kcc` base path에서 동작하도록 빌드/라우팅 설정을 둔다.

Cloudflare Tunnel 자체도 Mac mini 재부팅 후 자동 실행되어야 한다. `cloudflared service install` 또는
launchd 기반 자동 시작을 사용한다.

### 실제 적용된 KCC API Tunnel 설정

Mac mini에서는 기존 `wishingnote` 터널에 `api.sidore.org` ingress를 추가했다. 설정 파일 위치:

```bash
/etc/cloudflared/config.yml
```

KCC API에 필요한 ingress 항목:

```yaml
ingress:
  # KCC API
- hostname: api.sidore.org
  service: http://localhost:18080

  # 기존 서비스들...

  # 기본 fallback
- service: http_status:404
```

주의:

- `api.sidore.org` 항목은 반드시 fallback인 `http_status:404`보다 위에 있어야 한다.
- `api.sidore.org`의 Cloudflare DNS는 Tunnel 대상 `wishingnote`로 연결한다.
- Cloudflare UI에서 `api.sidore.org`가 타입 `터널`, 대상 `wishingnote`, 프록시됨으로 보이면 정상이다.
- `cloudflared tunnel route dns wishingnote api.sidore.org`가 현재 계정의 다른 zone 아래에
  `api.sidore.org.wishingnote.net` 같은 레코드를 만들 수 있으므로, `sidore.org` zone에서는
  Cloudflare Dashboard에서 직접 Tunnel DNS를 확인하는 편이 안전하다.

설정 문법 확인:

```bash
cloudflared tunnel --config /etc/cloudflared/config.yml ingress validate
```

### cloudflared LaunchDaemon 설정

`sudo cloudflared service install`만 실행하면 macOS LaunchDaemon의 `ProgramArguments`가
`/opt/homebrew/bin/cloudflared` 하나만 들어갈 수 있다. 이 상태에서는 터널 이름을 몰라 다음 로그를
반복하며 실행에 실패한다.

```text
Use `cloudflared tunnel run` to start tunnel wishingnote
```

`/Library/LaunchDaemons/com.cloudflare.cloudflared.plist`의 `ProgramArguments`는 다음처럼 터널 실행
인자를 명시해야 한다.

```xml
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/cloudflared</string>
  <string>tunnel</string>
  <string>--config</string>
  <string>/etc/cloudflared/config.yml</string>
  <string>run</string>
  <string>wishingnote</string>
</array>
```

plist 수정 후 권한은 root daemon 규칙에 맞춘다.

```bash
sudo chown root:wheel /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
sudo chmod 644 /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
plutil -lint /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
```

최신 macOS에서는 `launchctl load`보다 `bootstrap/kickstart`를 사용한다.

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.cloudflare.cloudflared.plist 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
sudo launchctl kickstart -k system/com.cloudflare.cloudflared
```

정상 실행 확인:

```bash
ps aux | grep cloudflared | grep -v grep
sudo launchctl print system/com.cloudflare.cloudflared | head -80
```

정상 프로세스 예:

```text
/opt/homebrew/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run wishingnote
```

외부 API 확인:

```bash
curl -fsS https://api.sidore.org/kcc/v1/health
curl -fsS https://api.sidore.org/kcc/v1/calendar/2026/7 | head
```

### 실제 적용할 KCC 백오피스 Tunnel 설정

백오피스는 외부에 바로 공개하지 말고 Cloudflare Access로 보호한 뒤 연결한다.

Mac mini 로컬 백오피스 확인:

```bash
curl -fsS http://127.0.0.1:13000/health
```

`/etc/cloudflared/config.yml`의 ingress에 `admin.sidore.org`를 fallback보다 위에 추가한다.

```yaml
ingress:
  # KCC API
- hostname: api.sidore.org
  service: http://localhost:18080

  # KCC Backoffice
- hostname: admin.sidore.org
  service: http://localhost:13000

  # WishingNote PRD
- hostname: v2.wishingnote.net
  service: http://localhost:8080

  # WishingNote DEV
- hostname: dev.wishingnote.net
  service: http://localhost:8081

  # 기본 fallback
- service: http_status:404
```

주의:

- `admin.sidore.org` 항목도 반드시 fallback인 `http_status:404`보다 위에 있어야 한다.
- Cloudflare Tunnel ingress는 위에서 아래로 매칭되므로 더 구체적인 hostname을 먼저 둔다.
- ingress 파일의 마지막 규칙은 catch-all fallback이어야 한다.

설정 문법 확인:

```bash
cloudflared tunnel --config /etc/cloudflared/config.yml ingress validate
```

어떤 규칙에 매칭되는지 확인:

```bash
cloudflared tunnel --config /etc/cloudflared/config.yml ingress rule https://admin.sidore.org/kcc
```

DNS 확인:

Cloudflare Dashboard의 `sidore.org` DNS에서 `admin.sidore.org`를 Tunnel `wishingnote` 대상으로 추가한다.
UI에서 타입이 `터널`, 대상이 `wishingnote`, 프록시됨으로 보이면 정상이다. CLI로 시도할 때 다른 zone에
잘못 생성될 수 있으므로 이 도메인은 Dashboard 확인을 우선한다.

터널 재시작:

```bash
sudo launchctl kickstart -k system/com.cloudflare.cloudflared
```

터널 상태 확인:

```bash
ps aux | grep cloudflared | grep -v grep
sudo launchctl print system/com.cloudflare.cloudflared | head -80
```

외부 백오피스 확인:

```bash
curl -I https://admin.sidore.org/kcc
```

Cloudflare Access 적용 전에는 외부에서 이 URL을 열지 않는다. Access가 적용되면 브라우저에서
`https://admin.sidore.org/kcc` 접속 시 Cloudflare 로그인 화면이 먼저 보여야 한다.

### Cloudflare Access 보호 설정

`admin.sidore.org`는 Tunnel DNS 연결만으로 끝내지 말고 반드시 Access Application으로 보호한다.

권장 설정:

- Application type: Self-hosted
- Application domain: `admin.sidore.org`
- Path: `/kcc*`
- Policy action: Allow
- Include rule: 본인 이메일 또는 허용할 관리자 이메일
- Session duration: 짧게 시작한다. 예: 8시간 이하
- 가능하면 MFA 또는 Cloudflare 계정의 2단계 인증을 켠다.

설정 후 확인할 것:

- 로그인하지 않은 브라우저/private window에서 `https://admin.sidore.org/kcc` 접속
- Cloudflare Access 로그인 화면이 먼저 나오는지 확인
- 허용된 이메일로 로그인 후 백오피스 Basic Auth가 한 번 더 나오는지 확인
- Basic Auth 사용자 이름은 `admin`, 비밀번호는 `ops/.env`의 `ADMIN_TOKEN`

이중 보호 구조:

1. Cloudflare Access: 외부 접근자 제한
2. 백오피스 Basic Auth: 앱 내부 관리자 비밀번호

Cloudflare Access가 적용되기 전까지는 `admin.sidore.org` DNS나 ingress를 추가하지 않는 편이 가장
안전하다. 이미 추가했다면 Access 정책을 먼저 켠 뒤 외부 테스트를 진행한다.

### Mac mini DNS 주의사항

Mac mini에서 `dig api.sidore.org`는 성공하지만 `curl`/Python이 `Could not resolve host` 또는
`nodename nor servname provided`로 실패하면 macOS 시스템 DNS resolver 문제일 수 있다.

실제 운영 중 Ethernet DNS를 Cloudflare DNS로 변경해 해결했다.

```bash
sudo networksetup -setdnsservers "Ethernet" 1.1.1.1 1.0.0.1
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

확인:

```bash
networksetup -getdnsservers "Ethernet"
scutil --dns | head -40
curl -4 -v https://api.sidore.org/kcc/v1/health
```

Cloudflare `error code: 1033`이 나오면 DNS는 Cloudflare까지 도달했지만 터널 연결이 없는 상태다.
이때는 `ps aux | grep cloudflared`, LaunchDaemon 상태, `/Library/Logs/com.cloudflare.cloudflared.err.log`
를 확인한다.

## DB 백업

PostgreSQL을 쓴다면 최소 매일 1회 `pg_dump` 백업을 만든다.

예상 명령:

```bash
./scripts/server-backup.sh
```

예상 구현:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p backups
STAMP="$(date +%Y%m%d-%H%M%S)"
docker compose -f ops/docker-compose.yml exec -T db \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "backups/db-$STAMP.sql"
```

보완할 점:

- 현재 `scripts/server-backup.sh`는 `ops/.env`를 읽어 `POSTGRES_USER`, `POSTGRES_DB`를 가져온다.
- 백업 파일은 암호화한다.
- Mac mini 내부 디스크 외부에도 복사한다.
- 복구 테스트를 정기적으로 한다.

## 1단계 검증 기록

개발 환경에는 Docker가 설치되어 있지 않아 Docker Compose 실행까지는 검증하지 못했다.

검증한 것:

- shell 스크립트 문법 검사: `bash -n scripts/server-*.sh`
- API 서버 JS 문법 검사: `node --check server-app/src/index.js`
- API 서버 로컬 기동
- `GET /kcc/v1/health` 응답 확인
- `GET /kcc/v1/calendar/2026/7`이 Cloudflare Worker 응답을 프록시하는 것 확인

9단계에서 추가된 전례력 캐시는 Mac mini Docker 환경에서 확인해야 한다.

Mac mini에서 추가로 확인해야 할 것:

- Docker 설치 및 실행
- `cp ops/.env.example ops/.env`
- `ops/.env`에서 `API_PORT=8080`, `HOST_API_PORT=18080` 확인
- `ops/.env`에서 `BACKOFFICE_PORT=3000`, `HOST_BACKOFFICE_PORT=13000`, `ADMIN_TOKEN` 확인
- `./scripts/server-build.sh`
- `./scripts/server-start.sh`
- `./scripts/server-status.sh`
- `./scripts/server-backup.sh`

전례력 캐시 확인:

```bash
curl -i http://127.0.0.1:18080/kcc/v1/calendar/2026/7
curl -i http://127.0.0.1:18080/kcc/v1/calendar/2026/7
```

첫 요청은 `x-calendar-cache: miss`, 두 번째 요청은 `x-calendar-cache: hit`가 나와야 한다. DB에 저장된
월별 캐시는 다음 명령으로 확인한다.

```bash
docker compose -f ops/docker-compose.yml --env-file ops/.env exec db \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB" \
  -c "select year, month, source, fetched_at, updated_at from calendar_months order by year, month;"
```

백오피스 확인:

```bash
curl -fsS http://127.0.0.1:13000/health
```

브라우저에서는 `http://127.0.0.1:13000/kcc`로 접속한다. 원격에서 확인할 때는 Cloudflare Tunnel에
`admin.sidore.org -> http://localhost:13000` ingress를 추가한 뒤 `https://admin.sidore.org/kcc`로
접속한다.

백오피스 외부 연결 확인:

- Cloudflare Access Application 생성
- `admin.sidore.org` Tunnel DNS 추가
- `/etc/cloudflared/config.yml`에 `admin.sidore.org -> http://localhost:13000` ingress 추가
- `cloudflared tunnel --config /etc/cloudflared/config.yml ingress validate`
- `sudo launchctl kickstart -k system/com.cloudflare.cloudflared`
- private window에서 `https://admin.sidore.org/kcc` 접속
- Cloudflare Access 로그인 후 Basic Auth 로그인 확인

## 배포/업데이트 절차

코드 업데이트 후:

```bash
git pull
./scripts/server-build.sh
./scripts/server-restart.sh
./scripts/server-status.sh
```

문제가 생기면:

```bash
./scripts/server-logs.sh api
./scripts/server-logs.sh backoffice
```

업데이트 전에는 가능한 한 백업을 먼저 만든다.

```bash
./scripts/server-backup.sh
```

## 자동화 가능성 검토

자동화는 충분히 가능하다. 권장 자동화 범위는 다음과 같다.

- `server-build.sh`
  - API/백오피스 Docker 이미지 빌드
  - 설정 파일 존재 확인
- `server-start.sh`
  - Docker 준비 대기
  - Docker Compose 실행
  - 헬스체크
- `server-stop.sh`
  - 컨테이너 중지
- `server-restart.sh`
  - 빌드 후 재실행
  - 헬스체크
- `server-status.sh`
  - 컨테이너/헬스체크/디스크 상태 확인
- `server-logs.sh`
  - 서비스별 로그 확인
- `server-backup.sh`
  - DB 백업 생성
- `server-install-launchd.sh`
  - launchd plist 설치
- `server-uninstall-launchd.sh`
  - launchd plist 제거

단, 다음은 완전 자동화보다 수동 확인을 권장한다.

- 최초 `.env` 작성
- DB 비밀번호/세션 secret 생성
- Cloudflare Tunnel 최초 로그인/등록
- 운영 DB 삭제/초기화
- 백업 복구

## 최소 운영 체크리스트

처음 서버를 올릴 때:

1. Docker 설치 및 자동 시작 설정
2. repo clone
3. `ops/.env.example`을 `ops/.env`로 복사 후 값 입력
4. `./scripts/server-build.sh`
5. `./scripts/server-start.sh`
6. `./scripts/server-status.sh`
7. Cloudflare Tunnel 연결
8. 관리자 페이지 접속 확인
9. `./scripts/server-backup.sh` 실행 확인
10. launchd 자동 시작 설정
11. Mac mini 재부팅 후 자동 복구 확인

정전/재부팅 후 확인:

1. Mac mini가 켜졌는지 확인
2. Docker가 실행 중인지 확인
3. `./scripts/server-status.sh`
4. `./scripts/server-logs.sh api`
5. `./scripts/server-logs.sh backoffice`
6. 외부에서 `https://api.sidore.org/kcc/v1/health` 확인
7. 관리자 페이지 접속 확인

## 결론

서버와 백오피스 구현이 끝난 뒤에도 운영을 사람이 손으로 기억해서 처리하면 오래 유지하기 어렵다.
처음부터 Docker Compose, `.env`, `scripts/server-*.sh`, launchd 자동 시작, 백업 스크립트를 함께
만드는 것이 좋다.

가장 중요한 목표는 다음 네 가지다.

1. 명령 하나로 빌드할 수 있다.
2. 명령 하나로 시작/재시작/상태 확인을 할 수 있다.
3. Mac mini 재부팅 후 자동으로 다시 살아난다.
4. 문제가 생겼을 때 로그와 백업으로 복구할 수 있다.
