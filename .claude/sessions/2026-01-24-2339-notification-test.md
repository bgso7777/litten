# 알림 기능 실제 테스트

## 세션 개요
- **시작 시간**: 2026-01-24 23:39 (KST)
- **세션 ID**: 2026-01-24-2339-notification-test
- **상태**: 진행 중

## 목표
이전 세션에서 구현한 알림 저장소 시스템을 Android 및 iOS 에뮬레이터에서 실제로 테스트하고 검증합니다.

### 주요 작업
- [ ] 리튼 생성 및 스케줄 추가
- [ ] 알림 저장소에 알림이 생성되는지 로그 확인
- [ ] 1회성 알림 테스트 (onDay, oneDayBefore)
- [ ] 반복 알림 테스트 (daily, weekly, monthly)
- [ ] 1년치 알림 생성 확인
- [ ] 놓친 알림 복구 시나리오 테스트
- [ ] 앱 재시작 후 알림 유지 확인
- [ ] 배터리 절약 모드 시뮬레이션 (가능한 경우)
- [ ] 백그라운드/포그라운드 전환 테스트

## 이전 세션 참고사항
이전 세션 (2026-01-17)에서 알림 저장소 시스템을 구현했습니다.

**구현된 핵심 기능**:
- StoredNotification 모델 클래스
- NotificationStorageService (SharedPreferences 기반 영구 저장)
- NotificationGeneratorService (1회성 1개, 반복 1년치 생성)
- NotificationOrchestratorService (저장소-생성기 통합 관리)
- NotificationService 통합

**주요 특징**:
1. 1회성 알림: 1개만 생성
2. 반복 알림: 1년치(365개) 사전 생성
3. 알림 수정 시 기존 삭제 후 재생성
4. 타이머 재시작 시 1년치 유지 확인
5. 놓친 알림 자동 복구

**참고 문서**: `.claude/sessions/2026-01-17-1111-notification-improvement.md`

## 테스트 환경
- **Android**: Medium_Phone (Android 16 API 36) - emulator-5554
- **iOS**: iPhone 16 Plus (iOS 18.6) - BA12F3E5-4D30-453F-A258-3EEBB010C24D
- **현재 상태**: 두 에뮬레이터 모두 앱 실행 중

## 진행 상황

### [23:39] 세션 시작
- 알림 기능 실제 테스트 세션 시작
- Android 및 iOS 에뮬레이터 모두 앱 실행 중
- 알림 저장소 시스템 테스트 준비 완료

### 업데이트 - 2026-01-25 오전 01:35

**요약**: 미래 날짜 알림 표시 문제 및 시간 선택기 무한 스크롤 해결

**Git 변경 사항**:
- 수정됨: frontend/lib/screens/home_screen.dart
- 수정됨: frontend/lib/services/app_state_provider.dart
- 수정됨: frontend/lib/widgets/home/schedule_picker.dart
- 수정됨: frontend/lib/widgets/home/time_picker_scroll.dart
- 현재 브랜치: main (커밋: 74bffcf 알림 개선 3)

**완료된 작업**:
- ✓ 같은 날짜 두 번 클릭 시 인덱스 오류 수정
- ✓ 캘린더 마커 중복 표시 문제 해결
- ✓ NoSuchMethodError 수정 (notification.ruleType → notification.rule.frequency.label)
- ✓ 미래 날짜 알림 표시 문제 해결 (상태 관리 아키텍처 개선)
- ✓ 시간 선택기 23시→00시 무한 스크롤 문제 해결

**발생한 이슈 및 해결책**:

1. **캘린더 마커 중복 표시**
   - 문제: 1월 25일에 알림 1개만 있는데 점 2개 표시
   - 원인: 리튼 생성일과 알림 날짜를 별도로 카운트
   - 해결: `Map<String, Set<String>>` 사용하여 리튼 ID 기반 중복 제거

2. **미래 날짜 알림 미표시 (핵심 이슈)**
   - 문제: 2월 1일, 2월 8일 선택 시 "일정과 파일이 없습니다" 표시
   - 근본 원인:
     * `_selectedDateNotifications`가 HomeScreen 로컬 상태
     * Consumer 빌더가 클로저로 생성 시점 값 캡처
     * 로컬 상태 변경 시 Consumer가 감지하지 못함
   - 해결: `selectedDateNotifications`를 AppStateProvider로 이동
     ```dart
     // app_state_provider.dart
     List<dynamic> _selectedDateNotifications = [];
     List<dynamic> get selectedDateNotifications => _selectedDateNotifications;

     void setSelectedDateNotifications(List<dynamic> notifications) {
       _selectedDateNotifications = notifications;
       notifyListeners();
     }
     ```

3. **시간 선택기 무한 스크롤**
   - 문제: 23시에서 00시로 스크롤 불가
   - 원인: initialItem을 실제 시간값(0-23)으로 설정하여 범위 제한
   - 해결: initialItem을 `1000 * 24 + hour`로 설정
     ```dart
     _hourController = FixedExtentScrollController(
       initialItem: 1000 * 24 + _selectedHour
     );
     ```

**변경 코드 상세**:

`app_state_provider.dart`:
- 53-59줄: selectedDateNotifications 상태 추가
- 1164-1167줄: forceUpdate() 메서드 추가

`home_screen.dart`:
- 37줄: 로컬 _selectedDateNotifications 제거, Map 타입 변경
- 117-122줄: appState.setSelectedDateNotifications() 사용
- 746-750줄: onDaySelected 간소화
- 786-807줄: eventLoader Set 기반 중복 제거
- 1002-1035줄: displayLittens 계산 개선
- 1125-1128줄: 인덱스 범위 체크 추가
- 1127-1135줄: EmptyState 조건 수정
- 1259줄: notification.rule.frequency.label 사용

`time_picker_scroll.dart`:
- 26-33줄: initialItem 값 증가
- 42-61줄: didUpdateWidget 위치 계산 로직

**테스트 대기 중**:
- 2월 1일, 2월 8일 알림 표시 확인 필요
- 시간 선택기 23→00 전환 확인 필요
- Android/iOS 에뮬레이터 재시작 완료

