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

---

## 세션 종료 요약 - 2026-04-26 18:30 (KST)

### 세션 개요
- **시작 시간**: 2026-04-26 (정확한 시작 시간 미기록, 이전 세션에서 연속)
- **종료 시간**: 2026-04-26 18:30 (KST)
- **목적**: 캘린더 UI/UX 개선 및 일정 관리 기능 향상

---

### Git 요약

**변경된 파일 (6개, 미커밋)**:
- 수정됨: `frontend/lib/screens/home_screen.dart` (+288 -129줄, 주요 변경)
- 수정됨: `frontend/lib/widgets/common/litten_unified_list_view.dart` (+48 -21줄)
- 수정됨: `frontend/lib/widgets/dialogs/create_litten_dialog.dart` (+10 -7줄)
- 수정됨: `frontend/lib/widgets/dialogs/edit_litten_dialog.dart` (+10 -7줄)
- 수정됨: `frontend/lib/widgets/home/schedule_picker.dart` (+38 -26줄)
- 수정됨: `frontend/lib/widgets/home/time_picker_scroll.dart` (+12 -8줄)

**전체 변경 통계**: +406줄 추가, -198줄 삭제 (순증 +208줄)

**관련 커밋 (이번 세션 이전)**:
- `27c052c` 캘린더 일정 점으로 표시
- `13f0006` 캘린더 노트 UI 개선

**최종 git 상태**: 6개 파일 미커밋 수정 중 (커밋 필요)

---

### 할 일 요약

**완료된 작업 (8개)**:
1. ✅ 캘린더 점 표시 로직 개선 (전체/축소 모드 분리)
2. ✅ 시작일자~종료일자 범위 모든 날짜에 점 표시
3. ✅ 캘린더 색상 변경 (토요일 검은색, 일요일 빨간색)
4. ✅ 일정 생성/수정 화면 UI 개선
5. ✅ 일정 겹침 방지 레이어 시스템 구현
6. ✅ 일정 리스트 아이콘 변경 (캘린더 모양)
7. ✅ 선택된 일정 강조 표시
8. ✅ flutter clean 후 재빌드 및 테스트

**미완료 작업**: 없음

---

### 주요 성과 및 구현 기능

#### 1. 캘린더 점 표시 로직 개선 ([home_screen.dart:1566-1604](frontend/lib/screens/home_screen.dart#L1566-L1604))

**전체 화면 vs 축소 모드 분리**:
- **전체 화면** (`_scheduleListVisible == false`): 일정 제목 바만 표시, 점 숨김
- **축소 모드** (`_scheduleListVisible == true`): 점만 표시 (최대 3개), 제목 바 숨김

**시작일~종료일 범위 점 표시**:
```dart
// 해당 날짜가 시작일~종료일 범위에 포함되는지 확인
final startDate = DateTime(litten.schedule!.date.year, ...);
final endDate = litten.schedule!.endDate != null ? DateTime(...) : startDate;

if ((targetDate.isAtSameMomentAs(startDate) || targetDate.isAfter(startDate)) &&
    (targetDate.isAtSameMomentAs(endDate) || targetDate.isBefore(endDate))) {
  scheduleCount++;
}
```

**개선 효과**:
- 사용자가 일정 기간을 한눈에 파악 가능
- 전체/축소 모드 간 정보 밀도 조절로 가독성 향상

#### 2. 캘린더 색상 커스터마이징 ([home_screen.dart](frontend/lib/screens/home_screen.dart))

**요일 헤더 색상 (3개 캘린더 모두 적용)**:
```dart
calendarBuilders: CalendarBuilders(
  dowBuilder: (context, day) {
    return Center(
      child: Text(
        DateFormat.E(appState.locale.languageCode).format(day),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: day.weekday == DateTime.sunday ? Colors.red : Colors.black,
        ),
      ),
    );
  },
  // ...
),
```

**날짜 텍스트 색상**:
- 토요일: 검은색
- 일요일: 빨간색 (헤더와 날짜 모두)

**적용 범위**:
- 메인 캘린더 (line ~1503)
- 시작일자 선택 캘린더 (line ~1790)
- 종료일자 선택 캘린더 (line ~1900)

#### 3. 일정 생성/수정 화면 UI 개선

**create_litten_dialog.dart & edit_litten_dialog.dart**:
- "일정 수정"/"일정 생성" 타이틀 라인 **완전히 제거**
- 제목 입력란 placeholder: "일정 제목을 입력하세요."
- 저장 시 제목 입력 필수 검증 유지

