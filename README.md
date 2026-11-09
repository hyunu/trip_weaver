# TripWeave

여행 일정·탐색·지도(OSM 타일)·오프라인 저장을 다루는 Flutter 앱입니다. `lib/`와 `test/`만 있던 저장소에 iOS·Android·macOS 실행용 플랫폼 프로젝트를 추가했습니다.

## 요구 사항

- [Flutter](https://docs.flutter.dev/get-started/install) **3.44 이상** (stable 권장)
- macOS 로컬 실행: Xcode 및 CocoaPods
- iOS 시뮬레이터: Xcode
- Android 에뮬레이터: Android Studio / SDK

## 의존성

```bash
flutter pub get
```

## 정적 분석·테스트

```bash
flutter analyze
flutter test
```

## 기기에서 실행

사용 가능한 기기 목록:

```bash
flutter devices
```

### iOS 시뮬레이터

1. 시뮬레이터를 띄웁니다 (Xcode **Open Developer Tool → Simulator**, 또는 `open -a Simulator`).
2. 프로젝트 루트에서:

```bash
flutter run -d ios
```

또는 목록에 보이는 시뮬레이터 ID를 지정합니다. 예:

```bash
flutter run -d "iPhone 16"
```

### Android 에뮬레이터

에뮬레이터를 실행한 뒤:

```bash
flutter run -d android
```

### macOS 데스크톱

```bash
flutter run -d macos
```

macOS 샌드박스에서는 지도 타일·지오코딩(Nominatim)을 위해 **아웃바운드 네트워크** 권한을 entitlements에 넣어 두었습니다.

## 네트워크·지도

- 온라인일 때 OSM 타일, Nominatim 검색, Google Maps 길찾기 링크(`url_launcher`)를 사용합니다.
- Android: `INTERNET` 권한
- iOS: HTTPS 기본(ATS) 유지
- macOS: `com.apple.security.network.client`

오프라인이면 번들된 샘플 지오코더와 로컬 타일 캐시 동작이 테스트에 포함되어 있습니다.

## web 플랫폼

이번 변경에는 **web** 디렉터리를 포함하지 않았습니다. 네이티브(iOS·Android·macOS) 실행을 우선합니다.
