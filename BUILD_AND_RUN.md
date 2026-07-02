# 빌드 & 실행 가이드 (iOS / Android)

**가톨릭 달력** Flutter 앱을 iOS·Android에서 실행/빌드하는 방법입니다.
(앱 이름: 가톨릭 달력 · 번들 ID: `com.sidore.catholiccalendar`)

> **DEBUG 배너 안 뜸**: 우측 상단 "DEBUG" 리본은 코드에서 이미 꺼져 있습니다
> (`lib/app/app.dart` → `debugShowCheckedModeBanner: false`). 어떤 실행 모드에서도
> 배너는 보이지 않습니다. "디버그 빌드 자체가 아닌" 상태로 돌리려면 아래 `--release`
> 또는 `--profile` 모드를 쓰세요.

---

## 0. 사전 준비 (최초 1회)

Flutter는 `/opt/homebrew/bin`에 설치되어 있습니다. 새 터미널에서 명령이 안 잡히면:
```bash
export PATH="/opt/homebrew/bin:$PATH"   # 필요 시 ~/.zshrc에 추가
```

상태 점검:
```bash
flutter doctor        # 각 플랫폼 준비 상태 확인
flutter devices       # 연결된 시뮬레이터/기기 목록 + 기기 ID
```

프로젝트 의존성:
```bash
flutter pub get
```

### iOS 준비물
- **Xcode** (설치됨).
- **CocoaPods** — 현재 미설치. 플러그인(url_launcher 등) 사용에 필수:
  ```bash
  sudo gem install cocoapods       # 또는: brew install cocoapods
  cd ios && pod install && cd ..   # 최초/플러그인 변경 시
  ```
- 실기기 배포용 서명: Xcode에서 **Apple Developer 팀** 지정 (아래 iOS 섹션 참고).

### Android 준비물
- **Android Studio + Android SDK** — 현재 미설치. 설치 후:
  ```bash
  flutter doctor --android-licenses   # 라이선스 동의
  # SDK가 커스텀 경로면: flutter config --android-sdk <경로>
  ```

---

## 1. 실행 모드 & 디버그 표시

| 모드 | 명령 | 특징 |
|---|---|---|
| debug (기본) | `flutter run` | 핫 리로드, 디버그 도구. (DEBUG 배너는 이미 꺼짐) |
| **profile** | `flutter run --profile` | 릴리스에 가까운 성능 + 프로파일링 |
| **release** | `flutter run --release` | 최적화된 배포용 빌드, 디버그 요소 없음 |

> "Debug 표시 없이 깔끔하게 돌리고 싶다" → `flutter run --release` (또는 `--profile`).
> 배너 자체는 debug 모드에서도 이미 숨겨져 있습니다.

---

## 2. iOS — 실행 & 빌드

### 시뮬레이터에서 실행
```bash
open -a Simulator                 # 시뮬레이터 실행
flutter devices                   # 시뮬레이터 ID 확인
flutter run -d "<시뮬레이터ID>"     # 실행 (배너 없이: 뒤에 --release)
```

### 실기기(iPhone)에서 실행
1. 케이블 연결(또는 동일 Wi‑Fi) + 기기에서 **개발자 모드** 활성화.
2. 서명 설정 (최초 1회):
   ```bash
   open ios/Runner.xcworkspace     # Xcode 열기
   ```
   Xcode → Runner 타깃 → **Signing & Capabilities** → Team 선택
   (Apple Developer 계정). Bundle Identifier = `com.sidore.catholiccalendar`
   (Apple Developer 포털에 동일 App ID 등록 필요).
3. 실행:
   ```bash
   flutter run -d "<기기ID>" --release
   ```

### 스토어 배포용 빌드
```bash
flutter build ipa --release
# 산출물: build/ios/ipa/*.ipa
# → Xcode Organizer 또는 Transporter로 App Store Connect 업로드
```
(또는 `flutter build ios --release` 후 Xcode에서 Product ▸ Archive)

---

## 3. Android — 실행 & 빌드

### 에뮬레이터 / 실기기에서 실행
```bash
flutter devices                   # 기기/에뮬레이터 ID 확인
flutter run -d "<기기ID>"           # 실행 (배너 없이: 뒤에 --release)
```
에뮬레이터가 없으면 Android Studio ▸ Device Manager에서 생성.

### 설치용 APK (사이드로드/테스트)
```bash
flutter build apk --release
# 산출물: build/app/outputs/flutter-apk/app-release.apk
```

### Play 스토어용 App Bundle
```bash
flutter build appbundle --release
# 산출물: build/app/outputs/bundle/release/app-release.aab
```

> ⚠️ **릴리스 서명**: 현재 release 빌드는 임시로 **디버그 키**로 서명됩니다
> (`android/app/build.gradle.kts`의 `signingConfig = signingConfigs.getByName("debug")`).
> Play 스토어 업로드 전에 **릴리스 keystore** 생성 + `android/key.properties` 설정 +
> gradle 서명 구성이 필요합니다.
> 참고: https://docs.flutter.dev/deployment/android#signing-the-app
> (applicationId = `com.sidore.catholiccalendar`)

---

## 4. 자주 쓰는 명령

```bash
flutter clean && flutter pub get     # 캐시 정리 후 재설치 (빌드 꼬일 때)
flutter analyze                      # 정적 분석
flutter test                         # 위젯/단위 테스트
dart test packages/liturgical_calendar   # 전례력 엔진 테스트

# 보너스 — 웹 (참고용, 배포 결정 시)
flutter run -d chrome
flutter build web --release          # 산출물: build/web/
```

---

## 5. 전례력 데이터 갱신 (참고)

공식 CBCK 전례력 스냅샷(`assets/calendar/cbck_days.json`)을 새 연도로 확장:
```bash
dart run tool/import_cbck.dart 2025 2028   # 공개된 연도까지
```
갱신 후 다시 빌드/배포하면 반영됩니다. (미수록 연도는 계산 엔진이 자동 폴백)
