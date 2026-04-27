# AOS Release 빌드 및 에뮬레이터 실행

## 세션 개요
- **시작 시간**: 2026-04-27 12:01 (KST)
- **목적**: Android 앱을 release 모드로 빌드하여 에뮬레이터(Litten Pixel5)에서 실행
- **에뮬레이터**: sdk gphone64 x86 64 / emulator-5554 (Android 15 API 35)

## 목표
- [x] Android 에뮬레이터(Litten_Pixel5) 실행
- [x] Flutter 빌드 완료 (debug 모드로 전환하여 진행)
- [x] 에뮬레이터에 앱 설치 및 실행 확인
- [x] UI 개선 작업 다수 완료

## 진행 상황

### 2026-04-27 12:01
- `Litten_Pixel5` 에뮬레이터 실행 시작
- 에뮬레이터 부팅 완료 확인 (Android 15 API 35)
- `flutter run --release -d emulator-5554` 명령 실행 중 (백그라운드)

---

### 업데이트 - 2026-04-28 오전 (KST)

**요약**: 노트탭 UI 전면 개선 - 통계 헤더 제거, 일정 리스트 통합, 탭 타이틀 파일 카운트 표시, 파일명 일정 이름 기반 변경

**Git 변경 사항**:
- 수정됨: `frontend/lib/screens/writing_screen.dart`
- 수정됨: `frontend/lib/services/audio_service.dart`
- 수정됨: `frontend/lib/widgets/draggable_tab_layout.dart`
- 수정됨: `frontend/lib/widgets/handwriting_tab.dart`
- 수정됨: `frontend/lib/widgets/text_tab.dart`
- 수정됨: `frontend/lib/widgets/common/litten_unified_list_view.dart`
- 현재 브랜치: main (커밋: 4afb44e)

**할 일 진행 상황**: 완료 9건
- ✓ 노트탭 통계 헤더(광고 아래 45px 바) 제거
- ✓ 캘린더 일정리스트 통계 바 복원 (잘못 제거된 것 복원)
- ✓ 노트탭 상단에 캘린더와 동일한 통계 바 + 일정리스트 표시 (LittenUnifiedListView 재사용)
- ✓ 노트탭 전환 시 선택 일정 없으면 일정리스트 자동 펼치기
- ✓ 빈 화면 메시지 "먼저 일정을 선택하세요."로 변경
- ✓ 텍스트/필기/녹음 탭 타이틀을 각 파일 카운트로 변경 (선택된 일정 기준)
- ✓ 파일명 생성 시 접두어(텍스트/필기/녹음) → 선택된 일정 이름으로 변경
- ✓ 텍스트 파일 신규 저장 시 updateFileCount() 호출 추가 (주석 해제)
- ✓ DraggableTabLayout didUpdateWidget에 setState() 추가 (탭 타이틀 실시간 갱신)

**세부사항**:

#### WritingScreen 구조 변경
- 기존: Stack + AnimatedPositioned + 커스텀 `_buildStatsHeader` (45px 바)
- 변경: Column + AnimatedContainer(45px↔반화면) + `LittenUnifiedListView`
- `listVisible`/`onListToggle` 파라미터를 `LittenUnifiedListView`에 추가하여 외부에서 높이 제어
- `_onAppStateChanged` 리스너로 노트탭 진입 시 선택 일정 없으면 자동 펼침

#### 탭 타이틀 파일 카운트
- `_initializeTabs()` 에 `textCount`, `handwritingCount`, `audioCount` 파라미터 추가
- `appState.actualTextCount` / `actualHandwritingCount` / `actualAudioCount` 사용
- 검색탭만 "검색" 텍스트 유지

#### 파일명 변경
- text_tab.dart: `텍스트 YYMMDD...` → `{일정명} YYMMDD...`
- handwriting_tab.dart: `필기 YYMMDD...` → `{일정명} YYMMDD...`
- audio_service.dart: `녹음 YYMMDDHHMMSS.m4a` → `{일정명} YYMMDDHHMMSS.m4a`
- undefined 일정일 경우 기존 접두어 유지

**발생한 이슈**:
- 캘린더 통계 바를 실수로 삭제 → 복원
- DraggableTabLayout이 didUpdateWidget에서 setState() 미호출 → 탭 타이틀 갱신 안 됨 → 수정
- text_tab에서 신규 파일 저장 시 updateFileCount() 주석 처리됨 → 카운트 미갱신 → 수정

