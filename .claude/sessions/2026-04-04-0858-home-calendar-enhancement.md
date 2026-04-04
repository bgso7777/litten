# 홈 캘린더 기능 보강

## 개요 (Overview)
- **시작 시간**: 2026-04-04 08:58 KST
- **세션 목표**: 홈 화면의 캘린더 기능을 보강하고 개선

## 목표 (Goals)
- 홈 캘린더 기능 보강 (구체적인 목표는 사용자와 논의 후 결정)

## 진행 상황 (Progress)

### 2026-04-04 08:58 - 세션 시작
- 세션 파일 생성 완료
- 구체적인 기능 보강 내용 확인 대기 중

### 업데이트 - 2026-04-04 13:33 KST

**요약**: 홈 화면 탭 전환 및 화면 회전 시 일관된 UX 구현 완료

**Git 변경 사항**:
- 수정됨: frontend/lib/screens/home_screen.dart
- 수정됨: frontend/lib/screens/main_tab_screen.dart
- 추가됨: .claude/sessions/2026-04-04-0858-home-calendar-enhancement.md
- 현재 브랜치: main (커밋: 1c59aab 홈탭 캘린더 위주 표시 2)

**할 일 진행 상황**: 완료 4건
- ✓ 완료됨: IndexedStack을 PageView로 변경하여 상태 보존
- ✓ 완료됨: 탭 전환 시 항상 캘린더가 보이도록 스크롤을 맨 위로 이동
- ✓ 완료됨: 화면 회전 시에도 캘린더가 보이도록 스크롤을 맨 위로 이동
- ✓ 완료됨: 홈 버튼 클릭과 동일한 동작으로 UX 통일

**발생한 이슈**:
1. 초기 요구사항: 탭 전환 및 화면 회전 시 스크롤 위치를 유지하고 싶음
2. 시도한 해결책들:
   - `AutomaticKeepAliveClientMixin` 사용 → 작동 안 함
   - 정적 변수로 스크롤 위치 저장 및 복원 → 작동 안 함
   - `ScrollController.initialScrollOffset` 사용 → 작동 안 함
   - `NotificationListener`로 스크롤 리셋 감지 → 작동 안 함
   - `IndexedStack` → `Offstage + Stack` → 작동 안 함
   - `PageView` 사용 → 여전히 스크롤 위치 유지 안 됨

**최종 해결책**:
- 스크롤 위치를 유지하는 대신, **항상 캘린더가 보이도록** 변경
- 홈 버튼 클릭과 동일한 동작으로 UX 통일
- 모든 경우(탭 전환, 화면 회전, 홈 버튼 클릭)에 일관된 동작

**구현 내용**:

1. **MainTabScreen 변경**:
   - `IndexedStack` → `PageView` 변경
   - `PageController` 추가 및 탭 전환 시 `jumpToPage()` 사용
   - 홈 탭으로 전환 시 `scrollToTop()` 자동 호출

2. **HomeScreen 변경**:
   - `scrollToTop()` 메서드 추가: 애니메이션과 함께 스크롤을 맨 위로 이동
   - `goToToday()` 수정: 오늘 날짜로 이동 + 스크롤 맨 위로
   - `didChangeMetrics()` 수정: 화면 회전 시 자동으로 `scrollToTop()` 호출

3. **코드 변경 세부사항**:
```dart
// MainTabScreen - PageView 사용
PageView(
  controller: _pageController,
  physics: const NeverScrollableScrollPhysics(),
  children: [
    HomeScreen(key: _homeScreenKey),
    WritingScreen(),
    SettingsScreen(),
  ],
)

// HomeScreen - 스크롤 맨 위로 이동
void scrollToTop() {
  if (_scrollController.hasClients) {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

// 화면 회전 감지
@override
void didChangeMetrics() {
  super.didChangeMetrics();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    scrollToTop();
  });
}
```

**결과**:
- ✅ 홈 버튼 클릭: 캘린더 표시
- ✅ 탭 전환 (다른 탭 → 홈): 캘린더 표시
- ✅ 화면 회전 (세로 ↔ 가로): 캘린더 표시
- ✅ 일관된 UX 제공

**교훈**:
- 스크롤 위치 유지가 Flutter에서 예상보다 복잡함 (특히 탭/페이지 전환 시)
- 때로는 기술적 해결책보다 UX 방향을 변경하는 것이  더 나을 수 있음
- 일관성 있는 사용자 경험이 가장 중요함

---

## 세션 종료 요약

### 기본 정보
- **세션 시작**: 2026-04-04 08:58 KST
- **세션 종료**: 2026-04-04 13:34 KST
- **총 소요 시간**: 약 4시간 36분

