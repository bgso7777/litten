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

### 업데이트 - 2026-04-25 오후 (세션 인계)

**요약**: 노트탭 통계 헤더 및 캘린더 일정 리스트 UI 개선 다수 완료

**Git 변경 사항**:
- 수정됨: frontend/lib/widgets/common/litten_unified_list_view.dart
- 수정됨: frontend/lib/screens/writing_screen.dart (이전 세션)
- 수정됨: frontend/lib/services/app_state_provider.dart (이전 세션)
- 수정됨: frontend/lib/screens/main_tab_screen.dart (이전 세션)
- 현재 브랜치: main (커밋: f0c17b0 - 노트 통계 확장 영역 개선)

**할 일 진행 상황**: 모두 완료

**세부사항**:

1. **undefined 리튼 선택 해제 → 디폴트 재선택**
   - 홈탭 터치 시 `clearSelectedLitten()` → undefined 리튼 선택으로 변경
   - 앱 시작 시 undefined 리튼 자동 선택 (디폴트)
   - `updateFileCount()`: undefined 선택 시 전체 카운트 표시 (null 처리)

2. **캘린더/노트 통계 확장 일정 리스트 개선**
   - undefined 리튼 항상 맨 위 고정
   - undefined 리튼 그룹: 전체 파일 수집 (총합 카운트 표시)
   - undefined 그룹 헤더: `Icons.folder_open` 아이콘 + 제목 공백
   - 파일 행의 일정명: 검은색(`Colors.black87`), undefined 파일은 공백
   - 배지 순서: 텍스트 → 필기 → 녹음 (변경)
   - 배지 항상 표시 (0이어도 표시)

3. **undefined 리튼 제목 표시**
   - 캘린더 리스트 및 노트 통계 확장 영역: '-' → '' (공백)

**미결 사항**: 없음

---

## 세션 종료 요약 - 2026-04-25 11:37 (KST)

**세션 소요 시간**: 2026-04-23 21:00 ~ 2026-04-25 11:37 (약 2일)

---

### Git 요약

**변경된 파일 (미커밋 포함)**:
- 수정됨: `frontend/lib/widgets/common/litten_unified_list_view.dart`
- 수정됨: `.claude/sessions/2026-04-23-2100-android-emulator-setup.md`

**이번 세션 관련 커밋 (f0c17b0 기준 이전)**:
- `f0c17b0` 노트 통계 확장 영역 개선
- `511070b` 노트 통계 확장 영역의 개선
- `76d81e9` 노트 탭의 통계 영역 개선
- `963d1c1` 통계 영역 확장 시 텍스트, 필기, 녹음 파일 리스트 표시

**최종 git 상태**: 2개 파일 미커밋 수정 중 (커밋 필요)

---

### 주요 성과 및 구현 기능

#### 1. 노트탭 통계 헤더 개선 (`writing_screen.dart`)
- 통계 헤더 높이: 56px → 45px
- 좌측 아이콘: 폴더 → `Icons.event_available` (캘린더 체크)
- 아이콘 크기: `getBadgeIconSize * 1.331` (여러 차례 10%씩 증가)
- 우측 배지 색상: 항상 진한 `primaryColor` (투명도 제거)
- 선택된 일정 제목: fontSize 12, 좌측 정렬
- undefined 리튼 제목: 표시 안 함 (`SizedBox.shrink()`)

#### 2. 통계 헤더 확장 패널 (`writing_screen.dart`)
- 헤더 클릭/스와이프 다운 → 파일 리스트 패널 확장
- 위로 스크롤 오버스크롤 시 패널 닫힘
- 우측 타입 배지(텍스트/필기/녹음) 탭으로 필터링
- 패널 열린 상태에서 배지 탭: 패널 유지 + 필터만 변경

#### 3. 일정 리스트 표시 형식 (`litten_unified_list_view.dart`)
- 파일 항목: `아이콘|파일명|시:분` → `일정명|파일명|MM/dd HH:mm`
- 일정명 색상: 테마색 → 검은색(`Colors.black87`)
- undefined 일정명: `'-'` → `''` (공백)

#### 4. undefined 리튼 처리 전략
- **위치**: 항상 맨 위 고정 (정렬 우선순위 최상위)
- **파일 수집**: undefined 그룹 = 전체 파일 수집 (총합 표시)
- **카운트**: `updateFileCount()`에서 undefined 선택 시 null 처리 → 전체 카운트
- **헤더 아이콘**: `Icons.folder_open`
- **헤더 제목**: 공백
- **디폴트 선택**: 앱 시작 시 + 캘린더탭 터치 시 undefined 자동 선택

#### 5. 배지 표시 변경
- **순서**: 녹음/텍스트/필기 혼재 → 텍스트 → 필기 → 녹음 통일
- **조건**: 파일 있을 때만 표시 → 항상 표시 (0도 표시)

#### 6. `AppStateProvider` 변경 (`app_state_provider.dart`)
- `clearSelectedLitten()` 메서드 추가 (SharedPreferences 제거 + 전체 카운트 갱신)
- `updateFileCount()`: undefined 또는 null 선택 시 전체 카운트 표시

#### 7. `MainTabScreen` 변경 (`main_tab_screen.dart`)
- 앱 시작 시 undefined 리튼 자동 선택 (디폴트)
- 캘린더탭 터치 시 undefined 리튼 선택 (전체 카운트 복원)

---

### 발생한 문제와 해결책

| 문제 | 해결책 |
|------|--------|
| AnimationController 리팩토링으로 터치 동작 전체 불작동 | 사용자가 직접 원복, 기존 AnimatedPositioned 방식 유지 |
| "일정명 파일명 생성일시" 요청을 정렬로 오해 | 원복 후 표시 형식 변경으로 재적용 |
| undefined 선택 시 전체 카운트가 아닌 undefined 파일만 카운트 | updateFileCount()에서 undefined → null 처리 |
| 선택 해제 시 노트탭에서 탭 영역이 사라짐 | selectedLitten null 시 "먼저 선택하세요" 표시됨 → undefined 항상 선택으로 해결 |

---

### 미완료 작업

없음 (모든 요청 사항 구현 완료)

---

### 미래 개발자를 위한 팁

1. **undefined 리튼**: 앱의 "기본/전체" 리튼으로 삭제 불가. 항상 목록 최상단에 위치하며 선택 시 전체 파일 카운트를 표시함.
2. **updateFileCount()**: `selectedLitten == null || selectedLitten.title == 'undefined'`이면 전체 카운트(littenId: null). 그 외는 해당 리튼 카운트.
3. **litten_unified_list_view.dart**: 캘린더 화면과 노트 통계 확장 패널 모두 동일 위젯 사용. filterType/littenId 파라미터로 동작 분기.
4. **AnimatedPositioned**: 패널 애니메이션을 AnimationController로 교체 시도했다가 실패함. AnimatedPositioned 방식 유지 권장.
5. **에뮬레이터 실행**: PowerShell에서 환경변수 설정 후 `flutter run` 실행. 세션 환경변수 섹션 참고.
