#!/usr/bin/env bash
#
# 가톨릭 달력 — iOS / Android 릴리스 빌드 스크립트
#
# 사용법:
#   ./build.sh            # iOS + Android 모두 빌드 (기본)
#   ./build.sh android    # Android만
#   ./build.sh ios        # iOS만
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
FAIL=0
info() { printf "\033[1;34m[build]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[build] ⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[build] ✗ %s\033[0m\n" "$*"; }

command -v flutter >/dev/null 2>&1 || { err "flutter 명령을 찾을 수 없습니다 (PATH 확인)"; exit 1; }

info "flutter pub get"
flutter pub get || { err "pub get 실패"; exit 1; }

have_android() {
  [ -n "${ANDROID_HOME:-}" ] || [ -n "${ANDROID_SDK_ROOT:-}" ] || [ -d "$HOME/Library/Android/sdk" ]
}

build_android() {
  if ! have_android; then
    warn "Android SDK 미설치 → Android 빌드 건너뜀 (Android Studio 설치 후 재시도)"
    return
  fi
  info "Android App Bundle (.aab) 빌드…"
  if flutter build appbundle --release; then
    info "→ build/app/outputs/bundle/release/app-release.aab"
  else err "App Bundle 빌드 실패"; FAIL=1; fi

  info "Android APK 빌드…"
  if flutter build apk --release; then
    info "→ build/app/outputs/flutter-apk/app-release.apk"
  else err "APK 빌드 실패"; FAIL=1; fi
}

build_ios() {
  if [ "$(uname)" != "Darwin" ]; then
    warn "iOS 빌드는 macOS에서만 가능 → 건너뜀"
    return
  fi
  command -v pod >/dev/null 2>&1 || warn "CocoaPods 미설치 → iOS 빌드가 실패할 수 있습니다 (sudo gem install cocoapods)"
  info "iOS 빌드 (서명 없이, 빌드 가능 여부 확인)…"
  if flutter build ios --release --no-codesign; then
    info "→ build/ios/iphoneos/Runner.app (서명 없음)"
    info "  스토어 업로드용 IPA: Xcode 서명 설정 후  flutter build ipa --release"
  else err "iOS 빌드 실패 (CocoaPods/Xcode 상태 확인)"; FAIL=1; fi
}

case "$TARGET" in
  ios)     build_ios ;;
  android) build_android ;;
  all)     build_android; build_ios ;;
  *)       err "알 수 없는 대상: '$TARGET' (사용: ios | android | all)"; exit 1 ;;
esac

if [ "$FAIL" -eq 0 ]; then
  info "빌드 완료 ✅"
else
  err "일부 플랫폼 빌드에 실패했습니다."
  exit 1
fi
