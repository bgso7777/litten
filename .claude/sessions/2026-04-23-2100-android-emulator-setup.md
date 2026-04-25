# Android 에뮬레이터 환경 구축 및 앱 실행

## 세션 개요
- **시작 시간**: 2026-04-23 21:00 (KST)
- **목적**: Flutter 프론트엔드 앱을 Android 에뮬레이터에 설치 및 실행

## 목표
- [x] Flutter SDK 설치 (`C:\Users\bgso7\litten\flutter`)
- [x] Android Studio 설치 (winget, v2025.3.4.6)
- [x] Android SDK 설치 (`C:\Users\bgso7\litten\android-sdk`)
- [x] Android Emulator Hypervisor Driver (AEHD) 설치
- [x] Android 에뮬레이터 생성 및 실행 (Litten_Pixel5, API 35)
- [x] Flutter 앱 빌드 및 에뮬레이터 설치 완료

## 설치된 환경 정보
- **Flutter SDK**: 3.41.7 (stable) → `C:\Users\bgso7\litten\flutter`
- **Android SDK**: API 35, 36 → `C:\Users\bgso7\litten\android-sdk`
- **Java (JDK)**: OpenJDK 21.0.10 (Android Studio 내장) → `C:\Program Files\Android\Android Studio\jbr`
- **AVD**: `Litten_Pixel5` (Pixel 5, Android API 35, x86_64)
- **AEHD**: `C:\Users\bgso7\litten\android-sdk\extras\google\Android_Emulator_Hypervisor_Driver`

## 환경변수 (매번 설정 필요)
```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME = "C:\Users\bgso7\litten\android-sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\bgso7\litten\android-sdk"
$env:Path += ";$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\emulator;C:\Users\bgso7\litten\flutter\bin"
```

## 앱 실행 방법
```powershell
# 1. 에뮬레이터 시작
Start-Process "C:\Users\bgso7\litten\android-sdk\emulator\emulator.exe" -ArgumentList "-avd Litten_Pixel5 -no-metrics"

# 2. 앱 빌드 및 실행
cd C:\Users\bgso7\litten\src\litten\frontend
flutter run -d emulator-5554
```

## 진행 상황
- 2026-04-23 21:00: Flutter SDK, Android Studio, SDK 설치 완료
- 2026-04-23 21:00: AEHD 설치 완료 (관리자 권한으로 silent_install.bat 실행)
- 2026-04-23 21:00: 에뮬레이터 부팅 완료 (약 96초 소요)
- 2026-04-23 21:00: `flutter pub get` 완료 (168개 패키지)
- 2026-04-23 21:00: `flutter run` 성공 - app-debug.apk 빌드 및 에뮬레이터 설치 완료
- 2026-04-23 21:00: `build.gradle.kts` NDK 버전 27.0.12077973 → 28.2.13676358 수정

## 특이사항
- Windows 10 Home이라 Hyper-V 미지원 → AEHD로 해결
- Flutter PATH는 사용자 환경변수에 등록 완료 (`C:\Users\bgso7\litten\flutter\bin`)
- ANDROID_HOME, ANDROID_SDK_ROOT, JAVA_HOME 환경변수 등록 완료
