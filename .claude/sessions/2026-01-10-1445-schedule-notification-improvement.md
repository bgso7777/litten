# 스케줄 알림 기능 개선

## 세션 개요
- **시작 시간**: 2026-01-10 14:45 (KST)
- **종료 시간**: 2026-01-10 19:18 (KST)
- **총 소요 시간**: 4시간 33분
- **세션 ID**: 2026-01-10-1445-schedule-notification-improvement
- **최종 상태**: ❌ 실패 - 요구사항 오해로 인한 전체 롤백

## 목표
스케줄의 알림 기능을 개선하여 사용자 경험을 향상시킵니다.

### 주요 작업
- [ ] 현재 알림 시스템 분석
- [ ] 개선이 필요한 부분 파악
- [ ] 알림 기능 개선 구현
- [ ] 테스트 및 검증

## 진행 상황

### [14:45] 세션 시작
- 스케줄 알림 기능 개선 작업 시작
- 현재 코드베이스 분석 예정

### 업데이트 - 2026-01-10 오후 7:13

**요약**: 실시간 알림 기능 시도 - 실패로 인한 수동 롤백 예정

**Git 변경 사항**:
- 수정됨: frontend/lib/screens/home_screen.dart
- 수정됨: frontend/lib/services/app_state_provider.dart
- 수정됨: frontend/lib/services/notification_service.dart
- 수정됨: frontend/lib/widgets/home/litten_item.dart
- 추가됨: frontend/lib/widgets/home/missed_notifications_widget.dart
- 현재 브랜치: main (커밋: 5aed9b8 알림 개선)

**할 일 진행 상황**: 완료 2건, 진행 중 1건
- ✓ 완료됨: 다이얼로그 제거 및 배지만 표시하도록 수정
- ✓ 완료됨: 이미 지난 알림 재스케줄링 방지
- ⏳ 진행 중: Android에서 수정된 알림 기능 테스트

**발생한 이슈**:
1. **초기 요구사항 오해**: 앱 실행 중 다이얼로그로 알림을 표시하는 것으로 잘못 이해
   - 사용자는 실제로 다이얼로그 없이 배지만 원함
   - 놓친 알림도 상단 위젯이 아닌 개별 리튼 배지로 표시

2. **알림 중복 발생**:
   - 알림이 발생한 후에도 계속 재스케줄링되어 30초마다 반복 발생
   - 원인: `_calculateNotificationTimes()`에서 `-1분` 이내의 지난 알림도 포함시킴

3. **HomeScreen 빌드 메서드 내 로직 문제**:
   - `build()` 메서드에서 직접 알림 감지 및 다이얼로그 표시
   - 매 빌드마다 `addPostFrameCallback` 호출로 "껌뻑" 현상 발생

**시도한 해결책**:
1. **실시간 알림 시스템 구현**:
   - `NotificationService`에 `onRealtimeNotification` 콜백 추가
   - 포그라운드에서 다이얼로그 표시, 백그라운드에서 시스템 알림 사용
   - `HomeScreen`에 `addListener()` 방식으로 알림 감지

2. **알림 중복 방지**:
   - `_calculateNotificationTimes()`에서 `nextTrigger.isAfter(now)` 조건으로 미래 알림만 스케줄링
   - 기존: `-1분` 이내 포함 → 수정: 미래 알림만

3. **UI 개선 시도**:
   - 상단 `MissedNotificationsWidget` 제거
   - 개별 리튼 아이템에 주황색 알림 배지 추가
   - `getNotificationCountForLitten()` 메서드로 알림 개수 표시

**변경된 코드 내용**:

1. **notification_service.dart**:
   - `onRealtimeNotification` 콜백 추가 (후에 제거)
   - `_fireNotification()`: 포그라운드/백그라운드 분기 처리
   - `_calculateNotificationTimes()`: 지난 알림 스케줄링 방지 (`nextTrigger.isAfter(now)`)

2. **app_state_provider.dart**:
   - `_onRealtimeNotification()` 콜백 메서드 추가
   - `getNotificationCountForLitten()`: 발생/놓친 알림 개수 반환
   - `hasNotificationForLitten()`: 발생/놓친 알림 존재 여부 확인

3. **home_screen.dart**:
   - `_onNotificationServiceChanged()`: 알림 서비스 리스너 등록
   - `_showRealtimeNotificationDialog()`: 다이얼로그 표시 (후에 제거)
   - `initState()`/`dispose()`에 리스너 등록/해제

4. **litten_item.dart**:
   - 알림 배지 표시 로직 추가 (주황색 아이콘 + 숫자)
   - `Consumer<AppStateProvider>`로 알림 개수 실시간 업데이트

