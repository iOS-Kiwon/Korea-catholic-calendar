# 빌드 & 실행 가이드 (iOS / Android)

**가톨릭 달력** Flutter 앱을 iOS·Android에서 실행/빌드하는 방법입니다.
(앱 이름: 가톨릭 달력 · 번들 ID: `com.sidore.catholiccalendar`)

> **DEBUG 배너 안 뜸**: 우측 상단 "DEBUG" 리본은 코드에서 이미 꺼져 있습니다
> (`lib/app/app.dart` → `debugShowCheckedModeBanner: false`). 어떤 실행 모드에서도
> 배너는 보이지 않습니다. "디버그 빌드 자체가 아닌" 상태로 돌리려면 아래 `--release`
> 또는 `--profile` 모드를 쓰세요.

## ⚡ 빠른 스크립트 (권장)

루트에 헬퍼 스크립트가 있습니다. (기기/툴체인이 없으면 경고 후 건너뜀)

```bash
./build.sh              # Android + iOS 스크린샷/테스트 빌드
./build.sh android      # Android AAB (광고 ON, 버전 입력 없음)
./build.sh ios          # iOS no-codesign
./build.sh aab          # Android AAB만
./run.sh                          # 연결된 첫 기기에서 실행 (release → DEBUG 없음)
./run.sh ios                      # 첫 iOS 실기기
./run.sh ios simulator            # 첫 iOS 시뮬레이터
./run.sh android                  # 첫 Android 실기기
./run.sh android simulator        # 첫 Android 에뮬레이터 (꺼져 있으면 자동 실행)
./run.sh all                      # iOS + Android 실기기 동시 실행 (백그라운드, 로그: build/run-logs/)
MODE=debug ./run.sh ios simulator # 모드 변경 (release[기본] | debug | profile)
ANDROID_AVD=Medium_Phone_API_36.1 ./run.sh android simulator # 특정 Android AVD 지정
```

모든 모바일 빌드는 광고 ON(`ADS_ENABLED=true`)입니다. debug/profile 실행은 AdMob 정책에
맞춰 Google 테스트 광고 단위를 사용하고, release 빌드만 실 광고 단위를 사용합니다.

### 원격 API 주소 전환

앱은 기본적으로 자체 서버 API를 사용합니다.

```text
https://api.sidore.org/kcc/v1
```

월 화면은 먼저 앱에 포함된 전례력 스냅샷과 계산 엔진으로 즉시 표시됩니다. 이후 백그라운드에서
자체 서버의 `/calendar/{year}/{month}`를 조회하고, 서버 데이터가 있으면 해당 월 데이터를 병합해
화면을 갱신합니다. 서버가 응답하지 않거나 `available=false`이면 기존 번들 데이터로 계속 동작합니다.

로컬 Mac mini API 서버나 개발 서버로 바꿔 테스트하려면 `KCC_API_BASE_URL`을
`--dart-define`으로 주입합니다.

```bash
flutter run \
  --dart-define=KCC_API_BASE_URL=http://127.0.0.1:18080/kcc/v1
```

실제 기기에서 Mac mini의 로컬 서버를 볼 때는 `127.0.0.1` 대신 Mac mini의 LAN IP를 사용합니다.

```bash
flutter run \
  --dart-define=KCC_API_BASE_URL=http://192.168.0.10:18080/kcc/v1
```

운영 API를 명시적으로 지정하려면:

```bash
flutter run \
  --dart-define=KCC_API_BASE_URL=https://api.sidore.org/kcc/v1
```

백오피스에서 전례력 JSON을 수정한 뒤 앱 반영 여부를 확인할 때는 다음 순서가 안전합니다.

1. `https://admin.sidore.org/kcc`에서 대상 월 JSON 수정 후 최종 저장
2. `https://api.sidore.org/kcc/v1/calendar/YYYY/M`에서 수정된 값 확인
3. 앱을 실행하고 같은 월로 이동
4. 처음에는 번들 데이터가 보일 수 있으나, 서버 응답 후 수정된 값으로 갱신되는지 확인

debug 빌드에서는 월 화면 오른쪽 위에 서버 연동 상태 배지가 표시됩니다. `서버 확인 중`,
`서버 갱신 완료`, `서버 데이터 없음`, `서버 확인 실패` 중 하나가 보이며, 콘솔에는 `[KCC API]`
접두사의 서버 호출 성공/실패 로그가 출력됩니다. release 빌드에는 이 배지가 표시되지 않습니다.

