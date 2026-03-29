# 홈탭 캘린더 스크롤 UX 개선

## 세션 개요

- **시작 시간**: 2026년 3월 29일 20:11 (KST)
- **세션 목표**: 홈탭을 심플하게 개선 - 초기 화면에 캘린더 전체 표시, 스크롤 시 리튼 목록 표시
- **현재 상태**: 홈탭이 캘린더 + 리튼 목록 + 파일 목록이 모두 섞여 있어 복잡함

## 목표

### 1. 홈탭 UX 개선 (메인 목표)
- 초기 화면: 캘린더를 전체 화면으로 크게 표시
- 위로 스크롤: 캘린더가 점점 축소되면서 리튼 목록 표시
- CustomScrollView + SliverAppBar 패턴 사용 (A안)

### 2. 구현 세부사항
- 캘린더가 접히면서 작아지는 부드러운 애니메이션
- 완전히 스크롤하면 캘린더는 상단에 작게 고정
- 리튼 목록은 기존과 동일하게 표시 (접기 기능 유지)

### 3. 기대 효과
- 첫 화면이 매우 심플해짐 (캘린더만 크게 표시)
- 직관적인 네비게이션 (위로 스크롤하면 상세 정보)
- 모던한 앱 UX (Instagram, Google Calendar 스타일)

## 진행 상황

### 분석 단계
- [x] 현재 홈탭 구조 분석 완료
  - `home_screen.dart` 구조 확인
  - 캘린더 섹션 + 통합 리스트 섹션으로 구성
  - `_buildCalendarSection()`, `_buildUnifiedListSection()` 분리
- [x] 개선 방향 결정
  - A안 (CustomScrollView + SliverAppBar) 선택
  - 접히는 애니메이션으로 자연스러운 UX 구현

### 계획 단계
- [ ] CustomScrollView 구조 설계
- [ ] SliverAppBar로 캘린더 영역 변환 계획
- [ ] 리튼 목록을 Sliver 위젯으로 변환 계획

### 구현 단계
- [ ] 기존 Column 구조를 CustomScrollView로 변경
- [ ] 캘린더 섹션을 SliverAppBar로 변환
- [ ] 리튼 목록을 SliverList로 변환
- [ ] 스크롤 애니메이션 조정 및 최적화

### 테스트 단계
- [ ] iOS 시뮬레이터에서 스크롤 동작 테스트
- [ ] 실제 iPhone 디바이스에서 테스트
- [ ] 다양한 화면 크기에서 테스트

### Git 커밋 단계
- [ ] 이전 세션 미완료 작업 커밋 (있다면)
- [ ] 홈탭 스크롤 UX 개선 커밋
- [ ] 세션 문서 커밋

## 주요 변경 예정 파일

1. **home_screen.dart**
   - `build()` 메서드: Column → CustomScrollView로 변경
   - `_buildCalendarSection()` → SliverAppBar로 변환
   - `_buildUnifiedListSection()` → SliverList로 변환

## 기술 스택

### Flutter 위젯
- **CustomScrollView**: 커스텀 스크롤 동작 구현
- **SliverAppBar**: 접히는 앱바 (캘린더 영역)
  - `expandedHeight`: 캘린더 전체 높이
  - `flexibleSpace`: 캘린더 위젯 배치
  - `pinned`: true (완전히 사라지지 않고 상단 고정)
- **SliverList**: 리튼 목록 표시

### 기존 기능 유지
- 캘린더 날짜 선택 기능
- 리튼 접기/펼치기 기능
- 드래그 앤 드롭으로 리튼 날짜 이동
- 알림 표시 기능

## 참고 사항

### 현재 home_screen.dart 구조
```dart
Scaffold(
  body: Column(
    children: [
      _buildCalendarSection(),  // 캘린더 (고정 높이)
      Expanded(
        child: _buildUnifiedListSection(),  // 리튼 목록 (나머지 공간)
      ),
    ],
  ),
)
```

### 변경될 구조
```dart
Scaffold(
  body: CustomScrollView(
    slivers: [
      SliverAppBar(
        expandedHeight: MediaQuery.of(context).size.height * 0.7,
        flexibleSpace: _buildCalendarSection(),
        pinned: true,
      ),
      SliverList(
        delegate: _buildUnifiedListSection(),
      ),
    ],
  ),
)
```

