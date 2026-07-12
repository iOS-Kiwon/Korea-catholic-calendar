#!/usr/bin/env bash
#
# 가톨릭 달력 — 실행 스크립트
#
# 기본은 release 모드로 실행하므로 "DEBUG" 요소가 없습니다.
# (참고: 우측 상단 DEBUG 배너는 코드에서 이미 꺼져 있어 debug 모드에서도 안 보입니다.)
#
# 사용법:
#   ./run.sh                    # 연결된 첫 기기에서 실행
#   ./run.sh ios                # 연결된 첫 iOS 실기기
#   ./run.sh ios simulator      # 연결된 첫 iOS 시뮬레이터
#   ./run.sh android            # 연결된 첫 Android 실기기
#   ./run.sh android simulator  # 연결된 첫 Android 에뮬레이터
#   ./run.sh all                # iOS + Android 실기기 동시 실행 (백그라운드, 로그: build/run-logs/)
#   ./run.sh <deviceId>         # 특정 기기 (flutter devices 로 ID 확인)
#
# 모드 변경:  MODE=debug ./run.sh ios   (release[기본] | debug | profile)
# Android 에뮬레이터 지정: ANDROID_AVD=Medium_Phone_API_36.1 ./run.sh android simulator
#
# 참고: 물리 iOS 기기는 flutter run(디버거 실행)이 구형 iOS+최신 Xcode 조합에서
# 실패하므로, 자동으로 flutter install(설치 전용)만 수행합니다. 설치 후 홈 화면에서
# 아이콘을 탭해 실행하세요. (시뮬레이터/안드로이드는 그대로 flutter run)
#
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")"

TARGET="${1:-auto}"
DEVICE_KIND="${2:-device}"
MODE="${MODE:-release}"
info() { printf "\033[1;34m[run]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[run] ⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[run] ✗ %s\033[0m\n" "$*"; }

command -v flutter >/dev/null 2>&1 || { err "flutter 명령을 찾을 수 없습니다 (PATH 확인)"; exit 1; }

android_sdk_dir() {
  if [ -n "${ANDROID_HOME:-}" ]; then
    printf "%s\n" "$ANDROID_HOME"
  elif [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    printf "%s\n" "$ANDROID_SDK_ROOT"
  elif [ -d "$HOME/Library/Android/sdk" ]; then
    printf "%s\n" "$HOME/Library/Android/sdk"
  fi
}

adb_cmd() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi
  local sdk
  sdk="$(android_sdk_dir)"
  if [ -n "$sdk" ] && [ -x "$sdk/platform-tools/adb" ]; then
    printf "%s\n" "$sdk/platform-tools/adb"
    return 0
  fi
  return 1
}

emulator_cmd() {
  if command -v emulator >/dev/null 2>&1; then
    command -v emulator
    return 0
  fi
  local sdk
  sdk="$(android_sdk_dir)"
  if [ -n "$sdk" ] && [ -x "$sdk/emulator/emulator" ]; then
    printf "%s\n" "$sdk/emulator/emulator"
    return 0
  fi
  return 1
}

# 지정 플랫폼(ios|android)과 종류(device|simulator)에 맞는 첫 번째 기기 ID를 출력.
pick_device() {
  flutter devices --machine 2>/dev/null | python3 -c '
import sys, json
plat = sys.argv[1]
kind = sys.argv[2]
try:
    devs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in devs:
    tp = str(d.get("targetPlatform", ""))
    is_emulator = bool(d.get("emulator", False))
    platform_matches = (
        (plat == "ios" and tp.startswith("ios")) or
        (plat == "android" and tp.startswith("android"))
    )
    kind_matches = (
        (kind == "simulator" and is_emulator) or
        (kind == "device" and not is_emulator)
    )
    if platform_matches and kind_matches:
        print(d["id"])
        break
' "$1" "$2"
}

# 기기 메타데이터 출력: "<targetPlatform> <emulator(true|false)>"
device_meta() {
  flutter devices --machine 2>/dev/null | python3 -c '
import sys, json
tid = sys.argv[1]
try:
    devs = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in devs:
    if d.get("id") == tid:
        print(str(d.get("targetPlatform", "")), str(d.get("emulator", False)).lower())
        break
' "$1"
}

first_android_avd() {
  local emulator_bin="$1"
  if [ -n "${ANDROID_AVD:-}" ]; then
    printf "%s\n" "$ANDROID_AVD"
    return 0
  fi
  "$emulator_bin" -list-avds 2>/dev/null | sed '/^[[:space:]]*$/d' | head -n 1
}