**최종 결과**:
- ❌ 구현 실패 - 사용자 요구사항과 불일치
- 사용자가 수동으로 소스 코드 롤백 예정
- 다이얼로그 표시 기능 불필요 (배지만 필요)
- 일부 로직은 재사용 가능 (알림 중복 방지 로직 등)

**교훈**:
1. 초기에 요구사항을 명확히 확인 필요
2. "실시간 알림"의 의미가 다이얼로그가 아닌 배지 업데이트였음
3. 단계적 접근 필요 - 먼저 기본 기능 확인 후 추가 기능 구현

---

## 세션 종료 요약

### Git 최종 상태
**변경된 파일**: 총 8개
- **수정됨 (M)**: 6개
  - `.claude/sessions/.current-session`
  - `0_history.txt`
  - `frontend/lib/screens/home_screen.dart`
  - `frontend/lib/services/app_state_provider.dart`
  - `frontend/lib/services/notification_service.dart`
  - `frontend/lib/widgets/home/litten_item.dart`

- **추가됨 (??)**: 2개
  - `.claude/sessions/2026-01-10-1445-schedule-notification-improvement.md`
  - `frontend/lib/widgets/home/missed_notifications_widget.dart`

**커밋 수**: 0개 (모든 변경사항 커밋되지 않음)

**최종 상태**:
- 브랜치: main
- 마지막 커밋: 5aed9b8 "알림 개선"
- 모든 변경사항 unstaged

### 할 일 최종 요약
**완료**: 2건 (기술적으로는 완료했으나 요구사항 불일치로 무의미)
- ✅ 다이얼로그 제거 및 배지만 표시하도록 수정
- ✅ 이미 지난 알림 재스케줄링 방지

**미완료**: 2건
- ❌ Android에서 수정된 알림 기능 테스트 (중단됨)
- ❌ 알림 기능 개선 구현 (실패)

### 주요 성과
**없음** - 요구사항 오해로 인한 전체 실패

### 구현 시도한 기능 (모두 롤백 예정)

#### 1. 실시간 알림 시스템
```dart
// NotificationService
Function(NotificationEvent)? onRealtimeNotification;

if (!_isInBackground) {
  debugPrint('📱 포그라운드 - 배지만 표시');
} else {
  await _backgroundService.showNotification(...);
}
```

#### 2. 알림 배지 시스템
```dart
// AppStateProvider
int getNotificationCountForLitten(String littenId) {
  return _firedNotifications.where(...).length +
         _missedNotifications.where(...).length;
}

// LittenItem
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    final count = appState.getNotificationCountForLitten(litten.id);
    if (count > 0) return _buildFileBadge(...);
  }
)
```

#### 3. 알림 중복 방지 로직 (재사용 가능)
```dart
// 기존 (문제)
if (nextTrigger.isAfter(now) || (timeDiff.inMinutes >= -1 && timeDiff.inMinutes <= 0))

// 수정 (정상)
if (nextTrigger.isAfter(now))  // 미래 알림만
```

### 발생한 문제와 시도한 해결책

#### 문제 1: 근본적인 요구사항 오해
- **문제**: "앱 실행 중 실시간 알림"을 다이얼로그 팝업으로 해석
- **실제 요구**: 다이얼로그 없이 배지만 업데이트
- **영향**: 전체 구현 방향이 잘못됨
- **교훈**: 초기 단계에서 UI 목업이나 예시 확인 필수

#### 문제 2: 알림 무한 반복
- **증상**: 정시 알림이 30초마다 계속 발생
- **원인**: 이미 지난 알림(-1분 이내)도 재스케줄링
- **해결**: `nextTrigger.isAfter(now)` 조건으로 미래 알림만 포함
- **상태**: 해결 완료 (이 부분은 유효한 개선)

#### 문제 3: UI "껌뻑" 현상
- **증상**: 화면이 반복적으로 깜빡이며 다이얼로그 재표시
- **원인**: `build()` 메서드 내에서 `addPostFrameCallback` 반복 호출
- **해결**: `initState()`에서 `addListener()` 패턴으로 변경
- **교훈**: Flutter에서 `build()` 메서드는 순수 함수여야 함

#### 문제 4: 디스크 공간 부족
- **증상**: "No space left on device" 빌드 에러
- **해결**: `flutter clean` 및 빌드 캐시 삭제
- **근본 원인**: Mac 디스크 용량 부족 (별도 해결 필요)

### 주요 변경 사항 상세

#### notification_service.dart
```dart
// 추가된 콜백 (나중에 제거)
Function(NotificationEvent)? onRealtimeNotification;

// _fireNotification() 수정
if (_isInBackground) {
  await _backgroundService.showNotification(...);
} else {
  debugPrint('📱 포그라운드 - 배지만 표시 (다이얼로그 없음)');
}

// _calculateNotificationTimes() 수정 (유효한 개선)
if (nextTrigger.isAfter(now)) {  // 미래 알림만
  notifications.add(NotificationEvent(...));
}
```