## 다음 단계

1. 사용자 확인 후 구현 시작
2. CustomScrollView 구조 상세 설계
3. 단계별 구현 진행

---

**세션 생성**: 2026년 3월 29일 20:11 (KST)

---

### 업데이트 - 2026년 03월 29일 23:29 (KST)

**요약**: 홈탭 캘린더 스크롤 UX 개선 완료 및 실제 디바이스 배포

**Git 변경 사항**:
- 수정됨: frontend/lib/screens/home_screen.dart
- 현재 브랜치: main (커밋: dc5f432 홈탭 캘린더 위주 표시)

**할 일 진행 상황**: 완료 8건
- ✓ 완료됨: CustomScrollView 구조 구현
- ✓ 완료됨: SliverPersistentHeader로 캘린더 영역 변환
- ✓ 완료됨: 동적 캘린더 크기 조정 (LayoutBuilder)
- ✓ 완료됨: 스크롤에 따른 동적 padding 조정
- ✓ 완료됨: 캘린더-리스트 간격 최소화
- ✓ 완료됨: 년월 텍스트 Consumer로 감싸기
- ✓ 완료됨: 월 변경 시 스크롤 위치 유지
- ✓ 완료됨: 실제 iPhone 디바이스 배포

**구현된 주요 기능**:

1. **SliverPersistentHeader 기반 캘린더**
   - Custom `_CalendarSliverDelegate` 클래스 구현
   - `minHeight` (45%) / `maxHeight` (85%) 제어
   - `shouldRebuild`에서 focusedDate 변경 감지

2. **동적 캘린더 크기 조정**
   - `LayoutBuilder`로 사용 가능한 높이 감지
   - `daysOfWeekHeight`: 전체 높이의 12%
   - `rowHeight`: 나머지를 6주로 나눔
   - 캘린더가 영역 전체를 채우도록 개선

3. **스크롤 기반 동적 padding**
   - `shrinkProgress` 계산으로 스크롤 진행률 추적
   - bottom padding: 100 (펼침) → 4 (축소)
   - 캘린더와 리스트 사이 공백 최소화

4. **월 변경 시 스크롤 위치 유지**
   - `Provider.of<AppStateProvider>(context, listen: false)`로 최신 상태 참조
   - builder 내부에서 currentAppState 사용
   - 년월 텍스트만 `Consumer`로 감싸서 선택적 업데이트
   - delegate는 높이 변경 시에만 재생성

5. **UI/UX 최적화**
   - 초기 화면: 캘린더 85%, bottom padding 100 (FAB 간격 확보)
   - 스크롤 후: 캘린더 45%, bottom padding 4 (최소 간격)
   - TableCalendar의 `onPageChanged`에 최신 state 반영

**해결한 주요 이슈**:

1. **이슈**: 캘린더가 전체 화면을 채우지 못하고 영역만 늘어남
   - **해결**: `LayoutBuilder`로 동적 크기 계산, `daysOfWeekHeight`와 `rowHeight`를 비율로 조정

2. **이슈**: 스크롤 후 캘린더-리스트 사이 큰 공백 발생
   - **해결**: shrinkProgress 기반 동적 padding (100 → 4), 리스트 top padding 제거 (16 → 0)

3. **이슈**: 31일이 FAB와 겹침
   - **해결**: bottom padding을 80 → 100으로 증가

4. **이슈**: 캘린더 좌우 스와이프 시 년월이 바뀌지 않음
   - **해결**: 년월 텍스트를 `Consumer<AppStateProvider>`로 감싸서 자동 업데이트

5. **이슈**: 월 변경 시 스크롤 위치 초기화됨
   - **해결**:
     - builder 내부에서 `Provider.of(listen: false)`로 최신 state 참조
     - `shouldRebuild`에 focusedDate 조건 추가로 변경 감지
     - delegate 재생성 시에도 SliverPersistentHeader가 스크롤 위치 유지

**기술적 세부사항**:

