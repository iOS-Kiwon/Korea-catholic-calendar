#!/usr/bin/env bash
#
# 가톨릭 달력 — iOS / Android 빌드 스크립트
#
# 사용법:
#   ./build.sh                    # Android + iOS 스크린샷/테스트 빌드
#   ./build.sh android            # Android AAB
#   ./build.sh ios                # iOS no-codesign
#   ./build.sh aab                # Android AAB만
#
# 출시 빌드:
#   ./build.sh android release    # Android 버전 입력 -> Android AAB 심사용 광고 ON 빌드
#   ./build.sh aab release        # Android 버전 입력 -> Android AAB 심사용 광고 ON 빌드
#   ./build.sh ios release        # iOS 버전 입력 -> iOS IPA 심사용 광고 ON 빌드
#
# - Android: App Bundle(.aab) 릴리스 산출.
# - iOS: 기본 빌드는 서명 없이(--no-codesign) 확인, release 옵션은 IPA 산출.
# - 준비물이 없는 플랫폼은 건너뛰고 경고만 출력합니다 (BUILD_AND_RUN.md 참고).
#
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")"

TARGET="${1:-all}"
MODE="${2:-test}"
RELEASE=0
BUILD_DEFINES=(--dart-define=ADS_ENABLED=true)
ANDROID_VERSION_FILE="android/release_version.properties"
IOS_VERSION_FILE="ios/release_version.properties"
ANDROID_BUILD_ARGS=()
IOS_BUILD_ARGS=()
RELEASE_OUTPUT_DIRS=()
FAIL=0
info() { printf "\033[1;34m[build]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[build] ⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[build] ✗ %s\033[0m\n" "$*"; }