#### app_state_provider.dart
```dart
// 실시간 알림 콜백 (사용되지 않음)
void _onRealtimeNotification(NotificationEvent event) {
  notifyListeners();
}

// 알림 개수 계산
int getNotificationCountForLitten(String littenId) {
  final fired = _notificationService.firedNotifications
      .where((n) => n.littenId == littenId).length;
  final missed = _notificationService.missedNotifications
      .where((n) => n.littenId == littenId).length;
  return fired + missed;
}

// 알림 존재 여부
bool hasNotificationForLitten(String littenId) {
  return _notificationService.firedNotifications.any(...) ||
         _notificationService.missedNotifications.any(...);
}
```

#### home_screen.dart
```dart
// 상태 변수
int _lastFiredNotificationCount = 0;

// initState
appState.notificationService.addListener(_onNotificationServiceChanged);
_lastFiredNotificationCount = appState.notificationService.firedNotifications.length;

// dispose
appState.notificationService.removeListener(_onNotificationServiceChanged);

// 리스너
void _onNotificationServiceChanged() {
  final currentCount = appState.notificationService.firedNotifications.length;
  if (currentCount > _lastFiredNotificationCount) {
    _lastFiredNotificationCount = currentCount;
    if (mounted) setState(() {});  // 배지 업데이트
  }
}

// 다이얼로그 메서드 (나중에 삭제)
void _showRealtimeNotificationDialog(...) { ... }
```

#### litten_item.dart
```dart
// 알림 배지 표시
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    final notificationCount = appState.getNotificationCountForLitten(widget.litten.id);
    if (notificationCount > 0) {
      return Row(
        children: [
          _buildFileBadge(
            Icons.notifications_active,
            notificationCount,
            Colors.orange.shade600,
            isActive: true,
          ),
          AppSpacing.horizontalSpaceXS,
        ],
      );
    }
    return const SizedBox.shrink();
  },
)
```

### 추가/제거된 종속성
**없음**

### 설정 변경 사항
**없음**

### 수행된 배포 단계
**없음** - 개발 단계에서 중단

### 얻은 교훈

#### 1. 요구사항 명확화의 중요성
- "실시간 알림"이라는 용어의 의미를 초기에 확인하지 않음
- 다이얼로그 vs 배지 업데이트 vs 다른 UI 방식
- **개선 방안**: 초기 단계에서 UI 목업이나 기존 예시 확인

#### 2. 점진적 개발의 필요성
- 전체 시스템을 한 번에 구현하려 시도
- 기본 동작조차 확인하지 않고 고급 기능 구현
- **개선 방안**:
  1. 기존 동작 확인
  2. 최소 단위 구현
  3. 테스트
  4. 다음 기능 추가

#### 3. Flutter 아키텍처 이해
- `build()` 메서드는 순수 함수여야 함
- 상태 변경이나 콜백 등록은 `initState()`에서
- `addPostFrameCallback`은 신중하게 사용
- **참고**: Flutter 공식 문서 "State management best practices"

#### 4. 디버깅 중요성
- 사용자가 "껌뻑한다"고 할 때 즉시 로그 확인
- 알림 발생 시점과 횟수를 명확히 로깅
- **개선**: 더 상세한 디버그 로그 추가

### 완료되지 않은 작업

#### 즉시 필요한 작업
1. **전체 롤백** (사용자가 수동으로 진행)
   - `git checkout -- frontend/lib/screens/home_screen.dart`
   - `git checkout -- frontend/lib/services/app_state_provider.dart`
   - `git checkout -- frontend/lib/services/notification_service.dart`
   - `git checkout -- frontend/lib/widgets/home/litten_item.dart`
   - `rm frontend/lib/widgets/home/missed_notifications_widget.dart`

2. **원래 코드 상태 확인**
   - 롤백 후 앱 정상 작동 확인
   - 기존 알림 기능 테스트

#### 향후 재시도 시 접근 방법

**1단계: 요구사항 재확인**
```
질문할 사항:
- 앱 실행 중 알림 시간이 되면 어떻게 표시?
  □ 다이얼로그/팝업
  □ 배지만 업데이트
  □ 스낵바
  □ 기타
- 놓친 알림은 어떻게 표시?
  □ 상단 위젯
  □ 개별 리튼 배지
  □ 별도 화면
```

**2단계: 최소 구현**
```dart
// 단계 1: 기존 시스템 확인
- Timer가 작동하는지 확인
- 알림이 _pendingNotifications에 추가되는지 확인
- 알림 시간이 되면 _firedNotifications로 이동하는지 확인

// 단계 2: 배지 표시만 구현
- hasNotificationForLitten() 메서드만 추가
- UI에서 간단한 아이콘 표시
- 테스트

// 단계 3: 개수 표시 추가
- getNotificationCountForLitten() 추가
- 숫자 표시
- 테스트

// 단계 4: 중복 방지
- nextTrigger.isAfter(now) 적용
- 테스트
```