```dart
// Custom Delegate
class _CalendarSliverDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final DateTime focusedDate;
  final Widget Function(BuildContext context, double shrinkOffset) builder;

  @override
  bool shouldRebuild(_CalendarSliverDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        focusedDate != oldDelegate.focusedDate;
  }
}

// 동적 Padding
final shrinkProgress = (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);
final dynamicBottomPadding = 100 - (96 * shrinkProgress);

// 동적 캘린더 크기
LayoutBuilder(
  builder: (context, constraints) {
    final availableHeight = constraints.maxHeight;
    final daysOfWeekHeight = availableHeight * 0.12;
    final rowHeight = (availableHeight - daysOfWeekHeight) / 6;
    return TableCalendar(...);
  },
)

// 년월 텍스트 업데이트
Consumer<AppStateProvider>(
  builder: (context, state, child) {
    return Text(DateFormat.yMMMM(state.locale.languageCode).format(state.focusedDate));
  },
)
```

**테스트 결과**:
- ✓ iPhone 16 Plus 시뮬레이터: 정상 작동
- ✓ 실제 iPhone (iOS 26.3.1): Release 모드 빌드 및 배포 완료
- ✓ 초기 화면에서 캘린더 85% 표시 확인
- ✓ 스크롤 시 캘린더 45%로 축소 및 리스트 표시 확인
- ✓ 월 변경 시 년월 텍스트 업데이트 확인
- ✓ 스크롤된 상태에서 월 변경 시 위치 유지 확인
- ✓ 31일이 FAB와 겹치지 않음 확인
- ✓ 캘린더-리스트 간격 최소화 확인

**다음 단계**:
- 세션 완료 후 Git 커밋 필요
- 추가 UX 개선이 필요한 경우 새 세션 시작

---

## 세션 종료 요약

**종료 시간**: 2026년 03월 29일 23:31 (KST)
**세션 소요 시간**: 약 3시간 20분 (20:11 ~ 23:31)

### Git 요약

**변경된 파일 수**: 2개 (수정 2개)

**변경된 파일 목록**:
1. 수정: `.claude/sessions/2026-03-29-2011-home-calendar-scroll-ux.md` (+123줄)
2. 수정: `frontend/lib/screens/home_screen.dart` (+98줄, -38줄)

**총 변경량**: 183줄 추가, 38줄 삭제

**커밋 현황**:
- 세션 중 1개 커밋 수행: `dc5f432 홈탭 캘린더 위주 표시`
- 현재 브랜치: main
- 커밋되지 않은 변경사항: 2개 파일

**최종 Git 상태**:
```
M .claude/sessions/2026-03-29-2011-home-calendar-scroll-ux.md
M frontend/lib/screens/home_screen.dart
```

### 할 일 요약

**완료된 작업**: 8개
**남은 작업**: 0개

**완료된 모든 작업 목록**:
1. ✓ CustomScrollView 구조 구현
2. ✓ SliverPersistentHeader로 캘린더 영역 변환
3. ✓ 동적 캘린더 크기 조정 (LayoutBuilder)
4. ✓ 스크롤에 따른 동적 padding 조정
5. ✓ 캘린더-리스트 간격 최소화
6. ✓ 년월 텍스트 Consumer로 감싸기
7. ✓ 월 변경 시 스크롤 위치 유지
8. ✓ 실제 iPhone 디바이스 배포

**미완료 작업**: 없음

### 주요 성과

1. **홈탭 UX 완전 개선**
   - 기존 Column 기반 레이아웃에서 CustomScrollView 기반으로 전면 개편
   - 초기 화면에서 캘린더가 85% 차지하며 심플한 UI 제공
   - 스크롤 시 캘린더 45%로 축소되며 리스트 표시

2. **고급 스크롤 애니메이션 구현**
   - SliverPersistentHeader의 Custom Delegate 활용
   - shrinkProgress 기반 동적 padding 조정
   - 부드러운 전환 애니메이션

3. **실제 디바이스 배포 완료**
   - Release 모드 빌드
   - 실제 iPhone (iOS 26.3.1)에 성공적 배포
   - 모든 기능 정상 작동 확인

### 구현된 모든 기능

#### 1. Custom SliverPersistentHeaderDelegate
```dart
class _CalendarSliverDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final DateTime focusedDate;
  final Widget Function(BuildContext context, double shrinkOffset) builder;
}
```
- minHeight (45%), maxHeight (85%) 제어
- focusedDate 변경 감지
- builder 패턴으로 동적 UI 구성