command -v flutter >/dev/null 2>&1 || { err "flutter 명령을 찾을 수 없습니다 (PATH 확인)"; exit 1; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

have_android() {
  [ -n "${ANDROID_HOME:-}" ] || [ -n "${ANDROID_SDK_ROOT:-}" ] || [ -d "$HOME/Library/Android/sdk" ]
}

remember_release_output_dir() {
  [ "$RELEASE" -eq 1 ] || return

  local dir="$1"
  local existing
  if [ "${#RELEASE_OUTPUT_DIRS[@]}" -gt 0 ]; then
    for existing in "${RELEASE_OUTPUT_DIRS[@]}"; do
      [ "$existing" = "$dir" ] && return
    done
  fi
  RELEASE_OUTPUT_DIRS+=("$dir")
}

open_release_output_dirs() {
  [ "$RELEASE" -eq 1 ] || return 0
  [ "${#RELEASE_OUTPUT_DIRS[@]}" -gt 0 ] || return 0

  if [ "$(uname)" != "Darwin" ] || ! command -v open >/dev/null 2>&1; then
    warn "Finder를 열 수 없는 환경입니다. 산출물 위치: ${RELEASE_OUTPUT_DIRS[*]}"
    return
  fi

  local dir
  for dir in "${RELEASE_OUTPUT_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      info "Finder 열기: $dir"
      open "$dir"
    fi
  done
}

require_android_release_signing() {
  [ "$RELEASE" -eq 0 ] && return

  local props="android/key.properties"
  if [ ! -f "$props" ]; then
    err "Android 심사용 release 빌드에는 $props 파일이 필요합니다."
    err "필수 키: storePassword, keyPassword, keyAlias, storeFile"
    FAIL=1
    return 1
  fi

  local missing=0 key value store_file
  for key in storePassword keyPassword keyAlias storeFile; do
    value="$(sed -n "s/^${key}=//p" "$props" | head -n 1)"
    if [ -z "$value" ]; then
      err "$props에 $key 값이 없습니다."
      missing=1
    fi
  done

  store_file="$(sed -n 's/^storeFile=//p' "$props" | head -n 1)"
  if [ -n "$store_file" ] && [ "${store_file#/}" = "$store_file" ]; then
    store_file="android/app/$store_file"
  fi
  if [ -n "$store_file" ] && [ ! -f "$store_file" ]; then
    err "Android keystore 파일을 찾을 수 없습니다: $store_file"
    missing=1
  fi

  if [ "$missing" -eq 1 ]; then
    FAIL=1
    return 1
  fi
}

current_pubspec_version() {
  sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1
}

read_release_version() {
  local file="$1"
  local fallback current_name current_number

  if [ -f "$file" ]; then
    current_name="$(sed -n 's/^appVersion=//p' "$file" | head -n 1)"
    current_number="$(sed -n 's/^buildNumber=//p' "$file" | head -n 1)"
  fi

  if [ -z "${current_name:-}" ] || [ -z "${current_number:-}" ]; then
    fallback="$(current_pubspec_version)"
    current_name="${fallback%%+*}"
    current_number="${fallback#*+}"
  fi

  if [[ -z "$current_name" || -z "$current_number" || ! "$current_name" =~ ^[0-9]+(\.[0-9]+){2}$ || ! "$current_number" =~ ^[0-9]+$ ]]; then
    err "버전 형식을 읽을 수 없습니다: $file"
    exit 1
  fi

  printf "%s+%s\n" "$current_name" "$current_number"
}

write_release_version() {
  local file="$1"
  local app_version="$2"
  local build_number="$3"

  if [ ! -f "$file" ]; then
    {
      printf "appVersion=%s\n" "$app_version"
      printf "buildNumber=%s\n" "$build_number"
    } > "$file"
    return
  fi

  perl -0pi -e "s/^appVersion=.*\$/appVersion=$app_version/m; s/^buildNumber=.*\$/buildNumber=$build_number/m" "$file"
}

version_code() {
  local IFS=.
  local -a parts
  read -r -a parts <<< "$1"
  printf "%d\n" $((10#${parts[0]} * 1000000 + 10#${parts[1]} * 1000 + 10#${parts[2]}))
}

prompt_release_version() {
  local platform file current current_name current_number current_code next_name next_number next_code same_answer android_auto build_choice
  platform="$1"
  file="$2"
  current="$(read_release_version "$file")"
  current_name="${current%%+*}"
  current_number="${current#*+}"
  current_code="$(version_code "$current_name")"

  # Android는 Google Play 규칙상 buildNumber(versionCode)가 앱 버전(versionName)과
  # 무관하게 업로드마다 반드시 증가해야 한다. 그래서 빌드번호는 입력받지 않고 무조건 +1.
  # iOS는 앱 버전을 올리면 빌드번호를 0부터 다시 시작할 수 있어 기존처럼 입력받는다.
  android_auto=0
  [ "$platform" = "Android" ] && android_auto=1

  while true; do
    printf "%s 앱 버전 입력 (현재 %s, 예: 1.2.3): " "$platform" "$current_name"
    read -r next_name

    if [[ ! "$next_name" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
      warn "$platform 앱 버전은 1.2.3 형식이어야 합니다."
      continue
    fi
    next_code="$(version_code "$next_name")"
    if ((next_code < current_code)); then
      warn "입력한 $platform 앱 버전($next_name)이 현재 버전($current_name)보다 낮습니다. 다시 입력하세요."
      continue
    fi

    if [ "$android_auto" -eq 1 ]; then
      # 빌드번호(versionCode)는 앱 버전과 무관하게 관리한다.
      # 현재 유지 / +1 / 직접 입력 중 선택 (동일 빌드번호로 다시 빌드하는 경우도 있음).
      while true; do
        printf "%s 빌드번호 (현재 %s): [Enter]=+1(%s) / s=현재 유지(%s) / 숫자 직접 입력: " \
          "$platform" "$current_number" "$((10#$current_number + 1))" "$current_number"
        read -r build_choice
        case "$build_choice" in
          "")
            next_number=$((10#$current_number + 1)) ;;
          [Ss])
            next_number=$((10#$current_number)) ;;
          *[!0-9]*)
            warn "Enter(+1) / s(현재 유지) / 0 이상의 정수 중에서 입력하세요."
            continue ;;
          *)
            if ((10#$build_choice < 10#$current_number)); then
              warn "빌드번호($build_choice)가 현재($current_number)보다 낮습니다. 같은 값 이상이어야 합니다(동일 값은 s)."
              continue
            fi
            next_number=$((10#$build_choice)) ;;
        esac
        break
      done
      info "$platform 빌드번호: $current_number -> $next_number (versionCode)"
    else
      printf "%s 빌드번호 입력 (현재 %s, 앱 버전 올림 시 0부터 가능, 예: 42): " "$platform" "$current_number"
      read -r next_number

      if [[ ! "$next_number" =~ ^[0-9]+$ ]]; then
        warn "$platform 빌드번호는 0 이상의 정수여야 합니다."
        continue
      fi
      if ((next_code == current_code && 10#$next_number < 10#$current_number)); then
        warn "입력한 $platform 빌드번호($next_number)가 현재 빌드번호($current_number)보다 낮습니다. 다시 입력하세요."
        continue
      fi
      if [ "$next_name" = "$current_name" ] && [ "$next_number" = "$current_number" ]; then
        while true; do
          printf "입력한 %s 앱 버전과 빌드번호가 현재와 동일합니다 (%s+%s). 이 값으로 빌드할까요? [y/N]: " "$platform" "$next_name" "$next_number"
          read -r same_answer
          case "$same_answer" in
            [Yy]|[Yy][Ee][Ss]) break ;;
            ""|[Nn]|[Nn][Oo])
              warn "다시 입력하세요."
              continue 2
              ;;
            *) warn "y 또는 n으로 입력하세요." ;;
          esac
        done
      fi
    fi

    write_release_version "$file" "$next_name" "$next_number"
    info "$file: $current -> $next_name+$next_number"
    case "$platform" in
      Android) ANDROID_BUILD_ARGS=(--build-name="$next_name" --build-number="$next_number") ;;
      iOS) IOS_BUILD_ARGS=(--build-name="$next_name" --build-number="$next_number") ;;
    esac
    break
  done
}

prompt_release_versions() {
  case "$TARGET" in
    all)
      prompt_release_version "Android" "$ANDROID_VERSION_FILE"
      prompt_release_version "iOS" "$IOS_VERSION_FILE"
      ;;
    android|aab) prompt_release_version "Android" "$ANDROID_VERSION_FILE" ;;
    ios) prompt_release_version "iOS" "$IOS_VERSION_FILE" ;;
  esac
}

if [ "$MODE" = "release" ]; then
  RELEASE=1
elif [ "$MODE" != "test" ]; then
  err "알 수 없는 옵션: '$MODE'"
  usage
  exit 1
fi

case "$TARGET" in
  all|android|ios|aab) ;;
  *) err "알 수 없는 대상: '$TARGET'"; usage; exit 1 ;;
esac

case "$TARGET" in
  all|android|aab) require_android_release_signing || exit 1 ;;