---

## 세션 종료 요약 - 2026-04-28 오전 (KST)

### 세션 소요 시간
- 시작: 2026-04-27 12:01 KST
- 종료: 2026-04-28 오전 KST
- 약 14~15시간 (복수 세션에 걸쳐 진행)

---

### Git 요약

**총 커밋 수**: 9개 (이번 세션 동안)

| 커밋 | 메시지 | 주요 변경 파일 |
|------|--------|--------------|
| 4afb44e | 노트탭 UI 개선 7 | writing_screen, audio_service, draggable_tab_layout, handwriting_tab, text_tab |
| 2475256 | 캘린더 일정 UI 개선 6 | writing_screen, litten_unified_list_view |
| ad0e25d | 캘린더 일정 UI 개선 5 | writing_screen, litten_unified_list_view |
| 656af49 | 캘린더 일정 UI 개선 5 | app_state_provider, litten_unified_list_view |
| a669ec2 | 캘린더 일정 UI 개선 4 | main_tab_screen, app_state_provider |
| b5dfe2b | 캘린더 일정 UI 개선 3 | app_state_provider, litten_unified_list_view |
| 82e0296 | 캘린더 일정 UI 개선 2 | app_state_provider |
| b986652 | 캘린더 일정 UI 개선 | app_state_provider, litten_unified_list_view |
| 079625b | 캘린더 UI 개선 | home_screen, litten_unified_list_view, dialogs |

**변경된 주요 파일**:
- `frontend/lib/screens/writing_screen.dart` — 노트탭 전면 재구성
- `frontend/lib/screens/main_tab_screen.dart` — undefined 자동 선택 제거
- `frontend/lib/services/app_state_provider.dart` — 콜드스타트 선택 초기화, 파일 카운트 이중 추적(전체/선택)
- `frontend/lib/services/audio_service.dart` — 파일명 일정 이름 기반 변경
- `frontend/lib/widgets/common/litten_unified_list_view.dart` — 통계 바 토글, 외부 제어 파라미터 추가
- `frontend/lib/widgets/draggable_tab_layout.dart` — didUpdateWidget setState() 추가
- `frontend/lib/widgets/text_tab.dart` — 파일명 변경, 신규 저장 시 카운트 갱신
- `frontend/lib/widgets/handwriting_tab.dart` — 파일명 일정 이름 기반 변경
- `frontend/lib/screens/home_screen.dart` — 캘린더 UI 개선

**최종 git 상태**: 워킹트리 클린 (세션 파일만 미커밋)

---

### 완료된 작업 목록

1. **undefined 자동 선택 제거**: 앱 시작 시 undefined 리튼이 자동으로 선택되던 문제 해결
   - `MainTabScreen.build()`의 `postFrameCallback` 코드 제거
   - 콜드스타트 시 선택 리튼 초기화 (`initializeApp()`에 추가)
   - `_restoreSelectedLittenState()` / `_loadSelectedLitten()`에서 undefined 필터링

2. **앱 시작 시 일정 미선택 상태로 시작**: `initializeApp()`에서 SharedPreferences 선택 값 클리어

3. **통계 숫자 항상 전체 표시**: `getActualFileCounts()` 리팩토링
   - 단일 패스에서 전체 카운트(`_totalAudioCount` 등)와 선택 카운트(`_actualAudioCount` 등) 동시 집계

4. **아이콘 정렬 수정**: 통계 바 아이콘과 일정 행 아이콘 사이 8px 오프셋 해결
   - `SliverPadding` left 값을 SliverToBoxAdapter 아이콘 위치에 반영

5. **통계 바 탭 토글**: 통계 바 클릭 시 일정 리스트 보이기/감추기 토글
   - `GestureDetector` + `HitTestBehavior.opaque` 적용
   - "..." 메뉴 탭 이벤트 흡수로 이중 토글 방지

6. **노트탭 통계 헤더 제거**: `WritingScreen`에서 커스텀 45px 통계 바 완전 제거

7. **노트탭에 캘린더와 동일한 통계+일정리스트 통합**:
   - `LittenUnifiedListView`에 `listVisible` / `onListToggle` 외부 제어 파라미터 추가
   - `WritingScreen`에 `AnimatedContainer`로 패널 높이 제어 (45px ↔ 화면 절반)
   - 기본 상태: 접힘(45px 통계 바만 표시)