wait_for_android_emulator() {
  local timeout="${1:-120}"
  local elapsed=0
  local dev=""

  while [ "$elapsed" -lt "$timeout" ]; do
    dev="$(pick_device android simulator)"
    if [ -n "$dev" ]; then
      printf "%s\n" "$dev"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    if [ $((elapsed % 10)) -eq 0 ]; then
      info "Android 에뮬레이터 부팅 대기 중... (${elapsed}s/${timeout}s)" >&2
    fi
  done
  return 1
}

ensure_android_simulator() {
  local dev adb_bin emulator_bin avd log_file

  dev="$(pick_device android simulator)"
  if [ -n "$dev" ]; then
    printf "%s\n" "$dev"
    return 0
  fi

  adb_bin="$(adb_cmd)" || {
    err "adb를 찾을 수 없습니다. Android Studio/SDK 설치 또는 ANDROID_HOME 설정을 확인하세요." >&2
    return 1
  }
  emulator_bin="$(emulator_cmd)" || {
    err "emulator 명령을 찾을 수 없습니다. Android Studio/SDK 설치 또는 ANDROID_HOME 설정을 확인하세요." >&2
    return 1
  }
  avd="$(first_android_avd "$emulator_bin")"
  if [ -z "$avd" ]; then
    err "사용 가능한 Android AVD가 없습니다. Android Studio ▸ Device Manager에서 에뮬레이터를 생성하세요." >&2
    return 1
  fi

  mkdir -p build/run-logs
  log_file="build/run-logs/android-emulator.log"
  info "Android 에뮬레이터 시작: $avd" >&2
  info "에뮬레이터 로그: $log_file" >&2
  "$adb_bin" start-server >/dev/null 2>&1 || true
  nohup "$emulator_bin" -avd "$avd" >"$log_file" 2>&1 &

  dev="$(wait_for_android_emulator 120)" || {
    err "Android 에뮬레이터가 제한 시간 안에 Flutter 기기로 인식되지 않았습니다." >&2
    warn "로그 확인: tail -f $log_file" >&2
    return 1
  }
  printf "%s\n" "$dev"
}

# 물리 iOS 기기는 install(설치 전용), 그 외는 flutter run.
launch() { # $1 = device id, $2 = label
  local id="$1" label="$2" meta plat emu
  meta="$(device_meta "$id")"
  plat="${meta%% *}"
  emu="${meta##* }"
  if [[ "$plat" == ios* && "$emu" == "false" ]]; then
    info "$label: 물리 iOS 기기 → flutter install (설치 전용)"
    warn "이 기기(구형 iOS + 최신 Xcode)는 flutter run 자동 실행이 실패하므로 install만 수행합니다."
    if flutter install --release -d "$id"; then
      info "설치 완료 ✅  아이폰 홈 화면에서 '가톨릭 달력' 아이콘을 탭해 실행하세요."
    else
      err "설치 실패 — 아이폰 잠금 해제 후 재시도하세요."
    fi
  else
    info "$label 실행 (mode=$MODE, device=$id)"
    flutter run --"$MODE" -d "$id"
  fi
}

case "$TARGET" in
  auto)
    info "연결된 첫 기기에서 실행 (mode=$MODE)"
    flutter run --"$MODE"
    ;;
  ios|android)
    if [[ "$DEVICE_KIND" != "device" && "$DEVICE_KIND" != "simulator" ]]; then
      err "두 번째 인자는 simulator만 사용할 수 있습니다. 예: ./run.sh $TARGET simulator"
      exit 1
    fi

    if [[ "$TARGET" == "android" && "$DEVICE_KIND" == "simulator" ]]; then
      dev="$(ensure_android_simulator)"
    else
      dev="$(pick_device "$TARGET" "$DEVICE_KIND")"
    fi
    if [ -z "$dev" ]; then
      if [[ "$DEVICE_KIND" == "simulator" ]]; then
        err "$TARGET 시뮬레이터를 찾을 수 없습니다 (flutter devices 로 확인)"
      else
        err "$TARGET 실기기를 찾을 수 없습니다 (flutter devices 로 확인)"
      fi
      exit 1
    fi

    if [[ "$DEVICE_KIND" == "simulator" ]]; then
      launch "$dev" "$TARGET simulator"
    else
      launch "$dev" "$TARGET device"
    fi
    ;;
  all)
    ios_dev="$(pick_device ios device)"
    and_dev="$(pick_device android device)"
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
    launch "$TARGET" "지정 기기"
    ;;
esac