**schedule_picker.dart** ([line 167-202](frontend/lib/widgets/home/schedule_picker.dart#L167-L202)):
```dart
// "날짜" → "시작일자"로 변경, 폰트 크기 14px로 통일
const Text('시작일자', style: TextStyle(fontSize: 14)),
```

**time_picker_scroll.dart**:
- Container 높이: 140px → 100px
- padding: 8 → 6
- itemExtent: 40 → 30
- diameterRatio: 1.8 → 1.5

**개선 효과**: 한 화면에 메모란까지 모두 표시 가능

#### 4. 일정 겹침 방지 레이어 시스템 ([home_screen.dart:1320-1471](frontend/lib/screens/home_screen.dart#L1320-L1471))

**문제 상황**:
- 25~29일 일정과 28일 일정이 같은 위치에 겹쳐서 보임
- 사용자가 일정을 구분할 수 없음

**해결 알고리즘**:
1. **일정별 레이어 결정**:
   ```dart
   final scheduleLayers = <String, int>{}; // scheduleId -> layer
   final rowLayerOccupancy = <int, Map<int, Set<int>>>{}; // row -> layer -> columns
   ```

2. **세그먼트 분석**: 각 일정이 차지하는 모든 행/열 범위 수집

3. **충돌 감지**:
   - 해당 일정의 모든 세그먼트가 차지할 공간 확인
   - 각 공간에서 이미 사용 중인 레이어 찾기

4. **레이어 할당**:
   ```dart
   int layer = 0;
   while (usedLayers.contains(layer)) {
     layer++;
   }
   scheduleLayers[scheduleId] = layer;
   ```

5. **공간 점유 등록**: 할당된 레이어에 이 일정이 차지하는 모든 열 등록

**렌더링**:
```dart
Positioned(
  left: leftPosition,
  top: topPosition + (layer * 22), // 레이어별 22px 간격
  width: barWidth,
  height: 20,
  child: Container(...),
)
```

**개선 효과**:
- 겹치는 일정들이 수직으로 분리되어 표시
- 같은 일정의 모든 세그먼트는 동일한 레이어에 배치되어 일관성 유지
- 최대 레이어 수 제한 없음 (자동 확장)

#### 5. 일정 리스트 UI 개선 ([litten_unified_list_view.dart:418-489](frontend/lib/widgets/common/litten_unified_list_view.dart#L418-L489))

**섹션 헤더 아이콘 변경**:
```dart
Icon(Icons.calendar_month, color: Theme.of(context).primaryColor, size: 20),
```

**선택된 일정 강조 표시**:
```dart
final isSelected = appState.selectedLitten?.id == litten.id;

return Container(
  decoration: BoxDecoration(
    color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : null,
    border: isSelected ? Border.all(
      color: Theme.of(context).primaryColor,
      width: 1.5,
    ) : null,
    borderRadius: BorderRadius.circular(8),
  ),
  child: ListTile(
    leading: Icon(Icons.calendar_month, color: Theme.of(context).primaryColor, size: 24),
    // ...
  ),
);
```

**개선 효과**:
- 캘린더 날짜 선택 효과와 동일한 시각적 피드백
- 현재 선택된 일정을 명확하게 인지 가능

---

### 발생한 문제와 해결책

#### 문제 1: 점이 전체 화면에서도 보임
**증상**: 캘린더가 전체 화면일 때도 날짜 아래 점이 표시됨

**원인**: `eventLoader` 로직에서 `_scheduleListVisible` 체크 누락

**해결**:
```dart
eventLoader: (day) {
  // 축소 모드일 때만 점 표시
  if (!_scheduleListVisible) {
    return [];
  }
  // ... 점 생성 로직
}
```

**디버깅 과정**:
- 처음에는 로직이 반대라고 생각했으나 실제로는 맞았음
- line 1503의 캘린더가 dual-purpose(전체/축소 모두 사용)라는 것을 발견
- `_scheduleListVisible == false`일 때가 전체 화면 모드

#### 문제 2: 시작일자만 점 표시, 종료일자 범위는 표시 안됨
**증상**: 28~30일 일정인데 28일에만 점이 표시됨

**원인**: `schedule.date`(시작일)만 체크하는 로직
```dart
// 잘못된 코드
if (scheduleDate.isAtSameMomentAs(targetDate)) {
  scheduleCount++;
}
```

**해결**: 종료일자 범위 체크 추가
```dart
final endDate = litten.schedule!.endDate != null ? ... : startDate;
if ((targetDate.isAtSameMomentAs(startDate) || targetDate.isAfter(startDate)) &&
    (targetDate.isAtSameMomentAs(endDate) || targetDate.isBefore(endDate))) {
  scheduleCount++;
}
```

#### 문제 3: 일정 겹침 (25~29일 + 28일 일정)
**증상**: 여러 일정이 같은 위치에 겹쳐서 렌더링됨

**원인**: 처음 구현한 레이어 시스템이 셀의 시작 위치(`startCol`)만 키로 사용
```dart
// 문제 있는 코드
final cellKey = '${row}_$colStart';
cellSchedules.putIfAbsent(cellKey, () => []);
```

**해결**: 전체 알고리즘 재설계
- 일정별로 레이어를 먼저 결정
- 각 행/열별로 점유 상태 추적 (`rowLayerOccupancy`)
- 일정의 모든 세그먼트가 차지하는 공간 분석
- 겹치는 레이어 찾기 → 사용 가능한 최소 레이어 할당

**디버깅 과정**:
1. 처음: 셀 기준 그룹화 → 실패
2. 두 번째: 일정별 레이어 할당 → 부분 성공
3. 최종: 행/열/레이어 3차원 점유 추적 → 완전 해결

#### 문제 4: 토요일 헤더 색상이 빨간색으로 유지됨
**증상**: 토요일과 일요일 헤더가 모두 빨간색

**원인**: `DaysOfWeekStyle`의 `weekendStyle`이 토요일/일요일 모두에 적용
```dart
daysOfWeekStyle: const DaysOfWeekStyle(
  weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
),
```

**해결**: `dowBuilder`를 추가하여 요일별로 커스텀 렌더링
```dart
dowBuilder: (context, day) {
  return Center(
    child: Text(
      DateFormat.E(appState.locale.languageCode).format(day),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: day.weekday == DateTime.sunday ? Colors.red : Colors.black,
      ),
    ),
  );
},
```

#### 문제 5: 일정 리스트 UI 변경이 반영 안됨
**증상**: hot reload로 아이콘과 색상 변경이 적용되지 않음

**원인**: Flutter 빌드 캐시 문제

**해결**: `flutter clean` 실행 후 완전 재빌드
```bash
cd /Users/mymac/Desktop/litten/frontend
flutter clean
flutter run -d iphone
```

**교훈**: UI 위젯 변경 시 hot reload가 안 먹히면 clean 빌드 시도

---

### 주요 변경 사항 및 기술적 발견

#### 1. table_calendar 패키지 커스터마이징
- **eventLoader**: 날짜별 마커(점) 생성 함수
- **CalendarBuilders**: 셀 렌더링 커스터마이징
  - `dowBuilder`: 요일 헤더
  - `defaultBuilder`: 일반 날짜
  - `selectedBuilder`: 선택된 날짜
  - `todayBuilder`: 오늘 날짜
- **DaysOfWeekStyle vs dowBuilder**: dowBuilder가 우선순위 높음

#### 2. 복잡한 레이아웃 충돌 해결 패턴
**학습한 알고리즘**:
```
1. 모든 객체(일정)를 순회
2. 각 객체가 차지할 모든 공간(세그먼트) 수집
3. 각 공간에서 이미 사용 중인 레이어 확인
4. 충돌하지 않는 최소 레이어 찾기
5. 객체 전체를 해당 레이어에 할당
6. 점유 상태 업데이트
```

**적용 가능성**:
- 달력뿐 아니라 간트 차트, 타임라인 등에도 적용 가능
- 2D 공간에서 겹치는 요소를 z-index로 분리하는 일반적인 패턴

#### 3. Flutter 빌드 시스템 이해
- **hot reload**: 위젯 트리 재구성, 상태 유지
- **hot restart**: 앱 재시작, 상태 초기화
- **flutter clean**: 빌드 캐시 완전 삭제
  - `build/` 디렉토리 삭제
  - `.dart_tool/` 디렉토리 삭제
  - pubspec.lock 재생성

**언제 clean이 필요한가**:
- UI 위젯 변경이 hot reload로 반영 안 될 때
- 의존성 버전 변경 후
- 빌드 오류가 지속될 때

---

### 얻은 교훈

1. **UX 세부사항의 중요성**:
   - 점 표시, 색상, 아이콘 등 작은 요소들이 사용자 경험에 큰 영향
   - 사용자 피드백을 통해 점진적으로 개선하는 과정이 중요

2. **모드 분리의 필요성**:
   - 전체 화면 vs 축소 모드에서 다른 정보 밀도 제공
   - 컨텍스트에 따라 UI 요소 표시/숨김 결정

3. **알고리즘 설계의 중요성**:
   - 레이어 시스템 같은 복잡한 로직은 처음부터 완벽하게 설계 필요
   - 부분적인 해결책은 엣지 케이스에서 실패 가능

4. **Flutter 빌드 시스템 이해**:
   - hot reload의 한계 인지
   - 문제 발생 시 clean 빌드를 빠르게 시도

5. **사용자 피드백 해석**:
   - "점 계속보여. 안보이게 해줘" → 로직이 반대로 되었다고 착각
   - 실제로는 로직은 맞았고, 다른 곳에 원인이 있었음
   - 깊게 생각하고 코드 전체를 다시 검토하는 것이 중요

---

### 미완료 작업

없음 (모든 요청 사항 구현 완료)

---

### 미래 개발자를 위한 팁

#### 캘린더 관련
1. **점 표시 로직**: `_scheduleListVisible == false`일 때가 전체 화면 모드. `eventLoader`에서 빈 리스트 반환하면 점 숨김.

2. **일정 범위 표시**: 시작일~종료일 범위를 체크할 때는 반드시 `isAtSameMomentAs` 포함해야 경계 날짜가 표시됨.

3. **레이어 시스템**: `_buildScheduleBars` 함수가 일정 겹침 방지의 핵심. 수정 시 신중하게 접근할 것.
   - `scheduleLayers`: 일정 ID → 레이어 번호 매핑
   - `rowLayerOccupancy`: 행 → 레이어 → 점유 열 집합
   - 레이어 간격: 22px (line ~1450)

4. **세 개의 캘린더**:
   - 메인 캘린더 (line ~1503)
   - 시작일자 선택 (line ~1790)
   - 종료일자 선택 (line ~1900)
   - 세 곳 모두 동일하게 수정해야 일관성 유지

5. **요일 색상 커스터마이징**: `DaysOfWeekStyle`보다 `dowBuilder`가 우선. `dowBuilder`로 토요일/일요일 개별 제어 가능.

#### 일정 리스트 관련
6. **litten_unified_list_view.dart**:
   - 캘린더 화면과 노트 통계 확장 패널 모두 사용
   - 섹션 헤더: line ~418
   - 일정 항목: line ~450-489
   - 선택 강조: `isSelected` 변수로 제어

7. **선택 효과**: `Theme.of(context).primaryColor.withValues(alpha: 0.15)`로 반투명 배경, `Border.all`로 테두리.

#### 일정 생성/수정 관련
8. **다이얼로그 구조**:
   - `create_litten_dialog.dart`: 새 일정 생성
   - `edit_litten_dialog.dart`: 기존 일정 수정
   - 두 파일이 거의 동일한 구조 → 중복 제거 고려 가능

9. **시간 선택기**: `time_picker_scroll.dart`의 높이는 전체 다이얼로그 레이아웃에 영향. 변경 시 메모란 가시성 확인.

#### 빌드 및 디버깅
10. **flutter clean 타이밍**:
    - UI 변경이 hot reload로 반영 안 될 때
    - 설명할 수 없는 빌드 오류 발생 시
    - 의존성 변경 후

11. **iOS 시뮬레이터**: `flutter run -d iphone`으로 실행. 기본 시뮬레이터가 자동 선택됨.

12. **에뮬레이터 실행**: PowerShell에서 환경변수 설정 후 `flutter run` 실행 (세션 환경변수 섹션 참고).

---

### 추가 개선 제안 (선택적)

1. **레이어 시각적 구분**: 레이어가 많아지면 색상을 조금씩 다르게 표시하여 구분성 향상

2. **일정 길이에 따른 제목 표시**:
   - 짧은 일정: 아이콘만
   - 중간 일정: 약어
   - 긴 일정: 전체 제목

3. **일정 생성 UX**:
   - 캘린더에서 날짜 범위 드래그로 일정 생성
   - 시간 입력 시 자동완성 (30분 단위 등)

4. **성능 최적화**:
   - `_buildScheduleBars`가 매 프레임마다 호출될 수 있음
   - 결과를 캐싱하여 불필요한 재계산 방지

5. **접근성**:
   - 색상만으로 정보 전달 지양 (색맹 사용자 고려)
   - 일요일: 빨간색 + 볼드체 등 복합 표시

---

**세션 완료 시각**: 2026-04-26 18:30 (KST)

**최종 상태**: 모든 요청 사항 구현 및 테스트 완료, 6개 파일 미커밋 상태
