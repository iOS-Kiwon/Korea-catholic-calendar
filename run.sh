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
# 참고: iOS 시뮬레이터는 release 실행을 지원하지 않아 자동으로 debug 모드로 전환됩니다.
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

ask_bool() { # $1 = env var name, $2 = prompt, $3 = default(true|false)
  local name="$1" prompt="$2" default="$3" answer="" default_label="N"
  [ "$default" = "true" ] && default_label="Y"
  local current="${!name:-}"
  if [ -n "$current" ]; then
    printf "%s\n" "$current"
    return 0
  fi
  if [ ! -t 0 ]; then
    printf "%s\n" "$default"
    return 0
  fi
  while true; do
    printf "%s" "$prompt (Y/N, 기본 $default_label): " >&2
    read -r answer
    case "$answer" in
      [Yy]*)
        printf "true\n"
        return 0
        ;;
      [Nn]*|"")
        printf "false\n"
        return 0
        ;;
      *)
        warn "Y 또는 N으로 입력해 주세요." >&2
        ;;
    esac
  done
}

ADS_ENABLED="$(ask_bool ADS_ENABLED "광고는 표시할까요?" true)"
SHOW_REMOTE_STATUS_BADGE="$(ask_bool SHOW_REMOTE_STATUS_BADGE "서버 상태 UI를 표시할까요?" false)"
RUN_DEFINES=(
  --dart-define=ADS_ENABLED="$ADS_ENABLED"
  --dart-define=SHOW_REMOTE_STATUS_BADGE="$SHOW_REMOTE_STATUS_BADGE"
)
ANDROID_APP_ID="com.sidore.catholiccalendar"
IOS_APP_ID="com.sidore.catholiccalendar"
ANDROID_VERSION_FILE="android/release_version.properties"
IOS_VERSION_FILE="ios/release_version.properties"

command -v flutter >/dev/null 2>&1 || { err "flutter 명령을 찾을 수 없습니다 (PATH 확인)"; exit 1; }

current_pubspec_version() {
  sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1
}

read_release_version() {
  local file="$1"
  local fallback app_version build_number

  if [ -f "$file" ]; then
    app_version="$(sed -n 's/^appVersion=//p' "$file" | head -n 1)"
    build_number="$(sed -n 's/^buildNumber=//p' "$file" | head -n 1)"
  fi

  if [ -z "${app_version:-}" ] || [ -z "${build_number:-}" ]; then
    fallback="$(current_pubspec_version)"
    app_version="${fallback%%+*}"
    build_number="${fallback#*+}"
  fi

  if [[ -z "$app_version" || -z "$build_number" || ! "$app_version" =~ ^[0-9]+(\.[0-9]+){2}$ || ! "$build_number" =~ ^[0-9]+$ ]]; then
    err "버전 형식을 읽을 수 없습니다: $file"
    exit 1
  fi

  printf "%s+%s\n" "$app_version" "$build_number"
}

version_args_for_platform() {
  local plat="$1" file version app_version build_number
  case "$plat" in
    android*) file="$ANDROID_VERSION_FILE" ;;
    ios*) file="$IOS_VERSION_FILE" ;;
    *) return 0 ;;
  esac

  version="$(read_release_version "$file")"
  app_version="${version%%+*}"
  build_number="${version#*+}"
  printf -- "--build-name=%s\n--build-number=%s\n" "$app_version" "$build_number"
}

android_apk_for_mode() {
  case "$1" in
    debug) printf "build/app/outputs/flutter-apk/app-debug.apk\n" ;;
    profile) printf "build/app/outputs/flutter-apk/app-profile.apk\n" ;;
    release) printf "build/app/outputs/flutter-apk/app-release.apk\n" ;;
  esac
}

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

android_data_free_kb() {
  local id="$1" adb_bin
  adb_bin="$(adb_cmd)" || return 1
  "$adb_bin" -s "$id" shell df -k /data 2>/dev/null \
    | awk 'NR == 2 { gsub(/\r/, "", $4); print $4 }'
}

