#!/usr/bin/env bash
#
# 가톨릭 달력 — 실행 스크립트
#
# 기본은 release 모드로 실행하므로 "DEBUG" 요소가 없습니다.
# (참고: 우측 상단 DEBUG 배너는 코드에서 이미 꺼져 있어 debug 모드에서도 안 보입니다.)
#
# 사용법:
#   ./run.sh              # 연결된 첫 기기에서 실행
#   ./run.sh ios          # 연결된 첫 iOS 기기/시뮬레이터
#   ./run.sh android      # 연결된 첫 Android 기기/에뮬레이터
#   ./run.sh all          # iOS + Android 동시 실행 (백그라운드, 로그: build/run-logs/)
#   ./run.sh <deviceId>   # 특정 기기 (flutter devices 로 ID 확인)
#
# 모드 변경:  MODE=debug ./run.sh ios   (release[기본] | debug | profile)
#
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")"

TARGET="${1:-auto}"
MODE="${MODE:-release}"
info() { printf "\033[1;34m[run]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[run] ⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[run] ✗ %s\033[0m\n" "$*"; }

command -v flutter >/dev/null 2>&1 || { err "flutter 명령을 찾을 수 없습니다 (PATH 확인)"; exit 1; }

# 지정 플랫폼(ios|android)의 첫 번째 기기 ID를 출력.
pick_device() {
  flutter devices --machine 2>/dev/null | python3 -c '
import sys, json
plat = sys.argv[1]
try:
    devs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in devs:
    tp = str(d.get("targetPlatform", ""))
    if (plat == "ios" and tp.startswith("ios")) or \
       (plat == "android" and tp.startswith("android")):
        print(d["id"]); break
' "$1"
}

run_fg() { # $1 = device id, $2 = label
  info "$2 실행 (mode=$MODE, device=$1)"
  flutter run --"$MODE" -d "$1"
}

case "$TARGET" in
  auto)
    info "연결된 첫 기기에서 실행 (mode=$MODE)"
    flutter run --"$MODE"
    ;;
  ios|android)
    dev="$(pick_device "$TARGET")"
    [ -n "$dev" ] || { err "$TARGET 기기를 찾을 수 없습니다 (flutter devices 로 확인)"; exit 1; }
    run_fg "$dev" "$TARGET"
    ;;
  all)
    ios_dev="$(pick_device ios)"
    and_dev="$(pick_device android)"
    [ -n "${ios_dev}${and_dev}" ] || { err "실행할 iOS/Android 기기가 없습니다"; exit 1; }
    mkdir -p build/run-logs
    if [ -n "$ios_dev" ]; then
      info "iOS 백그라운드 실행 (device=$ios_dev) → build/run-logs/ios.log"
      nohup flutter run --"$MODE" -d "$ios_dev" >build/run-logs/ios.log 2>&1 &
    else warn "iOS 기기 없음 → 건너뜀"; fi
    if [ -n "$and_dev" ]; then
      info "Android 백그라운드 실행 (device=$and_dev) → build/run-logs/android.log"
      nohup flutter run --"$MODE" -d "$and_dev" >build/run-logs/android.log 2>&1 &
    else warn "Android 기기 없음 → 건너뜀"; fi
    info "백그라운드 실행 시작. 로그 확인: tail -f build/run-logs/*.log"
    info "중지: pkill -f 'flutter run'"
    wait
    ;;
  *)
    run_fg "$TARGET" "지정 기기"
    ;;
esac