**3단계: 테스트 시나리오**
```
1. 앱 실행 중 알림 시간 도래
   - 배지가 표시되는가?
   - 알림이 1번만 발생하는가?

2. 앱 종료 후 재시작
   - 놓친 알림이 표시되는가?
   - 개수가 정확한가?

3. 리튼 클릭
   - 알림이 사라지는가?
   - firedNotifications에서 제거되는가?
```

### 미래 개발자를 위한 팁

#### 알림 시스템 구조 이해
```
NotificationService
├─ _pendingNotifications: 아직 발생하지 않은 알림
├─ _firedNotifications: 발생했지만 확인 안 한 알림
├─ _missedNotifications: 앱 꺼진 동안 발생한 알림
└─ Timer (30초): 알림 시간 체크
```

#### 알림 생명주기
```
1. scheduleNotifications() 호출
   → _pendingNotifications에 추가

2. Timer가 시간 체크 (30초마다)
   → _checkNotifications()

3. 알림 시간 도래
   → _fireNotification()
   → _pendingNotifications에서 제거
   → _firedNotifications에 추가

4. 사용자가 확인
   → _firedNotifications에서 제거
```

#### 주의사항

**DO (해야 할 것)**:
```dart
// 1. 미래 알림만 스케줄링
if (nextTrigger.isAfter(now)) {
  notifications.add(...);
}

// 2. initState에서 리스너 등록
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    service.addListener(_onServiceChanged);
  });
}

// 3. dispose에서 리스너 제거
@override
void dispose() {
  service.removeListener(_onServiceChanged);
  super.dispose();
}

// 4. mounted 체크
if (mounted) {
  setState(() {});
}
```

**DON'T (하지 말아야 할 것)**:
```dart
// 1. build() 메서드 내 상태 변경
Widget build(BuildContext context) {
  ✗ setState(() {});  // 절대 안 됨
  ✗ addListener(...);  // 절대 안 됨
  ✗ WidgetsBinding.instance.addPostFrameCallback(...);  // 반복 호출됨
}

// 2. 이미 지난 알림 재스케줄링
✗ if (timeDiff.inMinutes >= -1) { ... }  // 중복 발생 원인

// 3. 리스너 미제거
✗ // dispose 없이 리스너만 등록  // 메모리 누수
```

#### 유용한 디버그 로그
```dart
// 알림 발생 시
debugPrint('🔔 알림: ${notification.littenTitle}');
debugPrint('   시간: ${notification.timingDescription}');
debugPrint('   앱 상태: ${_isInBackground ? "백그라운드" : "포그라운드"}');

// 알림 체크 시 (30초마다)
debugPrint('🕒 알림 체크: ${DateFormat('HH:mm:ss').format(now)}');
debugPrint('   대기 중인 알림: ${_pendingNotifications.length}개');
debugPrint('   발생한 알림: ${_firedNotifications.length}개');
debugPrint('   놓친 알림: ${_missedNotifications.length}개');

// 스케줄링 시
for (final n in _pendingNotifications) {
  debugPrint('   - ${n.littenTitle}: ${DateFormat('HH:mm').format(n.triggerTime)}');
}
```

#### 재사용 가능한 코드

**1. 알림 중복 방지 로직**:
```dart
// notification_service.dart:878
if (nextTrigger.isAfter(now)) {  // 이 조건은 유효
  notifications.add(NotificationEvent(...));
}
```

**2. 알림 개수 계산**:
```dart
// app_state_provider.dart
int getNotificationCountForLitten(String littenId) {
  final fired = _notificationService.firedNotifications
      .where((n) => n.littenId == littenId).length;
  final missed = _notificationService.missedNotifications
      .where((n) => n.littenId == littenId).length;
  return fired + missed;
}
```

**3. Consumer 패턴 배지 표시**:
```dart
// litten_item.dart 패턴은 재사용 가능
Consumer<AppStateProvider>(
  builder: (context, appState, child) {
    final count = appState.getNotificationCountForLitten(...);
    if (count > 0) return Badge(...);
    return SizedBox.shrink();
  },
)
```

### 참고 자료
- Flutter 공식 문서: State management
- NotificationService 기존 구현 (commit: 5aed9b8)
- 이 세션의 실패 경험

---

**최종 메모**: 이 세션은 실패했지만, 알림 중복 방지 로직과 배지 표시 패턴은 재사용 가능합니다. 다음 시도 시에는 반드시 요구사항을 명확히 확인하고 점진적으로 구현하세요.