trim_android_emulator_caches() {
  local id="$1" adb_bin before after
  adb_bin="$(adb_cmd)" || return 0

  before="$(android_data_free_kb "$id" || true)"
  if [ -n "$before" ]; then
    info "Android 에뮬레이터 저장공간 확인: /data 여유 $((before / 1024))MB"
  fi

  # Safe cleanup: ask Android to trim app caches. This does not uninstall apps or
  # wipe user data, but often frees enough space for a release APK install.
  "$adb_bin" -s "$id" shell pm trim-caches 2G >/dev/null 2>&1 || true

  after="$(android_data_free_kb "$id" || true)"
  if [ -n "$after" ] && [ "$after" != "$before" ]; then
    info "Android 에뮬레이터 캐시 정리 후 /data 여유 $((after / 1024))MB"
  fi
}

is_android_install_no_space() {
  local log_file="$1"
  grep -qiE 'not enough space|INSTALL_FAILED_INSUFFICIENT_STORAGE|Requested internal only' "$log_file"
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
launch() { # $1 = device id, $2 = label, $3 = requested platform(optional)
  local id="$1" label="$2" requested_platform="${3:-}"
  local meta plat emu run_log status version_label apk_path
  local -a version_args
  meta="$(device_meta "$id")"
  plat="${meta%% *}"
  emu="${meta##* }"
  version_label="unknown"

  # flutter devices 메타데이터가 일시적으로 비어도 명시적으로 요청한
  # 플랫폼을 사용해 release_version.properties의 버전 주입이 빠지지 않도록 한다.
  if [ -z "$requested_platform" ]; then
    case "$label" in
      android*) requested_platform="android" ;;
      ios*) requested_platform="ios" ;;
    esac
  fi
  if [ -z "$plat" ]; then
    plat="$requested_platform"
  fi

  while IFS= read -r arg; do
    version_args+=("$arg")
  done < <(version_args_for_platform "${requested_platform:-$plat}")
  if [ "${#version_args[@]}" -gt 0 ]; then
    version_label="${version_args[0]#--build-name=}+${version_args[1]#--build-number=}"
    info "$label 버전: $version_label"
  fi
  if [[ "$plat" == ios* && "$emu" == "false" ]]; then
    info "$label: 물리 iOS 기기 → flutter install (설치 전용)"
    warn "이 기기(구형 iOS + 최신 Xcode)는 flutter run 자동 실행이 실패하므로 install만 수행합니다."
    info "실기기 설치용 iOS 앱 빌드/서명 중..."
    if ! flutter build ios --release "${RUN_DEFINES[@]}" "${version_args[@]}"; then
      err "iOS 앱 빌드/서명 실패 — Xcode의 Signing & Capabilities 설정을 확인하세요."
      return 1
    fi
    if flutter install --release -d "$id"; then
      info "설치 완료 ✅  아이폰 홈 화면에서 '가톨릭 달력' 아이콘을 탭해 실행하세요."
    else
      err "설치 실패 — 기기 신뢰/개발자 모드 또는 앱 서명 상태를 확인하세요."
    fi
  else
    if [[ "$plat" == ios* && "$emu" == "true" && "$MODE" == "release" ]]; then
      warn "iOS 시뮬레이터는 release 실행을 지원하지 않아 debug 모드로 전환합니다."
      MODE=debug
    fi
    info "$label 실행 (version=$version_label, mode=$MODE, ads=$ADS_ENABLED, serverBadge=$SHOW_REMOTE_STATUS_BADGE, device=$id)"
    if [[ "$plat" == ios* && "$emu" == "true" ]]; then
      info "iOS 시뮬레이터 앱 빌드 (배포 버전 주입): build/ios/iphonesimulator/Runner.app"
      if ! flutter build ios --simulator --"$MODE" "${RUN_DEFINES[@]}" "${version_args[@]}"; then
        err "iOS 시뮬레이터 앱 빌드 실패"
        return 1
      fi
      if ! xcrun simctl install "$id" build/ios/iphonesimulator/Runner.app; then
        err "iOS 시뮬레이터 설치 실패"
        return 1
      fi
      if xcrun simctl launch "$id" "$IOS_APP_ID"; then
        info "iOS 시뮬레이터 실행 완료"
        return 0
      fi
      err "iOS 시뮬레이터 실행 실패"
      return 1
    fi
    if [[ "$plat" == android* ]]; then
      mkdir -p build/run-logs
      run_log="build/run-logs/android-flutter-run.log"
      apk_path="$(android_apk_for_mode "$MODE")"
      info "Android APK 빌드 (version=$version_label, 배포 버전 주입): $apk_path"
      if ! flutter build apk --"$MODE" "${RUN_DEFINES[@]}" "${version_args[@]}"; then
        err "Android APK 빌드 실패"
        return 1
      fi
      if [[ "$emu" == "true" ]]; then
        trim_android_emulator_caches "$id"
      fi
      info "Android APK 실행 (version=$version_label): $apk_path"
      flutter run --"$MODE" -d "$id" --use-application-binary="$apk_path" 2>&1 | tee "$run_log"
      status=${PIPESTATUS[0]}
      if [[ "$emu" == "true" && "$status" -ne 0 ]] && is_android_install_no_space "$run_log"; then
        warn "에뮬레이터 저장공간 부족으로 설치가 실패했습니다. 캐시를 한 번 더 정리한 뒤 재시도합니다."
        trim_android_emulator_caches "$id"
        flutter run --"$MODE" -d "$id" --use-application-binary="$apk_path"
        status=$?
        if [ "$status" -ne 0 ]; then
          warn "계속 실패하면 에뮬레이터에서 불필요한 앱을 삭제하거나 Android Studio Device Manager에서 해당 AVD를 Wipe Data 하세요."
          warn "현재 앱만 지워도 되는 경우: $(adb_cmd 2>/dev/null || printf adb) -s $id uninstall $ANDROID_APP_ID"
        fi
      fi
      return "$status"
    fi
    flutter run --"$MODE" -d "$id" "${RUN_DEFINES[@]}"
  fi
}