### Git 변경 사항 요약
- **변경된 전체 파일 수**: 6개
  - 수정됨: 5개
  - 추가됨: 1개
  - 삭제됨: 0개
- **수행된 커밋**: 0개 (작업 내용은 커밋되지 않음)

**변경된 파일 목록**:
1. `M .DS_Store` - 시스템 파일 (자동 생성)
2. `M .claude/sessions/.current-session` - 세션 관리 파일
3. `M .gitignore` - Git 무시 설정 파일
4. `M frontend/lib/screens/home_screen.dart` - **핵심 변경**
5. `M frontend/lib/screens/main_tab_screen.dart` - **핵심 변경**
6. `?? .claude/sessions/2026-04-04-0858-home-calendar-enhancement.md` - 세션 기록 파일

**최종 Git 상태**:
- 브랜치: `main`
- 마지막 커밋: `1c59aab 홈탭 캘린더 위주 표시 2`
- 변경 사항 커밋 대기 중

### 할 일 요약
- **완료된 작업**: 4건
- **남은 작업**: 0건
- **완료율**: 100%

**완료된 작업 목록**:
1. ✓ IndexedStack을 PageView로 변경하여 상태 보존
2. ✓ 탭 전환 시 항상 캘린더가 보이도록 스크롤을 맨 위로 이동
3. ✓ 화면 회전 시에도 캘린더가 보이도록 스크롤을 맨 위로 이동
4. ✓ 홈 버튼 클릭과 동일한 동작으로 UX 통일

**미완료 작업**: 없음

### 주요 성과
1. **일관된 UX 구현**: 홈 화면 진입 시 항상 캘린더가 보이도록 통일
2. **PageView 도입**: 탭 상태 관리 개선 및 메모리 효율성 향상
3. **사용자 경험 개선**: 예측 가능하고 일관된 동작으로 사용성 향상

### 구현된 기능
1. **HomeScreen.scrollToTop()**: 부드러운 애니메이션과 함께 스크롤을 맨 위로 이동
2. **HomeScreen.goToToday()**: 오늘 날짜로 이동 + 캘린더 표시
3. **HomeScreen.didChangeMetrics()**: 화면 회전 감지 및 자동 스크롤
4. **MainTabScreen PageView**: IndexedStack 대체로 상태 관리 개선
5. **탭 전환 자동 스크롤**: 홈 탭 진입 시 자동으로 캘린더 표시

### 발생한 문제와 해결책

#### 문제 1: 스크롤 위치 유지 실패
**원인**:
- `AutomaticKeepAliveClientMixin`이 탭 전환 시 제대로 작동하지 않음
- `IndexedStack`의 상태 관리 한계
- Flutter의 위젯 생명주기와 스크롤 컨트롤러 재연결 이슈

**시도한 해결책** (모두 실패):
1. `AutomaticKeepAliveClientMixin` + `wantKeepAlive = true`
2. 정적 변수 `_globalScrollOffset`로 위치 저장 및 복원
3. `ScrollController(initialScrollOffset: ...)`
4. `PostFrameCallback`에서 `jumpTo()` 복원
5. `NotificationListener<ScrollUpdateNotification>`로 리셋 감지
6. `Offstage + Stack` 구조
7. `PageView` + 스크롤 위치 복원

**최종 해결책**:
- **UX 방향 변경**: 스크롤 위치 유지 대신 **항상 캘린더 표시**로 변경
- 홈 버튼 클릭과 동일한 동작으로 일관성 확보
- 사용자에게 예측 가능한 경험 제공

#### 문제 2: Offstage의 build() 미호출
**원인**: `Offstage`의 `offstage` 값 변경 시 자식 위젯의 `build()`가 호출되지 않음

**해결책**: `Offstage` 대신 `PageView` 사용

### 주요 코드 변경 사항

#### 1. MainTabScreen.dart
**변경 전**: `IndexedStack` 사용
```dart
IndexedStack(
  index: appState.selectedTabIndex,
  children: [
    HomeScreen(key: _homeScreenKey),
    WritingScreen(),
    SettingsScreen(),
  ],
)
```

**변경 후**: `PageView` + 자동 스크롤
```dart
// PageController 추가
late PageController _pageController;

@override
void initState() {
  super.initState();
  _pageController = PageController(initialPage: appState.selectedTabIndex);
}

// PageView 사용
PageView(
  controller: _pageController,
  physics: const NeverScrollableScrollPhysics(),
  children: [
    HomeScreen(key: _homeScreenKey),
    WritingScreen(),
    SettingsScreen(),
  ],
)

// 탭 전환 시 홈으로 가면 스크롤 맨 위로
if (index == 0) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _homeScreenKey.currentState?.scrollToTop();
  });
}
```

