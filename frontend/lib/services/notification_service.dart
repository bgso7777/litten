import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/litten.dart';
import 'background_notification_service.dart';
import 'recurring_notification_service.dart';

class NotificationEvent {
  final String littenId;
  final String littenTitle;
  final LittenSchedule schedule;
  final NotificationRule rule;
  final DateTime triggerTime;

  NotificationEvent({
    required this.littenId,
    required this.littenTitle,
    required this.schedule,
    required this.rule,
    required this.triggerTime,
  });

  String get message {
    final startHour = schedule.startTime.hour.toString().padLeft(2, '0');
    final startMinute = schedule.startTime.minute.toString().padLeft(2, '0');
    final endHour = schedule.endTime.hour.toString().padLeft(2, '0');
    final endMinute = schedule.endTime.minute.toString().padLeft(2, '0');
    final timeStr = '$startHour:$startMinute - $endHour:$endMinute';

    switch (rule.frequency) {
      case NotificationFrequency.onDay:
        return '오늘 $timeStr에 "$littenTitle" 일정이 있습니다.';
      case NotificationFrequency.oneDayBefore:
        return '내일 $timeStr에 "$littenTitle" 일정이 있습니다.';
      case NotificationFrequency.daily:
        return '매일 $timeStr "$littenTitle" 일정 알림입니다.';
      case NotificationFrequency.weekly:
        return '매주 $timeStr "$littenTitle" 일정 알림입니다.';
      case NotificationFrequency.monthly:
        return '매월 $timeStr "$littenTitle" 일정 알림입니다.';
      case NotificationFrequency.yearly:
        return '매년 $timeStr "$littenTitle" 일정 알림입니다.';
    }
  }

  String get timingDescription {
    if (rule.timing.minutesOffset == 0) {
      return '정시 알림';
    } else if (rule.timing.minutesOffset > 0) {
      return '${rule.timing.minutesOffset}분 후 알림';
    } else {
      return '${-rule.timing.minutesOffset}분 전 알림';
    }
  }
}

class NotificationService extends ChangeNotifier {
  Timer? _timer;
  Timer? _healthCheckTimer; // 상태 체크 타이머
  final List<NotificationEvent> _pendingNotifications = [];
  final List<NotificationEvent> _firedNotifications = [];
  final Map<String, Litten> _littenMap = {}; // 리튼 ID -> 리튼 객체 매핑
  DateTime? _lastCheckTime; // 마지막 체크 시간 추적
  DateTime? _lastHealthCheckTime; // 마지막 헬스 체크 시간
  bool _isInBackground = false; // 백그라운드 상태 추적
  bool _isRunning = false; // 알림 서비스 작동 상태
  int _failureCount = 0; // 실패 횟수 추적

  // 백그라운드 알림 서비스
  final BackgroundNotificationService _backgroundService = BackgroundNotificationService();

  // 반복 알림 발생 시 자식 리튼 생성을 위한 콜백
  Function(Litten parentLitten, NotificationEvent notification)? onCreateChildLitten;

  List<NotificationEvent> get pendingNotifications => List.unmodifiable(_pendingNotifications);
  List<NotificationEvent> get firedNotifications => List.unmodifiable(_firedNotifications);
  bool get isRunning => _isRunning;