같은 월의 서버 확인 결과는 기본 24시간 동안 재사용합니다. 백오피스 수정값을 즉시 반복 확인해야 할
때는 debug 실행에 아래 값을 추가하면 TTL 없이 매번 서버를 확인합니다.

```bash
flutter run \
  --dart-define=KCC_REMOTE_REFRESH_TTL_HOURS=0
```

출시 빌드는 `release` 옵션을 붙입니다. 앱 버전과 빌드번호를 입력하면
플랫폼별 버전 파일을 갱신한 뒤 심사용 산출물을 빌드합니다.
Android와 iOS는 서로 다른 버전을 사용할 수 있습니다.

```bash
./build.sh android release    # 버전 입력 -> Android AAB 심사용 빌드
./build.sh aab release        # 버전 입력 -> Android AAB 심사용 빌드
./build.sh ios release        # 버전 입력 -> iOS IPA 심사용 빌드
```

플랫폼별 release 버전 파일:

```text
android/release_version.properties
ios/release_version.properties
```

Release 버전 입력 규칙:

- 앱 버전은 이전 앱 버전보다 낮게 입력할 수 없습니다.
- 같은 앱 버전에서는 빌드번호도 이전 빌드번호보다 낮게 입력할 수 없습니다.
- 앱 버전을 올린 경우에는 새 앱스토어 업데이트 버전으로 보고 빌드번호를 `0`부터 다시 사용할 수 있습니다.

세부 절차/사전 준비는 아래를 참고하세요.

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
- **Xcode**.
- **CocoaPods** — 플러그인(url_launcher 등) 사용에 필수:
  ```bash
  sudo gem install cocoapods       # 또는: brew install cocoapods
  cd ios && pod install && cd ..   # 최초/플러그인 변경 시
  ```
- 실기기 배포용 서명: Xcode에서 **Apple Developer 팀** 지정 (아래 iOS 섹션 참고).

### Android 준비물
- **Android Studio + Android SDK**. 최초 1회:
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
./run.sh ios simulator            # iOS 시뮬레이터는 자동으로 debug 모드 실행
```
Flutter는 iOS 시뮬레이터의 release 실행을 지원하지 않습니다. `run.sh`는 기본 모드가
release여도 iOS 시뮬레이터에서는 자동으로 debug 모드로 전환합니다.

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
./build.sh ios release
# 산출물: build/ios/ipa/*.ipa
```
Xcode에서 Apple Developer 팀/Bundle ID 서명이 설정되어 있어야 합니다.
생성된 IPA는 Transporter 또는 Xcode Organizer로 App Store Connect에 업로드합니다.

---

## 3. Android — 실행 & 빌드

### 에뮬레이터 / 실기기에서 실행
```bash
flutter devices                   # 기기/에뮬레이터 ID 확인
flutter run -d "<기기ID>"           # 실행 (배너 없이: 뒤에 --release)
```
에뮬레이터가 꺼져 있어도 루트 스크립트를 쓰면 자동으로 첫 Android AVD를 실행하고
ADB 연결이 완료될 때까지 기다린 뒤 앱을 실행합니다.

```bash
./run.sh android simulator
```

특정 AVD를 쓰고 싶으면 `ANDROID_AVD`를 지정하세요.

```bash
ANDROID_AVD=Medium_Phone_API_36.1 ./run.sh android simulator
```

사용 가능한 AVD가 없으면 Android Studio ▸ Device Manager에서 생성하세요.

### Play 스토어용 App Bundle
```bash
./build.sh aab release
# 산출물: build/app/outputs/bundle/release/app-release.aab
```

심사용이 아닌 확인용 AAB만 만들 때는 버전 입력 없이 아래 명령을 사용합니다.

```bash
./build.sh android
```

> ⚠️ **릴리스 서명**: `./build.sh ... release`는 `android/key.properties`와 릴리스 keystore가
> 없으면 중단됩니다. Play Console 심사용 AAB는 debug key가 아니라 릴리스 keystore로
> 서명되어야 합니다.
> 참고: https://docs.flutter.dev/deployment/android#signing-the-app
> (applicationId = `com.sidore.catholiccalendar`)

`android/key.properties` 예시:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

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