#### 2. HomeScreen.dart
**추가된 메서드**:
```dart
// 스크롤 맨 위로 이동
void scrollToTop() {
  if (_scrollController.hasClients) {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

// goToToday() 수정 - 스크롤도 맨 위로
void goToToday() {
  final now = DateTime.now();
  _calendarFocusedDate.value = DateTime(now.year, now.month, now.day);
  scrollToTop(); // 추가
}

// 화면 회전 시 자동 스크롤
@override
void didChangeMetrics() {
  super.didChangeMetrics();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    scrollToTop();
  });
}
```

### 추가/제거된 종속성
- **추가**: 없음
- **제거**: 없음

### 설정 변경 사항
- 없음

### 배포 단계
- iOS 기기에 여러 차례 테스트 빌드 및 설치 (릴리즈 모드)
- 실제 기기에서 동작 확인 완료

### 얻은 교훈

1. **Flutter 스크롤 위치 유지의 복잡성**:
   - `AutomaticKeepAliveClientMixin`이 항상 예상대로 작동하지 않음
   - 탭/페이지 전환 시 위젯 생명주기가 복잡함
   - `PageStorage`도 모든 경우를 커버하지 못함

2. **UX vs 기술적 구현**:
   - 때로는 기술적으로 어려운 구현보다 UX 방향을 변경하는 것이 더 나을 수 있음
   - 일관성 있는 사용자 경험이 완벽한 기술적 구현보다 중요할 수 있음
   - "항상 같은 위치에서 시작"하는 것도 좋은 UX가 될 수 있음

3. **PageView의 장점**:
   - `IndexedStack`보다 상태 관리가 더 안정적
   - `physics: NeverScrollableScrollPhysics()`로 스와이프 제스처 차단 가능
   - 메모리 효율적 (인접 페이지만 유지)

4. **디버깅 접근법**:
   - 로그 수집이 어려울 때는 접근 방법을 바꿔야 함
   - 여러 해결책 시도 후 작동하지 않으면 근본적으로 재고려 필요
   - 사용자 요구사항의 본질을 다시 파악하는 것이 중요

### 완료되지 않은 작업
- 없음 (모든 목표 달성)

### 추가 고려사항
- 향후 스크롤 위치 유지가 정말 필요한 경우, `PageStorageBucket`과 `PageStorageKey`를 더 깊이 연구 필요
- 또는 각 탭을 완전히 독립적인 `Navigator`로 분리하는 방법 고려 가능

### 미래 개발자를 위한 팁

1. **PageView 사용**:
   - 탭 기반 네비게이션에서 상태 유지가 중요하다면 `PageView` 사용 권장
   - `physics: NeverScrollableScrollPhysics()`로 스와이프 제스처 차단
   - `PageController.jumpToPage()`로 애니메이션 없이 전환 가능

2. **스크롤 위치 관리**:
   - 단순히 위치를 유지하는 것보다 일관된 시작 위치를 제공하는 것이 더 나을 수 있음
   - `scrollToTop()`에 애니메이션을 추가하면 사용자에게 부드러운 경험 제공
   - `WidgetsBinding.instance.addPostFrameCallback()`을 활용하여 프레임 렌더링 후 스크롤

3. **화면 회전 처리**:
   - `WidgetsBindingObserver` mixin 사용
   - `didChangeMetrics()` 오버라이드
   - 회전 후 레이아웃이 완료된 시점에 스크롤 조정

4. **디버깅**:
   - `debugPrint()`로 상세한 로그 추가
   - 여러 해결책을 시도하되, 일정 시도 후에는 방향 전환 고려
   - 사용자의 진짜 니즈가 무엇인지 다시 확인

5. **코드 정리**:
   - 현재 코드에는 사용하지 않는 스크롤 위치 저장 관련 코드가 남아있음
   - 향후 리팩토링 시 `_globalScrollOffset`, `NotificationListener` 등 미사용 코드 제거 고려

### 최종 상태
- ✅ 홈 버튼 클릭: 캘린더 표시 (오늘 날짜)
- ✅ 탭 전환 (다른 탭 → 홈): 캘린더 표시
- ✅ 화면 회전 (세로 ↔ 가로): 캘린더 표시
- ✅ 모든 경우에 일관된 UX 제공
- ✅ 부드러운 애니메이션으로 사용자 경험 향상

**세션 종료**: 2026-04-04 13:34 KST