#### 2. 동적 캘린더 크기 조정
- LayoutBuilder로 사용 가능한 높이 감지
- daysOfWeekHeight: 전체 높이의 12%
- rowHeight: 나머지를 6주로 나눔
- TableCalendar가 전체 공간 활용

#### 3. 스크롤 기반 동적 Padding
```dart
final shrinkProgress = (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);
final dynamicBottomPadding = 100 - (96 * shrinkProgress);
```
- 펼침 상태: bottom padding 100px (FAB와 간격)
- 축소 상태: bottom padding 4px (최소 간격)
- 캘린더-리스트 간격 최소화

#### 4. 월 변경 시 스크롤 위치 유지
- Provider.of<AppStateProvider>(context, listen: false)로 최신 상태 참조
- 년월 텍스트만 Consumer로 감싸서 선택적 업데이트
- shouldRebuild에서 focusedDate 변경 감지
- delegate 재생성 시에도 스크롤 위치 유지

#### 5. TableCalendar 통합
- onPageChanged에서 focusedDate 업데이트
- 좌우 스와이프 시 년월 텍스트 자동 업데이트
- 날짜 선택, 이벤트 로더 등 기존 기능 유지

### 발생한 문제와 해결책

#### 문제 1: 캘린더가 전체 화면을 채우지 못함
**증상**: 캘린더 영역만 늘어나고 캘린더 자체는 작게 표시됨
**원인**: TableCalendar의 daysOfWeekHeight, rowHeight가 고정값
**해결**: LayoutBuilder로 동적 크기 계산
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final availableHeight = constraints.maxHeight;
    final daysOfWeekHeight = availableHeight * 0.12;
    final rowHeight = (availableHeight - daysOfWeekHeight) / 6;
    return TableCalendar(
      daysOfWeekHeight: daysOfWeekHeight,
      rowHeight: rowHeight,
      ...
    );
  },
)
```

#### 문제 2: 스크롤 후 캘린더-리스트 사이 큰 공백
**증상**: 스크롤하면 캘린더 아래에 알림 2개 정도 들어갈 공백 발생
**원인**: 캘린더의 bottom padding이 고정 (100px)
**해결**: shrinkProgress 기반 동적 padding
```dart
final dynamicBottomPadding = 100 - (96 * shrinkProgress);
```
펼침: 100px → 축소: 4px

#### 문제 3: 31일이 FAB와 겹침
**증상**: 토요일이 31일인 경우 플로팅 버튼과 겹침
**원인**: bottom padding 부족
**해결**: bottom padding을 80 → 100으로 증가

#### 문제 4: 캘린더 좌우 스와이프 시 년월이 바뀌지 않음
**증상**: TableCalendar를 좌우로 스와이프해도 상단 년월 텍스트 고정
**원인**: builder 내부에서 appState를 클로저로 캡처하여 업데이트 안 됨
**해결**: 년월 텍스트를 Consumer로 감싸기
```dart
Consumer<AppStateProvider>(
  builder: (context, state, child) {
    return Text(
      DateFormat.yMMMM(state.locale.languageCode).format(state.focusedDate),
      ...
    );
  },
)
```

#### 문제 5: 월 변경 시 스크롤 위치 초기화
**증상**: 스크롤된 상태에서 월을 변경하면 캘린더가 다시 확장됨
**원인**: shouldRebuild가 항상 true를 반환하거나, focusedDate 변경을 감지 못함
**해결 시도 1**: shouldRebuild에서 focusedDate 제외 → 년월 업데이트 안 됨
**해결 시도 2**: key로 강제 재생성 → 스크롤 위치 초기화
**최종 해결**:
- builder 내부에서 `Provider.of(listen: false)`로 최신 state 참조
- shouldRebuild에 focusedDate 조건 추가
- SliverPersistentHeader는 delegate 재생성 시에도 스크롤 위치 유지

### 주요 변경 사항

#### home_screen.dart
**라인 수 변경**: +98줄, -38줄

**주요 변경 부분**:

1. **_buildCalendarSliverAppBar() 메서드** (라인 1129-1410)
   - SliverAppBar → SliverPersistentHeader 변경
   - builder 패턴 도입
   - 동적 padding 계산 추가
   - Provider.of로 최신 appState 참조
   - Consumer로 년월 텍스트 감싸기
   - LayoutBuilder로 동적 TableCalendar 크기 조정

2. **_buildUnifiedListSliver() 메서드** (라인 1411-1420)
   - top padding: 16 → 0으로 변경

3. **_CalendarSliverDelegate 클래스** (라인 2380-2421)
   - 새로 추가된 Custom Delegate
   - focusedDate 필드 추가
   - builder 패턴 사용
   - shouldRebuild에서 focusedDate 변경 감지

**주요 코드 변경**:
```dart
// Before: SliverAppBar
SliverAppBar(
  expandedHeight: expandedHeight,
  collapsedHeight: collapsedHeight,
  pinned: true,
  flexibleSpace: FlexibleSpaceBar(
    background: Container(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(...),
    ),
  ),
)