8. **노트탭 자동 펼치기**: 노트탭 전환 시 선택 일정 없으면 일정리스트 자동 펼침
   - `AppStateProvider` 리스너 등록 (`initState`에서 `addPostFrameCallback` 사용)

9. **빈 화면 메시지 변경**: "먼저 리튼을 선택하거나 생성하세요" → "먼저 일정을 선택하세요."

10. **탭 타이틀을 파일 카운트로 변경**: 텍스트/필기/녹음 탭 타이틀이 각 파일 수를 표시
    - `_initializeTabs()`에 `textCount`, `handwritingCount`, `audioCount` 파라미터 추가

11. **파일명 일정 이름 기반 생성**: 접두어(텍스트/필기/녹음) → 선택된 일정 이름
    - text_tab, handwriting_tab, audio_service 모두 수정
    - undefined 일정은 기존 접두어 유지

12. **탭 타이틀 실시간 갱신 수정**:
    - `DraggableTabLayout.didUpdateWidget()`에 `setState(() {})` 추가
    - `text_tab.dart` 신규 파일 저장 시 `updateFileCount()` 호출 복원 (주석 해제)

---

### 발생한 문제와 해결책

| 문제 | 원인 | 해결책 |
|------|------|--------|
| undefined 항상 자동 선택 | MainTabScreen.build()의 postFrameCallback | 해당 코드 제거 + 콜드스타트 초기화 |
| 두 개의 SharedPreferences 키 불일치 | `selected_litten`(LittenService) vs `selected_litten_id`(직접) | 콜드스타트 시 양쪽 모두 클리어 |
| 통계 아이콘 8px 어긋남 | SliverToBoxAdapter(풀폭) vs SliverPadding(left:8) | hPad 오프셋 보정 |
| "..." 탭 시 이중 토글 | 부모 GestureDetector와 PopupMenuButton 이벤트 중복 | 내부 GestureDetector로 이벤트 흡수 |
| 캘린더 통계 바 실수 삭제 | 사용자 요청 오해 | _buildStatsSection 복원 + listVisible 파라미터 추가 |
| 탭 타이틀 실시간 미갱신 | didUpdateWidget에서 setState() 미호출 | setState(() {}) 추가 |
| 텍스트 파일 카운트 미갱신 | updateFileCount() 주석 처리 | 신규 파일일 때(existingIndex < 0) 호출 복원 |

---

### 주요 아키텍처 변경

#### AppStateProvider 파일 카운트 이중 추적
```dart
// 전체 카운트 (캘린더 통계 바용)
int _totalAudioCount, _totalTextCount, _totalHandwritingCount;
// 선택 리튼 카운트 (노트탭 탭 타이틀용)
int _actualAudioCount, _actualTextCount, _actualHandwritingCount;
```
`getActualFileCounts()`가 단일 패스에서 두 세트 모두 집계.

#### LittenUnifiedListView 외부 제어
```dart
// 추가된 파라미터
final bool? listVisible;      // 외부에서 리스트 표시 여부 제어
final VoidCallback? onListToggle; // 외부 토글 콜백
```
`WritingScreen`에서 `AnimatedContainer` 높이와 연동하여 사용.

---

### 미완료 작업
- 없음 (세션 내 요청 사항 모두 완료)

---

### 미래 개발자를 위한 팁

1. **탭 타이틀 카운트 갱신**: 파일 추가/삭제 후 반드시 `appState.updateFileCount()` 호출 필요. 호출하지 않으면 탭 타이틀 카운트가 갱신되지 않음.

2. **undefined 리튼**: 앱 내부적으로 "미분류" 용도로 사용. UI에 표시하지 않고 선택도 저장하지 않음. 관련 필터링 코드가 `_restoreSelectedLittenState()`, `_loadSelectedLitten()`, `selectLitten()`에 산재해 있음.

3. **WritingScreen 패널 높이**: `_listVisible` 상태 + `LittenUnifiedListView(listVisible:, onListToggle:)` 파라미터로 제어. 높이는 45px(접힘) ↔ `constraints.maxHeight / 2`(펼침).

4. **DraggableTabLayout 탭 타이틀 갱신**: `didUpdateWidget`에서 `setState(() {})` 필수. 없으면 부모가 rebuild해도 탭 타이틀 UI가 갱신되지 않음.

5. **두 종류의 파일 카운트**: `actualXxxCount`(선택 리튼), `totalXxxCount`(전체). 캘린더 통계 바는 total, 노트탭 탭 타이틀은 actual 사용.

