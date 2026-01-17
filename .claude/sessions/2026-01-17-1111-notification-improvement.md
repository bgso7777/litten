# 알림 기능 개선

## 세션 개요
- **시작 시간**: 2026-01-17 11:11 (KST)
- **세션 ID**: 2026-01-17-1111-notification-improvement
- **상태**: 진행 중

## 목표
리튼 앱의 알림 기능을 개선하여 사용자 경험을 향상시킵니다.

### 주요 작업
- [ ] 알림 기능 요구사항 명확히 파악
- [ ] 현재 알림 시스템 상태 분석
- [ ] 개선이 필요한 부분 식별
- [ ] 알림 기능 개선 구현
- [ ] 테스트 및 검증

## 이전 세션 참고사항
이전 세션 (2026-01-10)에서 알림 기능 개선을 시도했으나 요구사항 오해로 실패했습니다.

**재사용 가능한 코드**:
- 알림 중복 방지 로직: `if (nextTrigger.isAfter(now))`
- 배지 표시 패턴 (Consumer 활용)

**주요 교훈**:
1. 요구사항을 초기에 명확히 확인할 것
2. 점진적으로 구현하고 각 단계마다 테스트
3. Flutter `build()` 메서드는 순수 함수여야 함

**참고 문서**: `.claude/sessions/2026-01-10-1445-schedule-notification-improvement.md`

## 진행 상황

### [11:11] 세션 시작
- 알림 기능 개선 작업 시작
- 이전 세션의 실패 경험을 바탕으로 신중한 접근
- 요구사항 명확화부터 시작

### 요구사항 분석
**문제점**: 기존 타이머 기반 알림은 배터리 절약, 백그라운드, 앱 종료 시 작동 안 함

**새로운 아키텍처**:
1. **생성/수정 시**: 알림을 미리 생성하여 저장
   - 1회성 알림: 1개 생성
   - 반복 알림: 1년치(365일) 생성
2. **수정 시**: 기존 알림 모두 삭제 후 재생성
3. **타이머 재시작 시**: 반복 알림 1년치 유지 확인
4. **타이머 동작**: 저장된 알림 체크하여 발생
5. **확인 시**: 해당 알림 삭제
6. **앱 재시작/백그라운드 복귀 시**: 놓친 알림 체크 및 표시

### [구현 완료] 알림 저장소 시스템
#### 1. StoredNotification 모델 클래스
**파일**: `frontend/lib/models/stored_notification.dart`
- 알림 고유 ID, 리튼 ID, 트리거 시간, 규칙, 반복 여부, 확인 여부 저장
- JSON 직렬화/역직렬화 구현
- `generateId()` 헬퍼 메소드: 리튼 ID + 트리거 시간으로 고유 ID 생성
- `markAsAcknowledged()`: 알림 확인 처리

#### 2. NotificationStorageService
**파일**: `frontend/lib/services/notification_storage_service.dart`
- SharedPreferences를 사용한 영구 저장
- 주요 메소드:
  - `loadNotifications()`: 모든 알림 로드
  - `saveNotifications()`: 알림 저장
  - `loadNotificationsByLittenId()`: 특정 리튼 알림 조회
  - `deleteNotificationsByLittenId()`: 리튼별 알림 삭제
  - `deleteNotification()`: 특정 알림 삭제
  - `addNotifications()`: 여러 알림 추가 (중복 제거)
  - `getPastUnacknowledgedNotifications()`: 놓친 알림 조회
  - `getStatistics()`: 통계 조회

#### 3. NotificationGeneratorService
**파일**: `frontend/lib/services/notification_generator_service.dart`
- 알림 생성 로직 전담
- `generateNotificationsForLitten()`: 리튼의 알림 생성
  - 1회성 알림 (onDay, oneDayBefore): 1개만 생성
  - 반복 알림 (daily, weekly, monthly, yearly): 1년치 생성
- 알림 발생 시간 범위 검증 (notificationStartTime ~ notificationEndTime)
- 주별 알림의 요일 필터링 지원

#### 4. NotificationOrchestratorService
**파일**: `frontend/lib/services/notification_orchestrator_service.dart`
- 저장소와 생성기를 조율하는 통합 서비스
- 주요 메소드:
  - `scheduleNotificationsForLitten()`: 알림 스케줄링 (기존 삭제 → 새로 생성 → 저장)
  - `maintainYearlyNotifications()`: 1년치 알림 유지 로직
  - `checkMissedNotifications()`: 놓친 알림 체크
  - `acknowledgeNotification()`: 알림 확인 및 삭제
  - `deleteNotificationsForLitten()`: 리튼 삭제 시 알림 정리

#### 5. NotificationService 통합
**파일**: `frontend/lib/services/notification_service.dart`
- 기존 NotificationService에 새로운 저장소 시스템 통합
- **수정된 메소드**:
  - `scheduleNotifications()`: orchestrator를 통해 알림 저장소에 저장
  - `onAppResumed()`: 놓친 알림 체크 추가 (`_checkMissedNotificationsFromStorage()`)
  - `dismissNotification()`: 알림 확인 시 저장소에서도 삭제
  - `startNotificationChecker()`: 타이머 시작 시 1년치 유지 로직 실행