case "$TARGET" in
  auto)
    info "연결된 첫 기기에서 실행 (mode=$MODE, ads=$ADS_ENABLED, serverBadge=$SHOW_REMOTE_STATUS_BADGE)"
    dev="$(pick_device android device)"
    [ -n "$dev" ] || dev="$(pick_device ios device)"
    [ -n "$dev" ] || dev="$(pick_device android simulator)"
    [ -n "$dev" ] || dev="$(pick_device ios simulator)"
    if [ -n "$dev" ]; then
      launch "$dev" "auto"
    else
      warn "모바일 기기를 찾지 못해 Flutter 기본 선택으로 실행합니다. 이 경우 배포 버전을 강제할 수 없습니다."
      flutter run --"$MODE" "${RUN_DEFINES[@]}"
    fi
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
      launch "$dev" "$TARGET simulator" "$TARGET"
    else
      launch "$dev" "$TARGET device" "$TARGET"
    fi
    ;;
  all)
    ios_dev="$(pick_device ios device)"
    and_dev="$(pick_device android device)"
    [ -n "${ios_dev}${and_dev}" ] || { err "실행할 iOS/Android 기기가 없습니다"; exit 1; }
    mkdir -p build/run-logs
    if [ -n "$ios_dev" ]; then
      info "iOS 백그라운드 실행 (device=$ios_dev) → build/run-logs/ios.log"
      nohup env ADS_ENABLED="$ADS_ENABLED" SHOW_REMOTE_STATUS_BADGE="$SHOW_REMOTE_STATUS_BADGE" MODE="$MODE" ./run.sh ios >build/run-logs/ios.log 2>&1 &
    else warn "iOS 기기 없음 → 건너뜀"; fi
    if [ -n "$and_dev" ]; then
      info "Android 백그라운드 실행 (device=$and_dev) → build/run-logs/android.log"
      nohup env ADS_ENABLED="$ADS_ENABLED" SHOW_REMOTE_STATUS_BADGE="$SHOW_REMOTE_STATUS_BADGE" MODE="$MODE" ./run.sh android >build/run-logs/android.log 2>&1 &
    else warn "Android 기기 없음 → 건너뜀"; fi
    info "백그라운드 실행 시작. 로그 확인: tail -f build/run-logs/*.log"
    info "중지: pkill -f 'flutter run'"
    wait
    ;;
  *)
    launch "$TARGET" "지정 기기"
    ;;
esac
