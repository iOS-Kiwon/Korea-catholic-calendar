# Firebase Firestore + App Check 설정 체크리스트

이 앱은 사용자가 새 카테고리를 추가할 때 카테고리 이름을 Firestore에 기록할 수 있습니다.
앱 코드에는 Firebase API 키 같은 공개 설정값만 들어가며, 별도의 관리자 토큰은 넣지 않습니다.

## 1. Firebase 프로젝트 준비

1. Firebase Console에서 프로젝트를 만들거나 기존 프로젝트를 선택합니다.
2. Android 앱을 추가합니다.
   - Android package name: `com.sidore.catholiccalendar`
   - 앱 등록 후 `google-services.json`을 다운로드합니다.
3. iOS 앱을 추가합니다.
   - iOS bundle ID: `com.sidore.catholiccalendar`
   - 앱 등록 후 `GoogleService-Info.plist`를 다운로드합니다.
4. 프로젝트 루트에서 FlutterFire CLI를 실행합니다.
   - `firebase login`
   - `dart pub global activate flutterfire_cli`
   - `flutterfire configure`
   - 생성/갱신되어야 하는 파일: `lib/firebase_options.dart`

## 2. Firestore 설정

1. Firebase Console에서 Firestore Database를 생성합니다.
2. 위치는 나중에 변경하기 어려우므로 신중히 선택합니다.
   - 한국 사용자가 대부분이면 가까운 Asia 리전을 선택하는 편이 좋습니다.
3. Security Rules는 처음부터 쓰기 대상을 제한합니다.

예시 규칙:

```text
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /category_add_logs/{logId} {
      allow create: if request.time < timestamp.date(2099, 1, 1)
        && request.resource.data.keys().hasOnly([
          'name',
          'color',
          'platform',
          'appVersion',
          'buildNumber',
          'createdAt'
        ])
        && request.resource.data.name is string
        && request.resource.data.name.size() > 0
        && request.resource.data.name.size() <= 80
        && request.resource.data.color is int
        && request.resource.data.platform in ['android', 'ios', 'web', 'unknown']
        && request.resource.data.appVersion is string
        && request.resource.data.buildNumber is string
        && request.resource.data.createdAt == request.time;

      allow read, update, delete: if false;
    }
  }
}
```

운영에서는 App Check enforcement를 켠 뒤, 가능하면 규칙을 더 좁히는 것이 좋습니다.

## 3. App Check 설정

1. Firebase Console > App Check로 이동합니다.
2. Android 앱 provider를 등록합니다.
   - Play 배포 앱이면 Play Integrity를 사용합니다.
   - 디버그 테스트 중이면 Debug provider 토큰을 등록합니다.
3. iOS 앱 provider를 등록합니다.
   - App Attest를 우선 사용합니다.
   - 오래된 iOS 기기 지원이 필요하면 DeviceCheck fallback을 검토합니다.
4. Firestore에 대해 App Check enforcement를 켭니다.
   - 앱에 App Check가 정상 적용되고 실제 쓰기 확인 후 켜는 것을 권장합니다.

## 4. 개인정보/심사 문구

카테고리명은 사용자가 직접 입력하는 데이터입니다. 개인정보 처리방침과 앱 심사 메모에 다음 내용을 반영하세요.

- 사용자가 추가한 카테고리명이 서비스 개선/사용 패턴 파악을 위해 Firebase에 전송될 수 있음
- 전송 항목: 카테고리명, 색상값, 플랫폼, 앱 버전, 생성 시각
- 계정/이름/연락처 등 직접 식별 정보는 함께 전송하지 않음

## 참고 공식 문서

- Firebase Flutter 설정: https://firebase.google.com/docs/flutter/setup
- Firestore 시작하기: https://firebase.google.com/docs/firestore/quickstart
- Flutter App Check 설정: https://firebase.google.com/docs/app-check/flutter/default-providers