  void startNotificationChecker() {
    debugPrint('🚀 알림 체커 시작 - 30초마다 자동 체크');
    _isRunning = true;
    _failureCount = 0;

    // 기존 타이머 정리
    _timer?.cancel();
    _healthCheckTimer?.cancel();

    // 30초마다 알림 체크 (백그라운드에서도 계속 작동)
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      debugPrint('⏰ Timer 실행: ${DateTime.now()}');
      _safeCheckNotifications();
    });

    // 5분마다 헬스 체크 타이머
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performHealthCheck();
    });

    // 즉시 한 번 체크
    _safeCheckNotifications();
    _lastHealthCheckTime = DateTime.now();
  }

  void stopNotificationChecker() {
    debugPrint('🛑 알림 체커 중지');
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// 앱이 백그라운드로 갈 때 호출
  void onAppPaused() {
    debugPrint('⏸️ 앱 일시정지 - 백그라운드로 전환');
    _isInBackground = true;
    _lastCheckTime = DateTime.now();
    // Timer는 계속 실행되도록 유지
  }

  /// 앱이 포그라운드로 돌아올 때 호출
  void onAppResumed() {
    debugPrint('▶️ 앱 재개 - 포그라운드로 전환');
    _isInBackground = false;

    // 백그라운드에 있는 동안 놓친 알림이 있는지 체크
    if (_lastCheckTime != null) {
      final missedDuration = DateTime.now().difference(_lastCheckTime!);
      debugPrint('⏱️ 백그라운드 기간: ${missedDuration.inSeconds}초');

      if (missedDuration.inSeconds > 30) {
        debugPrint('🔍 놓친 알림 체크 시작');
        _checkNotifications();
      }
    }

    _lastCheckTime = DateTime.now();
  }

  /// 안전한 알림 체크 (오류 처리 포함)
  Future<void> _safeCheckNotifications() async {
    try {
      await _checkNotifications();
      _failureCount = 0; // 성공 시 실패 카운트 리셋
    } catch (e) {
      _failureCount++;
      debugPrint('❌ 알림 체크 실패 (${_failureCount}회): $e');

      // 3번 연속 실패 시 서비스 재시작
      if (_failureCount >= 3) {
        debugPrint('🔄 알림 서비스 재시작 시도');
        await _restartService();
      }
    }
  }

  /// 서비스 상태 확인 및 복구
  Future<void> _performHealthCheck() async {
    debugPrint('🏥 알림 서비스 헬스 체크');

    final now = DateTime.now();

    // 타이머가 멈췄는지 확인
    if (_timer == null || !_timer!.isActive) {
      debugPrint('⚠️ 알림 타이머가 멈췄 - 재시작');
      await _restartService();
      return;
    }

    // 마지막 체크 시간 확인 (10분 이상 지났으면 문제)
    if (_lastCheckTime != null) {
      final timeSinceLastCheck = now.difference(_lastCheckTime!);
      if (timeSinceLastCheck.inMinutes > 10) {
        debugPrint('⚠️ 알림 체크가 10분 이상 안 됨 - 재시작');
        await _restartService();
        return;
      }
    }

    _lastHealthCheckTime = now;
    debugPrint('✅ 알림 서비스 정상 작동 중');
  }

  /// 서비스 재시작
  Future<void> _restartService() async {
    try {
      debugPrint('🔄 알림 서비스 재시작 시작');

      // 기존 타이머 정리
      stopNotificationChecker();

      // 약간 대기 후 재시작
      await Future.delayed(const Duration(seconds: 2));

      // 서비스 재시작
      startNotificationChecker();

      debugPrint('✅ 알림 서비스 재시작 완료');
    } catch (e) {
      debugPrint('❌ 알림 서비스 재시작 실패: $e');
    }
  }

  Future<void> _checkNotifications() async {
    // 오래된 Child 리튼 정리
    await RecurringNotificationService().cleanupOldChildLittens();

    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _lastCheckTime = now; // 체크 시간 업데이트

    // 현재 시간과 정확히 일치하거나 1분 이내에 지난 알림을 찾습니다
    final checkStartTime = currentMinute.subtract(const Duration(minutes: 1));
    final checkEndTime = currentMinute.add(const Duration(minutes: 1));

    // Parent 리튼의 알림만 체크
    final notifications = _pendingNotifications.where((notification) {
      // Parent 리튼인지 확인
      final litten = _littenMap[notification.littenId];
      if (litten != null && litten.isChildLitten) {
        return false; // Child 리튼은 체크하지 않음
      }

      final triggerMinute = DateTime(
        notification.triggerTime.year,
        notification.triggerTime.month,
        notification.triggerTime.day,
        notification.triggerTime.hour,
        notification.triggerTime.minute,
      );

      return triggerMinute.isAfter(checkStartTime) &&
             triggerMinute.isBefore(checkEndTime);
    }).toList();

    // 디버그 정보 출력
    final bgStatus = _isInBackground ? '🌙 백그라운드' : '☀️ 포그라운드';
    debugPrint('🕒 알림 체크: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)} ($bgStatus)');
    debugPrint('   현재 분: ${DateFormat('yyyy-MM-dd HH:mm').format(currentMinute)}');
    debugPrint('   체크 범위: ${DateFormat('HH:mm').format(checkStartTime)} ~ ${DateFormat('HH:mm').format(checkEndTime)}');
    debugPrint('   대기 중인 알림: ${_pendingNotifications.length}개');
    debugPrint('   이번에 발생할 알림: ${notifications.length}개');

    if (notifications.isNotEmpty) {
      for (final notification in notifications) {
        debugPrint('   - ${notification.littenTitle}: ${DateFormat('yyyy-MM-dd HH:mm').format(notification.triggerTime)}');
      }
    }

    for (final notification in notifications) {
      await _fireNotification(notification);
    }
  }

  Future<void> _fireNotification(NotificationEvent notification) async {
    if (!_firedNotifications.any((fired) =>
        fired.littenId == notification.littenId &&
        fired.rule.frequency == notification.rule.frequency &&
        fired.rule.timing == notification.rule.timing &&
        fired.triggerTime.isAtSameMomentAs(notification.triggerTime))) {

      _firedNotifications.add(notification);
      _pendingNotifications.remove(notification);

      // 실제 시스템 알림 표시
      await _backgroundService.showNotification(
        title: '리튼 알림',
        body: notification.message,
        littenId: notification.littenId,
      );

      debugPrint('🔔 알림: ${notification.message}');
      debugPrint('   시간: ${notification.timingDescription}');

      // 반복 알림(매일, 매주, 매월, 매년)이고 정시 알림인 경우 자식 리튼 생성
      final isRecurringNotification = [
        NotificationFrequency.daily,
        NotificationFrequency.weekly,
        NotificationFrequency.monthly,
        NotificationFrequency.yearly,
      ].contains(notification.rule.frequency);

      final isOnTime = notification.rule.timing == NotificationTiming.onTime;

      if (isRecurringNotification && isOnTime && onCreateChildLitten != null) {
        final parentLitten = _littenMap[notification.littenId];
        if (parentLitten != null) {
          debugPrint('🏗️ 반복 알림 발생: ${notification.rule.frequency.label} - 자식 리튼 생성 요청');
          onCreateChildLitten!(parentLitten, notification);
        }
      }

      notifyListeners();
    }
  }

  Future<void> scheduleNotifications(List<Litten> littens) async {
    try {
      debugPrint('🔔 알림 스케줄링 시작: ${littens.length}개 리튼');

      // 서비스가 실행 중이 아니면 시작
      if (!_isRunning) {
        debugPrint('🔄 알림 서비스가 중지됨 - 재시작');
        startNotificationChecker();
      }

      _pendingNotifications.clear();
      _littenMap.clear();
      final now = DateTime.now();
      int totalScheduled = 0;
      int totalNativeScheduled = 0;

      // Parent 리튼만 필터링
      final parentLittens = littens.where((l) => !l.isChildLitten).toList();
      debugPrint('👪 Parent 리튼: ${parentLittens.length}개');

      // Child 리튼 생성은 비동기로 처리하여 알림 서비스가 블록되지 않도록 함
      List<Litten> todayChildren = [];
      List<Litten> tomorrowChildren = [];

      try {
        // 오늘/내일에 대한 Child 리튼 자동 생성 (시간 제한 설정)
        final recurringService = RecurringNotificationService();
        todayChildren = await recurringService.generateChildLittensForRecurring(
          parentLittens: parentLittens,
          targetDate: now,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⚠️ Child 리튼 생성 타임아웃 (오늘)');
            return [];
          },
        );

        tomorrowChildren = await recurringService.generateChildLittensForRecurring(
          parentLittens: parentLittens,
          targetDate: now.add(const Duration(days: 1)),
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⚠️ Child 리튼 생성 타임아웃 (내일)');
            return [];
          },
        );
      } catch (e) {
        debugPrint('❌ Child 리튼 생성 중 오류 (무시): $e');
      }

      debugPrint('🔄 생성된 Child 리튼: 오늘 ${todayChildren.length}개, 내일 ${tomorrowChildren.length}개');

      // 모든 리튼 합치기 (Parent + 기존 Child + 새 Child)
      final allLittens = [...parentLittens];
      allLittens.addAll(littens.where((l) => l.isChildLitten));
      allLittens.addAll(todayChildren);
      allLittens.addAll(tomorrowChildren);

      // 리튼 맵 업데이트
      for (final litten in allLittens) {
        _littenMap[litten.id] = litten;
      }

      // 기존 OS 네이티브 알림 모두 취소
      await _backgroundService.cancelAllNotifications();

      // Parent 리튼과 오늘/내일의 Child 리튼만 알림 체크
      final littensToCheck = allLittens.where((litten) {
        if (!litten.isChildLitten) return true; // Parent는 항상 체크
        if (litten.schedule == null) return false;

        // Child는 오늘/내일 것만 체크
        final scheduleDate = litten.schedule!.date;
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final littenDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);

        return littenDay.isAtSameMomentAs(today) || littenDay.isAtSameMomentAs(tomorrow);
      }).toList();

      debugPrint('🔍 알림 체크 대상: ${littensToCheck.length}개 리튼');

      for (final litten in littensToCheck) {
        if (litten.schedule == null) continue;

        final schedule = litten.schedule!;
        debugPrint('📋 "${litten.title}" 알림 설정 중: ${schedule.notificationRules.length}개 규칙');

        for (final rule in schedule.notificationRules) {
          if (!rule.isEnabled) {
            debugPrint('⏸️ 비활성화된 알림 규칙 건너뛰기: ${rule.frequency.label} ${rule.timing.label}');
            continue;
          }

          try {
            final notifications = _calculateNotificationTimes(litten, schedule, rule, now);
            _pendingNotifications.addAll(notifications);
            totalScheduled += notifications.length;

            // OS 네이티브 예약 알림도 함께 등록 (향후 30일간)
            // iOS/Android가 백그라운드에서도 알림을 발생시킬 수 있도록 OS에 등록
            final nativeNotifications = notifications.where((n) =>
              n.triggerTime.difference(now).inDays < 30
            ).toList();

            for (int i = 0; i < nativeNotifications.length; i++) {
              final notification = nativeNotifications[i];
              await _backgroundService.scheduleNotification(
                id: litten.id.hashCode + i,
                title: '리튼 알림',
                body: notification.message,
                scheduledDate: notification.triggerTime,
                littenId: litten.id,
              );
              totalNativeScheduled++;
            }

            debugPrint('✅ 알림 추가: ${notifications.length}개 (${rule.frequency.label} ${rule.timing.label})');
            debugPrint('   - OS 네이티브 알림: ${nativeNotifications.length}개 등록');
          } catch (e) {
            debugPrint('❌ 알림 계산 실패: "${litten.title}" - $e');
          }
        }
      }

      debugPrint('🔔 알림 스케줄링 완료: 총 $totalScheduled개 알림 예약 (OS 네이티브: $totalNativeScheduled개)');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 알림 스케줄링 에러: $e');
    }
  }

  List<NotificationEvent> _calculateNotificationTimes(
    Litten litten,
    LittenSchedule schedule,
    NotificationRule rule,
    DateTime now,
  ) {
    final List<NotificationEvent> notifications = [];
    final scheduleDateTime = DateTime(
      schedule.date.year,
      schedule.date.month,
      schedule.date.day,
      schedule.startTime.hour,
      schedule.startTime.minute,
    );

    // 향후 30일간의 알림을 계산
    final endDate = now.add(const Duration(days: 30));

    DateTime? nextTrigger = _getNextTriggerTime(scheduleDateTime, rule, now);

    while (nextTrigger != null && nextTrigger.isBefore(endDate)) {
      // 이미 지난 시간은 제외
      if (nextTrigger.isAfter(now)) {
        notifications.add(NotificationEvent(
          littenId: litten.id,
          littenTitle: litten.title,
          schedule: schedule,
          rule: rule,
          triggerTime: nextTrigger,
        ));
      }

      // 다음 알림 시간 계산
      nextTrigger = _getNextOccurrence(nextTrigger, rule.frequency);
    }

    return notifications;
  }

  DateTime? _getNextTriggerTime(DateTime scheduleTime, NotificationRule rule, DateTime now) {
    final baseTime = scheduleTime.add(Duration(minutes: rule.timing.minutesOffset));

    switch (rule.frequency) {
      case NotificationFrequency.onDay:
        return baseTime.isAfter(now) ? baseTime : null;

      case NotificationFrequency.oneDayBefore:
        final oneDayBefore = baseTime.subtract(const Duration(days: 1));
        return oneDayBefore.isAfter(now) ? oneDayBefore : null;

      case NotificationFrequency.daily:
        DateTime candidate = baseTime;
        while (candidate.isBefore(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;

      case NotificationFrequency.weekly:
        DateTime candidate = baseTime;
        while (candidate.isBefore(now)) {
          candidate = candidate.add(const Duration(days: 7));
        }
        return candidate;

      case NotificationFrequency.monthly:
        DateTime candidate = baseTime;
        while (candidate.isBefore(now)) {
          candidate = DateTime(
            candidate.month == 12 ? candidate.year + 1 : candidate.year,
            candidate.month == 12 ? 1 : candidate.month + 1,
            candidate.day,
            candidate.hour,
            candidate.minute,
          );
        }
        return candidate;

      case NotificationFrequency.yearly:
        DateTime candidate = baseTime;
        while (candidate.isBefore(now)) {
          candidate = DateTime(
            candidate.year + 1,
            candidate.month,
            candidate.day,
            candidate.hour,
            candidate.minute,
          );
        }
        return candidate;
    }
  }

  DateTime? _getNextOccurrence(DateTime current, NotificationFrequency frequency) {
    switch (frequency) {
      case NotificationFrequency.onDay:
      case NotificationFrequency.oneDayBefore:
        return null; // 일회성 알림

      case NotificationFrequency.daily:
        return current.add(const Duration(days: 1));

      case NotificationFrequency.weekly:
        return current.add(const Duration(days: 7));

      case NotificationFrequency.monthly:
        return DateTime(
          current.month == 12 ? current.year + 1 : current.year,
          current.month == 12 ? 1 : current.month + 1,
          current.day,
          current.hour,
          current.minute,
        );

      case NotificationFrequency.yearly:
        return DateTime(
          current.year + 1,
          current.month,
          current.day,
          current.hour,
          current.minute,
        );
    }
  }

  void clearAllNotifications() {
    _pendingNotifications.clear();
    _firedNotifications.clear();
    notifyListeners();
  }

  // 수동으로 알림 체크 (디버깅용)
  Future<void> manualCheckNotifications() async {
    debugPrint('🔍 수동 알림 체크 실행');
    await _checkNotifications();
  }

  // 테스트용: 즉시 발생할 알림 생성
  void createTestNotification(String title) {
    final now = DateTime.now();
    // 30초 후에 발생하도록 설정
    final triggerTime = now.add(const Duration(seconds: 30));
    final testNotification = NotificationEvent(
      littenId: 'test_${now.millisecondsSinceEpoch}',
      littenTitle: title,
      schedule: LittenSchedule(
        date: now,
        startTime: TimeOfDay.fromDateTime(triggerTime),
        endTime: TimeOfDay.fromDateTime(triggerTime.add(const Duration(minutes: 1))),
      ),
      rule: NotificationRule(
        frequency: NotificationFrequency.onDay,
        timing: NotificationTiming.onTime,
        isEnabled: true,
      ),
      triggerTime: triggerTime,
    );

    _pendingNotifications.add(testNotification);
    debugPrint('🧪 테스트 알림 생성: ${DateFormat('HH:mm:ss').format(triggerTime)}에 발생 예정');
    notifyListeners();
  }

  // 즉시 발생하는 테스트 알림
  void createImmediateTestNotification(String title) {
    final now = DateTime.now();
    final testNotification = NotificationEvent(
      littenId: 'immediate_test_${now.millisecondsSinceEpoch}',
      littenTitle: title,
      schedule: LittenSchedule(
        date: now,
        startTime: TimeOfDay.fromDateTime(now),
        endTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
      ),
      rule: NotificationRule(
        frequency: NotificationFrequency.onDay,
        timing: NotificationTiming.onTime,
        isEnabled: true,
      ),
      triggerTime: now,
    );

    _firedNotifications.add(testNotification);
    debugPrint('🧪 즉시 테스트 알림 발생: $title');
    notifyListeners();
  }

  // 매일 반복 알림 테스트 (자식 리튼 생성용)
  Future<void> createDailyRecurringTestNotification(String littenId, String title) async {
    final now = DateTime.now();
    final testNotification = NotificationEvent(
      littenId: littenId,
      littenTitle: title,
      schedule: LittenSchedule(
        date: now,
        startTime: TimeOfDay.fromDateTime(now),
        endTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
      ),
      rule: NotificationRule(
        frequency: NotificationFrequency.daily, // 매일 반복
        timing: NotificationTiming.onTime, // 정시 알림
        isEnabled: true,
      ),
      triggerTime: now,
    );

    debugPrint('🧪 매일 반복 테스트 알림 발생: $title (리튼 ID: $littenId)');
    await _fireNotification(testNotification); // 직접 발생시켜서 자식 리튼 생성 테스트
  }

  void dismissNotification(NotificationEvent notification) {
    _firedNotifications.remove(notification);
    notifyListeners();
  }

  @override
  void dispose() {
    stopNotificationChecker();
    _pendingNotifications.clear();
    _firedNotifications.clear();
    _littenMap.clear();
    super.dispose();
  }
}