// After: SliverPersistentHeader
SliverPersistentHeader(
  pinned: true,
  delegate: _CalendarSliverDelegate(
    minHeight: minHeight,
    maxHeight: maxHeight,
    focusedDate: appState.focusedDate,
    builder: (context, shrinkOffset) {
      final currentAppState = Provider.of<AppStateProvider>(context, listen: false);
      final shrinkProgress = (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);
      final dynamicBottomPadding = 100 - (96 * shrinkProgress);
      return Container(
        child: Padding(
          padding: EdgeInsets.only(bottom: dynamicBottomPadding),
          child: Column(...),
        ),
      );
    },
  ),
)
```

### 추가/제거된 종속성

**추가된 종속성**: 없음
**제거된 종속성**: 없음

기존 Flutter 패키지만 사용:
- provider (기존)
- table_calendar (기존)
- intl (기존)

### 설정 변경 사항

**설정 변경**: 없음
**환경 변수 변경**: 없음

### 수행된 배포 단계

1. **개발 환경 테스트**
   - iPhone 16 Plus 시뮬레이터에서 개발 및 테스트
   - Hot reload로 빠른 반복 개발

2. **실제 디바이스 배포**
   - 유선 연결된 iPhone (iOS 26.3.1)
   - Release 모드 빌드: `flutter run -d "00008030-001D05CE2E85802E" --release`
   - 총 8회 빌드 및 배포
   - 각 빌드 소요 시간: 약 8-69초

3. **배포 검증**
   - 초기 화면 캘린더 크기 확인
   - 스크롤 동작 확인
   - 월 변경 시 년월 업데이트 확인
   - 스크롤 위치 유지 확인
   - FAB와 캘린더 간격 확인

### 얻은 교훈

1. **SliverPersistentHeader의 스크롤 위치 유지**
   - delegate가 재생성되어도 SliverPersistentHeader는 스크롤 위치를 유지함
   - key로 강제 재생성하면 스크롤 위치가 초기화됨
   - shouldRebuild를 신중하게 구현해야 함

2. **Provider의 listen 파라미터 활용**
   - `listen: false`로 최신 상태를 가져오되 rebuild는 방지
   - Consumer로 특정 위젯만 선택적으로 업데이트
   - 성능과 반응성의 균형

3. **동적 UI는 builder 패턴으로**
   - shrinkOffset 같은 동적 값은 builder에서 계산
   - 고정 위젯을 전달하면 업데이트 불가
   - builder 패턴으로 유연성 확보

4. **LayoutBuilder의 활용**
   - 사용 가능한 공간을 정확히 측정
   - 비율 기반 레이아웃으로 다양한 화면 크기 대응
   - TableCalendar 같은 고정 크기 위젯도 동적으로 조정 가능

5. **디버깅 방법**
   - 스크린샷으로 UI 이슈 정확히 파악
   - 단계적 접근으로 문제 분리
   - 각 수정 후 즉시 테스트

### 완료되지 않은 작업

**없음** - 모든 계획된 작업 완료

### 향후 개선 가능 영역

1. **성능 최적화**
   - shouldRebuild 조건을 더 세밀하게 조정
   - 불필요한 rebuild 최소화

2. **애니메이션 개선**
   - 캘린더 축소/확장 시 커브 애니메이션 추가
   - 월 변경 시 페이드 전환 효과

3. **접근성 개선**
   - 스크린 리더 지원 강화
   - 제스처 힌트 추가

### 미래 개발자를 위한 팁

#### 1. SliverPersistentHeader 커스터마이징

```dart
// Custom Delegate 구조
class _CalendarSliverDelegate extends SliverPersistentHeaderDelegate {
  // 필수: 최소/최대 높이
  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  // 필수: 위젯 빌드 (shrinkOffset으로 스크롤 진행률 파악)
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / (maxExtent - minExtent);
    // progress를 활용한 동적 UI 구성
  }

  // 필수: 재빌드 조건
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    // 변경 감지가 필요한 필드만 체크
  }
}
```

#### 2. 스크롤 위치 유지가 필요한 경우

**DO**:
```dart
// shouldRebuild에서 필요한 변경사항만 감지
@override
bool shouldRebuild(_CalendarSliverDelegate oldDelegate) {
  return maxHeight != oldDelegate.maxHeight ||
      minHeight != oldDelegate.minHeight ||
      focusedDate != oldDelegate.focusedDate;
}