esac

if [ "$RELEASE" -eq 1 ]; then
  prompt_release_versions
fi

info "flutter pub get"
flutter pub get || { err "pub get 실패"; exit 1; }

build_android_aab() {
  if ! have_android; then
    warn "Android SDK 미설치 → Android 빌드 건너뜀 (Android Studio 설치 후 재시도)"
    return
  fi
  require_android_release_signing || return
  info "Android App Bundle (.aab) 빌드…"
  if [ "$RELEASE" -eq 1 ]; then
    if flutter build appbundle --release "${BUILD_DEFINES[@]}" "${ANDROID_BUILD_ARGS[@]}"; then
      info "→ build/app/outputs/bundle/release/app-release.aab"
      remember_release_output_dir "build/app/outputs/bundle/release"
    else err "App Bundle 빌드 실패"; FAIL=1; fi
  else
    if flutter build appbundle --release "${BUILD_DEFINES[@]}"; then
      info "→ build/app/outputs/bundle/release/app-release.aab"
    else err "App Bundle 빌드 실패"; FAIL=1; fi
  fi
}

build_android() {
  build_android_aab
}

build_ios() {
  if [ "$(uname)" != "Darwin" ]; then
    warn "iOS 빌드는 macOS에서만 가능 → 건너뜀"
    return
  fi
  command -v pod >/dev/null 2>&1 || warn "CocoaPods 미설치 → iOS 빌드가 실패할 수 있습니다 (sudo gem install cocoapods)"
  if [ "$RELEASE" -eq 1 ]; then
    info "iOS IPA 심사용 빌드…"
    if flutter build ipa --release "${BUILD_DEFINES[@]}" "${IOS_BUILD_ARGS[@]}"; then
      info "→ build/ios/ipa/*.ipa"
      remember_release_output_dir "build/ios/ipa"
    else err "iOS IPA 빌드 실패 (Apple Developer 서명/Xcode 상태 확인)"; FAIL=1; fi
  else
    info "iOS 빌드 (서명 없이, 빌드 가능 여부 확인)…"
    if flutter build ios --release --no-codesign "${BUILD_DEFINES[@]}"; then
      info "→ build/ios/iphoneos/Runner.app (서명 없음)"
    else err "iOS 빌드 실패 (CocoaPods/Xcode 상태 확인)"; FAIL=1; fi
  fi
}

case "$TARGET" in
  ios)     build_ios ;;
  android) build_android ;;
  aab)     build_android_aab ;;
  all)     build_android; build_ios ;;
esac

if [ "$FAIL" -eq 0 ]; then
  info "빌드 완료 ✅"
  open_release_output_dirs
else
  err "일부 플랫폼 빌드에 실패했습니다."
  exit 1
fi
