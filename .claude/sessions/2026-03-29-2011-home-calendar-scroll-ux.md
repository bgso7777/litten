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
