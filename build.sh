#!/usr/bin/env bash
#
# 가톨릭 달력 — iOS / Android 빌드 스크립트
#
# 사용법:
#   ./build.sh                    # Android + iOS 스크린샷/테스트 빌드
#   ./build.sh android            # Android AAB/APK
#   ./build.sh ios                # iOS no-codesign
#   ./build.sh apk                # Android APK만
#   ./build.sh aab                # Android AAB만
#
# 출시 빌드:
#   ./build.sh android release    # 버전 입력 -> pubspec 갱신 -> Android AAB/APK 광고 ON 빌드
#   ./build.sh aab release        # 버전 입력 -> pubspec 갱신 -> Android AAB 광고 ON 빌드
#   ./build.sh ios release        # 버전 입력 -> pubspec 갱신 -> iOS no-codesign 광고 ON 빌드
#
# - Android: App Bundle(.aab) + APK(.apk) 릴리스 산출.
# - iOS: 서명 없이(--no-codesign) 빌드 가능 여부까지 확인. 스토어용 IPA는
#        Xcode 서명 설정 후 `flutter build ipa --release` 사용.
# - 준비물이 없는 플랫폼은 건너뛰고 경고만 출력합니다 (BUILD_AND_RUN.md 참고).
#
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")"

TARGET="${1:-all}"
MODE="${2:-test}"
RELEASE=0
BUILD_DEFINES=(--dart-define=ADS_ENABLED=false)
FAIL=0
info() { printf "\033[1;34m[build]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[build] ⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[build] ✗ %s\033[0m\n" "$*"; }

command -v flutter >/dev/null 2>&1 || { err "flutter 명령을 찾을 수 없습니다 (PATH 확인)"; exit 1; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

current_pubspec_version() {
  sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1
}

version_lt() {
  local IFS=.
  local -a left right
  read -r -a left <<< "$1"
  read -r -a right <<< "$2"

  for i in 0 1 2; do
    local a="${left[$i]:-0}"
    local b="${right[$i]:-0}"
    if ((10#$a < 10#$b)); then return 0; fi
    if ((10#$a > 10#$b)); then return 1; fi
  done
  return 1
}

prompt_release_version() {
  local current current_name current_number next_name next_number
  current="$(current_pubspec_version)"
  current_name="${current%%+*}"
  current_number="${current#*+}"

  if [[ -z "$current" || "$current" == "$current_number" || ! "$current_number" =~ ^[0-9]+$ ]]; then
    err "pubspec.yaml의 version 형식을 읽을 수 없습니다: '$current'"
    exit 1
  fi

  while true; do
    printf "앱 버전 입력 (현재 %s, 예: 1.2.3): " "$current_name"
    read -r next_name
    printf "빌드번호 입력 (현재 %s, 예: 42): " "$current_number"
    read -r next_number

    if [[ ! "$next_name" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
      warn "앱 버전은 1.2.3 형식이어야 합니다."
      continue
    fi
    if [[ ! "$next_number" =~ ^[0-9]+$ ]]; then
      warn "빌드번호는 0 이상의 정수여야 합니다."
      continue
    fi
    if version_lt "$next_name" "$current_name"; then
      warn "입력한 앱 버전($next_name)이 현재 버전($current_name)보다 낮습니다. 다시 입력하세요."
      continue
    fi
    if ((10#$next_number < 10#$current_number)); then
      warn "입력한 빌드번호($next_number)가 현재 빌드번호($current_number)보다 낮습니다. 다시 입력하세요."
      continue
    fi

    perl -0pi -e "s/^version:\\s*.*\$/version: $next_name+$next_number/m" pubspec.yaml
    info "pubspec.yaml version: $current -> $next_name+$next_number"
    break
  done
}

if [ "$MODE" = "release" ]; then
  RELEASE=1
  BUILD_DEFINES=(--dart-define=ADS_ENABLED=true)
elif [ "$MODE" != "test" ]; then
  err "알 수 없는 옵션: '$MODE'"
  usage
  exit 1
fi

case "$TARGET" in
  all|android|ios|apk|aab) ;;
  *) err "알 수 없는 대상: '$TARGET'"; usage; exit 1 ;;
esac

if [ "$RELEASE" -eq 1 ]; then
  prompt_release_version
fi

info "flutter pub get"
flutter pub get || { err "pub get 실패"; exit 1; }

have_android() {
  [ -n "${ANDROID_HOME:-}" ] || [ -n "${ANDROID_SDK_ROOT:-}" ] || [ -d "$HOME/Library/Android/sdk" ]
}

build_android_aab() {
  if ! have_android; then
    warn "Android SDK 미설치 → Android 빌드 건너뜀 (Android Studio 설치 후 재시도)"
    return
  fi
  info "Android App Bundle (.aab) 빌드…"
  if flutter build appbundle --release "${BUILD_DEFINES[@]}"; then
    info "→ build/app/outputs/bundle/release/app-release.aab"
  else err "App Bundle 빌드 실패"; FAIL=1; fi
}

build_android_apk() {
  if ! have_android; then
    warn "Android SDK 미설치 → Android 빌드 건너뜀 (Android Studio 설치 후 재시도)"
    return
  fi
  info "Android APK 빌드…"
  if flutter build apk --release "${BUILD_DEFINES[@]}"; then
    info "→ build/app/outputs/flutter-apk/app-release.apk"
  else err "APK 빌드 실패"; FAIL=1; fi
}

build_android() {
  build_android_aab
  build_android_apk
}

build_ios() {
  if [ "$(uname)" != "Darwin" ]; then
    warn "iOS 빌드는 macOS에서만 가능 → 건너뜀"
    return
  fi
  command -v pod >/dev/null 2>&1 || warn "CocoaPods 미설치 → iOS 빌드가 실패할 수 있습니다 (sudo gem install cocoapods)"
  info "iOS 빌드 (서명 없이, 빌드 가능 여부 확인)…"
  if flutter build ios --release --no-codesign "${BUILD_DEFINES[@]}"; then
    info "→ build/ios/iphoneos/Runner.app (서명 없음)"
    info "  스토어 업로드용 IPA: Xcode 서명 설정 후  flutter build ipa --release"
  else err "iOS 빌드 실패 (CocoaPods/Xcode 상태 확인)"; FAIL=1; fi
}

case "$TARGET" in
  ios)     build_ios ;;
  android) build_android ;;
  apk)     build_android_apk ;;
  aab)     build_android_aab ;;
  all)     build_android; build_ios ;;
esac

if [ "$FAIL" -eq 0 ]; then
  info "빌드 완료 ✅"
else
  err "일부 플랫폼 빌드에 실패했습니다."
  exit 1
fi