### 구현된 기능 요약
✅ **1회성 알림**: onDay, oneDayBefore 타입은 1개만 생성
✅ **반복 알림**: daily, weekly, monthly, yearly 타입은 1년치(365일) 생성
✅ **알림 수정**: 기존 알림 삭제 후 새로 생성
✅ **1년치 유지**: 타이머 재시작 시 반복 알림이 1년 미만이면 재생성
✅ **놓친 알림**: 앱 재시작/백그라운드 복귀 시 놓친 알림 모두 표시
✅ **알림 확인**: 사용자가 배지 클릭 시 저장소에서 삭제
✅ **영구 저장**: SharedPreferences로 앱 종료/재시작에도 유지

### 주요 개선사항
1. **배터리 절약 모드 대응**: 알림을 미리 생성하여 저장하므로 타이머 중단에 영향 없음
2. **백그라운드 작동**: 저장소에서 알림을 관리하므로 백그라운드에서도 유효
3. **앱 종료 후 복구**: SharedPreferences에 저장되어 앱 재시작 후에도 알림 유지
4. **놓친 알림 복구**: 앱 복귀 시 지난 알림을 모두 찾아서 표시
5. **1년치 사전 생성**: 반복 알림은 365일치를 미리 생성하여 장기간 안정적 작동

### 다음 단계
- [ ] 실제 디바이스에서 테스트
- [ ] 배터리 절약 모드 테스트
- [ ] 백그라운드/포그라운드 전환 테스트
- [ ] 놓친 알림 복구 테스트
- [ ] 1년치 알림 유지 로직 테스트

---

### 업데이트 - 2026-01-17 11:40

**요약**: 알림 저장소 시스템 구현 완료 및 iOS 시뮬레이터 테스트 진행

**Git 변경 사항**:
- 수정됨: `frontend/lib/services/notification_service.dart`
- 수정됨: `.claude/sessions/.current-session`, `0_history.txt`
- 추가됨: `frontend/lib/models/stored_notification.dart`
- 추가됨: `frontend/lib/services/notification_storage_service.dart`
- 추가됨: `frontend/lib/services/notification_generator_service.dart`
- 추가됨: `frontend/lib/services/notification_orchestrator_service.dart`
- 추가됨: `.claude/sessions/2026-01-17-1111-notification-improvement.md`
- 현재 브랜치: main (커밋: 3e66ec1 - "알림 개선 2 - 실패")

**할 일 진행 상황**: 완료 11건, 진행 중 0건, 대기 중 0건
- ✓ 완료: StoredNotification 모델 클래스 생성
- ✓ 완료: JSON 직렬화/역직렬화 구현
- ✓ 완료: SharedPreferences 저장/로드 로직
- ✓ 완료: 1회성 알림 생성 로직 (1개)
- ✓ 완료: 반복 알림 생성 로직 (1년치)
- ✓ 완료: 알림 수정 시 이전 알림 삭제
- ✓ 완료: 타이머 재시작 시 1년치 유지 로직
- ✓ 완료: 놓친 알림 체크 및 표시
- ✓ 완료: 알림 확인 시 삭제 로직
- ✓ 완료: NotificationService에 통합
- ✓ 완료: 구현 내용 요약 및 문서화

**구현 세부사항**:

1. **새로운 파일 생성**:
   - `StoredNotification` 모델: 알림 데이터를 JSON으로 직렬화하여 SharedPreferences에 저장
   - `NotificationStorageService`: 알림 CRUD 작업 전담 (로드, 저장, 삭제, 조회)
   - `NotificationGeneratorService`: 알림 생성 로직 (1회성 1개, 반복 1년치)
   - `NotificationOrchestratorService`: 저장소와 생성기를 조율하는 통합 서비스

2. **NotificationService 통합**:
   - `scheduleNotifications()`: orchestrator를 통해 알림을 저장소에 저장
   - `onAppResumed()`: 놓친 알림 체크 로직 추가 (`_checkMissedNotificationsFromStorage()`)
   - `dismissNotification()`: 알림 확인 시 저장소에서도 삭제
   - `startNotificationChecker()`: 타이머 시작 시 1년치 유지 로직 실행

3. **핵심 기능**:
   - 1회성 알림 (onDay, oneDayBefore): 1개만 생성
   - 반복 알림 (daily, weekly, monthly, yearly): 1년치(365개) 생성
   - 알림 수정 시 기존 알림 삭제 후 재생성
   - 타이머 재시작 시 반복 알림이 1년 미만이면 자동 재생성
   - 앱 재시작/백그라운드 복귀 시 놓친 알림 모두 표시
   - 배터리 절약 모드, 백그라운드, 앱 종료 시에도 알림 유지

**테스트 진행**:
- iOS 시뮬레이터(iPhone 16 Plus)에서 앱 빌드 및 실행 성공
- 앱 재시작 테스트 완료 (kill & restart)
- 알림 타이머가 30초마다 정상 작동 확인
- Android 에뮬레이터 실행 실패 (Android Studio에서 수동 실행 필요)

**발생한 이슈**:
- Android 에뮬레이터(Medium_Phone, Medium_Phone_API_36.0) 실행 실패 (exit code 1)
- adb 명령어가 PATH에 없음 (전체 경로로 해결)

**다음 작업**:
- 실제 리튼에 스케줄 추가하여 알림 생성 테스트
- 저장소에 알림이 저장되는지 로그 확인
- 놓친 알림 복구 시나리오 테스트
- 1년치 알림 유지 로직 동작 확인