// builder 내부에서 Provider.of(listen: false) 사용
builder: (context, shrinkOffset) {
  final state = Provider.of<AppStateProvider>(context, listen: false);
  // state 활용
}
```

**DON'T**:
```dart
// key로 강제 재생성 - 스크롤 위치 초기화됨
SliverPersistentHeader(
  key: ValueKey(appState.focusedDate), // ❌
  ...
)

// shouldRebuild에서 항상 true - 성능 저하
@override
bool shouldRebuild(_CalendarSliverDelegate oldDelegate) {
  return true; // ❌
}
```

#### 3. 동적 크기 조정

```dart
// LayoutBuilder로 사용 가능한 공간 측정
LayoutBuilder(
  builder: (context, constraints) {
    // constraints.maxHeight로 높이 계산
    final itemHeight = constraints.maxHeight / itemCount;
    return Widget(height: itemHeight);
  },
)
```

#### 4. 선택적 위젯 업데이트

```dart
// Consumer로 필요한 부분만 업데이트
Consumer<AppStateProvider>(
  builder: (context, state, child) {
    // state가 변경되면 이 부분만 rebuild
    return Text(state.value);
  },
)

// child 파라미터로 정적 부분 최적화
Consumer<AppStateProvider>(
  child: ExpensiveWidget(), // 한 번만 빌드됨
  builder: (context, state, child) {
    return Column(
      children: [
        Text(state.value), // 동적
        child!, // 정적
      ],
    );
  },
)
```

#### 5. 디버깅 팁

```dart
// shrinkOffset 출력으로 스크롤 진행률 확인
@override
Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
  print('shrinkOffset: $shrinkOffset, progress: ${shrinkOffset / (maxExtent - minExtent)}');
  ...
}

// shouldRebuild 호출 확인
@override
bool shouldRebuild(_CalendarSliverDelegate oldDelegate) {
  final result = maxHeight != oldDelegate.maxHeight ||
      minHeight != oldDelegate.minHeight ||
      focusedDate != oldDelegate.focusedDate;
  print('shouldRebuild: $result (focusedDate: $focusedDate -> ${oldDelegate.focusedDate})');
  return result;
}
```

#### 6. 관련 파일 위치

- **홈 화면**: `frontend/lib/screens/home_screen.dart`
- **AppState**: `frontend/lib/services/app_state_provider.dart`
- **캘린더 유틸**: `frontend/lib/utils/responsive_utils.dart`
- **테마 설정**: `frontend/lib/config/themes.dart`

#### 7. 참고 자료

- [SliverPersistentHeader 공식 문서](https://api.flutter.dev/flutter/widgets/SliverPersistentHeader-class.html)
- [CustomScrollView 가이드](https://docs.flutter.dev/ui/layout/scrolling/slivers)
- [Provider 패턴](https://pub.dev/packages/provider)
- [TableCalendar 문서](https://pub.dev/packages/table_calendar)

---

**세션 종료**: 2026년 03월 29일 23:31 (KST)
**상태**: 성공적으로 완료
**권장 다음 작업**: Git 커밋 수행
