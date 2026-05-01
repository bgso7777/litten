import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/litten.dart';
import '../models/stored_notification.dart';
import 'background_notification_service.dart';
import 'notification_orchestrator_service.dart';

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

  // 알림 오케스트레이터 서비스 (저장소 기반)
  final NotificationOrchestratorService _orchestrator = NotificationOrchestratorService();

  // 알림 발생 시 리튼 업데이트를 위한 콜백
  Function(String littenId)? onNotificationFired;

  List<NotificationEvent> get pendingNotifications => List.unmodifiable(_pendingNotifications);
  List<NotificationEvent> get firedNotifications => List.unmodifiable(_firedNotifications);
  bool get isRunning => _isRunning;

  // 오늘 날짜 기준 미해제 스케줄 뱃지 수 (HomeScreen._loadNotificationDates에서 업데이트)
  int _scheduleBadgeCount = 0;
  int get scheduleBadgeCount => _scheduleBadgeCount;
  void updateScheduleBadgeCount(int count) {
    if (_scheduleBadgeCount == count) return;
    _scheduleBadgeCount = count;
    notifyListeners();
  }

  void startNotificationChecker() {
    debugPrint('🚀 알림 체커 시작 - 30초마다 자동 체크');
    _isRunning = true;
    _failureCount = 0;

    // 기존 타이머 완전히 정리
    _timer?.cancel();
    _timer = null;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // ⭐ 타이머 시작 시 반복 알림 1년치 유지 로직 실행
    _maintainYearlyNotificationsOnStart();

    // ⭐ 앱 시작 시 놓친 알림 체크 (재시작 시 확인하지 않은 알림 표시)
    _checkMissedNotificationsOnStart();

    // 30초마다 알림 체크 (백그라운드에서도 계속 작동)
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // ⭐ 타이머가 여전히 활성화되어 있는지 확인
      if (!timer.isActive) {
        debugPrint('⚠️ 타이머가 비활성화됨 - 재시작 시도');
        timer.cancel();
        startNotificationChecker();
        return;
      }

      debugPrint('⏰ Timer 실행: ${DateTime.now()}');
      _safeCheckNotifications();
    });

    // 2분마다 헬스 체크 타이머 (5분 → 2분으로 단축하여 더 빠른 감지)
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      // ⭐ 헬스 체크 타이머도 상태 확인
      if (!timer.isActive) {
        debugPrint('⚠️ 헬스 체크 타이머가 비활성화됨');
        timer.cancel();
        _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (t) {
          _performHealthCheck();
        });
        return;
      }

      _performHealthCheck();
    });

    // ⭐ 타이머가 제대로 시작되었는지 확인
    if (_timer != null && _timer!.isActive) {
      debugPrint('✅ 알림 타이머 시작 확인됨');
    } else {
      debugPrint('❌ 알림 타이머 시작 실패 - 재시도');
      Future.delayed(const Duration(milliseconds: 100), () {
        startNotificationChecker();
      });
      return;
    }

    // 즉시 한 번 체크
    _safeCheckNotifications();
    _lastHealthCheckTime = DateTime.now();
    _lastCheckTime = DateTime.now();
  }

  /// 타이머 시작 시 반복 알림 1년치 유지
  Future<void> _maintainYearlyNotificationsOnStart() async {
    try {
      debugPrint('🔄 타이머 시작 시 1년치 알림 유지 로직 실행');
      final littens = _littenMap.values.toList();
      await _orchestrator.maintainYearlyNotifications(littens);
    } catch (e) {
      debugPrint('❌ 1년치 알림 유지 에러: $e');
    }
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
    
    // ⭐ 백그라운드 전환 전 타이머 상태 확인
    if (_timer == null || !_timer!.isActive) {
      debugPrint('⚠️ 백그라운드 전환 시 타이머가 비활성화됨 - 재시작');
      // 백그라운드에서도 타이머는 유지되어야 하므로 재시작
      startNotificationChecker();
    }
    
    // Timer는 계속 실행되도록 유지 (하지만 시스템이 멈출 수 있으므로 OS 알림에 의존)
    debugPrint('📱 백그라운드 전환 - OS 네이티브 알림에 의존');
  }

  /// 앱이 포그라운드로 돌아올 때 호출
  Future<void> onAppResumed() async {
    debugPrint('▶️ 앱 재개 - 포그라운드로 전환');
    _isInBackground = false;

    // ⭐ 타이머 상태 확인 및 재시작 (가장 중요!)
    if (_timer == null || !_timer!.isActive) {
      debugPrint('⚠️ 타이머가 비활성화됨 - 즉시 재시작');
      startNotificationChecker();
    } else {
      debugPrint('✅ 타이머 정상 작동 중');
    }

    // 헬스 체크 타이머도 확인
    if (_healthCheckTimer == null || !_healthCheckTimer!.isActive) {
      debugPrint('⚠️ 헬스 체크 타이머가 비활성화됨 - 재시작');
      _healthCheckTimer?.cancel();
      _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
        _performHealthCheck();
      });
    }

    // ⭐ 저장소 기반: 놓친 알림 체크 및 표시
    await _checkMissedNotificationsFromStorage();

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
    _lastHealthCheckTime = DateTime.now();
  }

  /// 앱 시작 시 놓친 알림 체크 (재시작 시에도 확인하지 않은 알림 표시)
  Future<void> _checkMissedNotificationsOnStart() async {
    try {
      debugPrint('🔍 앱 시작 시 놓친 알림 체크');
      final missedNotifications = await _orchestrator.checkMissedNotifications();

      if (missedNotifications.isEmpty) {
        debugPrint('   ℹ️ 놓친 알림 없음');
        return;
      }

      debugPrint('   ⚠️ ${missedNotifications.length}개 놓친 알림 발견');

      // 놓친 알림들을 firedNotifications에 추가하여 배지 표시
      for (final stored in missedNotifications) {
        // StoredNotification을 NotificationEvent로 변환
        final litten = _littenMap[stored.littenId];
        if (litten == null) continue;

        final event = NotificationEvent(
          littenId: stored.littenId,
          littenTitle: litten.title,
          schedule: litten.schedule!,
          rule: stored.rule,
          triggerTime: stored.triggerTime,
        );

        // 중복 체크 후 추가
        if (!_firedNotifications.any((e) =>
            e.littenId == event.littenId &&
            e.triggerTime.isAtSameMomentAs(event.triggerTime))) {
          _firedNotifications.add(event);
          debugPrint('      🔔 놓친 알림 추가: ${litten.title} - ${stored.triggerTime}');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('   ❌ 놓친 알림 체크 에러: $e');
    }
  }

  /// 저장소에서 놓친 알림 체크 (백그라운드에서 포그라운드로 전환 시)
  Future<void> _checkMissedNotificationsFromStorage() async {
    try {
      debugPrint('📂 저장소에서 놓친 알림 체크');
      final missedNotifications = await _orchestrator.checkMissedNotifications();

      if (missedNotifications.isEmpty) {
        debugPrint('   ℹ️ 놓친 알림 없음');
        return;
      }

      debugPrint('   ⚠️ ${missedNotifications.length}개 놓친 알림 발견');

      // 놓친 알림들을 firedNotifications에 추가하여 배지 표시
      for (final stored in missedNotifications) {
        // StoredNotification을 NotificationEvent로 변환
        final litten = _littenMap[stored.littenId];
        if (litten == null) continue;

        final event = NotificationEvent(
          littenId: stored.littenId,
          littenTitle: litten.title,
          schedule: litten.schedule!,
          rule: stored.rule,
          triggerTime: stored.triggerTime,
        );

        // 중복 체크 후 추가
        if (!_firedNotifications.any((e) =>
            e.littenId == event.littenId &&
            e.triggerTime.isAtSameMomentAs(event.triggerTime))) {
          _firedNotifications.add(event);
          debugPrint('      🔔 놓친 알림 추가: ${litten.title} - ${stored.triggerTime}');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('   ❌ 놓친 알림 체크 에러: $e');
    }
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

    // 헬스 체크 타이머도 확인
    if (_healthCheckTimer == null || !_healthCheckTimer!.isActive) {
      debugPrint('⚠️ 헬스 체크 타이머가 멈췄 - 재시작');
      _healthCheckTimer?.cancel();
      _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
        _performHealthCheck();
      });
    }

    // 마지막 체크 시간 확인 (5분 이상 지났으면 문제, 10분 → 5분으로 단축)
    if (_lastCheckTime != null) {
      final timeSinceLastCheck = now.difference(_lastCheckTime!);
      if (timeSinceLastCheck.inMinutes > 5) {
        debugPrint('⚠️ 알림 체크가 5분 이상 안 됨 (${timeSinceLastCheck.inMinutes}분 경과) - 재시작');
        await _restartService();
        return;
      }
    } else {
      // _lastCheckTime이 null이면 즉시 체크 실행
      debugPrint('⚠️ 마지막 체크 시간이 없음 - 즉시 체크 실행');
      await _safeCheckNotifications();
    }

    _lastHealthCheckTime = now;
    debugPrint('✅ 알림 서비스 정상 작동 중 (타이머: ${_timer!.isActive ? "활성" : "비활성"}, 마지막 체크: ${_lastCheckTime != null ? "${now.difference(_lastCheckTime!).inSeconds}초 전" : "없음"})');
  }

  /// 서비스 재시작
  Future<void> _restartService() async {
    try {
      debugPrint('🔄 알림 서비스 재시작 시작');

      // 기존 타이머 완전히 정리
      _timer?.cancel();
      _timer = null;
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;

      // 약간 대기 후 재시작 (메모리 정리 시간 확보)
      await Future.delayed(const Duration(milliseconds: 500));

      // 서비스 재시작
      startNotificationChecker();

      // 재시작 후 즉시 한 번 체크하여 상태 확인
      await Future.delayed(const Duration(milliseconds: 500));
      await _safeCheckNotifications();

      debugPrint('✅ 알림 서비스 재시작 완료');
    } catch (e) {
      debugPrint('❌ 알림 서비스 재시작 실패: $e');
      // 재시작 실패 시 재시도
      _failureCount++;
      if (_failureCount < 5) {
        debugPrint('🔄 재시작 재시도 예정 (${_failureCount}/5)');
        await Future.delayed(const Duration(seconds: 3));
        await _restartService();
      } else {
        debugPrint('🔴 알림 서비스 재시작 최종 실패 - 수동 재시작 필요');
        _isRunning = false;
      }
    }
  }

  Future<void> _checkNotifications() async {
    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _lastCheckTime = now; // 체크 시간 업데이트

    // ⭐ 저장소에서 모든 알림 로드
    final storedNotifications = await _orchestrator.getAllNotifications();

    // ⭐ 디버그: 저장소의 모든 알림 출력
    debugPrint('   📋 저장소 알림 상세:');
    for (final stored in storedNotifications) {
      final litten = _littenMap[stored.littenId];
      debugPrint('      - ${litten?.title ?? "unknown"}: ${DateFormat('yyyy-MM-dd HH:mm').format(stored.triggerTime)} (acknowledged: ${stored.isAcknowledged})');
    }

    // 현재 시간과 정확히 일치하거나 1분 이내에 지난 알림을 찾습니다
    final checkStartTime = currentMinute.subtract(const Duration(minutes: 1));
    final checkEndTime = currentMinute.add(const Duration(minutes: 1));

    // 저장소에서 로드한 알림을 NotificationEvent로 변환 및 필터링
    final List<NotificationEvent> notifications = [];

    for (final stored in storedNotifications) {
      // 이미 확인된 알림은 건너뛰기
      if (stored.isAcknowledged) continue;

      // 리튼 정보 가져오기
      final litten = _littenMap[stored.littenId];
      if (litten == null) continue;

      final triggerMinute = DateTime(
        stored.triggerTime.year,
        stored.triggerTime.month,
        stored.triggerTime.day,
        stored.triggerTime.hour,
        stored.triggerTime.minute,
      );

      // ⭐ 시간 범위 내에 있는지 확인 (경계값 포함)
      final isInTimeRange = (triggerMinute.isAfter(checkStartTime) || triggerMinute.isAtSameMomentAs(checkStartTime)) &&
                           (triggerMinute.isBefore(checkEndTime) || triggerMinute.isAtSameMomentAs(checkEndTime));

      if (!isInTimeRange) continue;

      // ⭐ 추가 확인: 정확히 현재 분과 일치하는지 확인
      final isExactMatch = triggerMinute.isAtSameMomentAs(currentMinute);
      if (!isExactMatch) {
        // 정확히 일치하지 않으면 1분 이내에 지난 알림인지 확인
        final timeDiff = now.difference(stored.triggerTime);
        if (timeDiff.inMinutes > 1 || timeDiff.isNegative) continue;
      }

      // 알림 발생 시간 범위 검증 (notificationStartTime ~ notificationEndTime)
      if (litten.schedule != null) {
        final schedule = litten.schedule!;
        if (schedule.notificationStartTime != null || schedule.notificationEndTime != null) {
          final triggerTimeOfDay = TimeOfDay.fromDateTime(stored.triggerTime);
          final triggerMinutes = triggerTimeOfDay.hour * 60 + triggerTimeOfDay.minute;

          // 시작 시간 체크
          if (schedule.notificationStartTime != null) {
            final startMinutes = schedule.notificationStartTime!.hour * 60 + schedule.notificationStartTime!.minute;
            if (triggerMinutes < startMinutes) continue;
          }

          // 종료 시간 체크
          if (schedule.notificationEndTime != null) {
            final endMinutes = schedule.notificationEndTime!.hour * 60 + schedule.notificationEndTime!.minute;
            if (triggerMinutes > endMinutes) continue;
          }
        }
      }

      // StoredNotification을 NotificationEvent로 변환
      final event = NotificationEvent(
        littenId: stored.littenId,
        littenTitle: litten.title,
        schedule: litten.schedule!,
        rule: stored.rule,
        triggerTime: stored.triggerTime,
      );

      notifications.add(event);
    }

    // 디버그 정보 출력
    final bgStatus = _isInBackground ? '🌙 백그라운드' : '☀️ 포그라운드';
    debugPrint('🕒 알림 체크: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)} ($bgStatus)');
    debugPrint('   현재 분: ${DateFormat('yyyy-MM-dd HH:mm').format(currentMinute)}');
    debugPrint('   체크 범위: ${DateFormat('HH:mm').format(checkStartTime)} ~ ${DateFormat('HH:mm').format(checkEndTime)}');
    debugPrint('   저장소 알림: ${storedNotifications.length}개');
    debugPrint('   이번에 발생할 알림: ${notifications.length}개');

    if (notifications.isNotEmpty) {
      for (final notification in notifications) {
        debugPrint('   ✅ 발생: ${notification.littenTitle}: ${DateFormat('yyyy-MM-dd HH:mm').format(notification.triggerTime)} (${notification.rule.timing.label})');
      }
    }

    for (final notification in notifications) {
      await _fireNotification(notification);
    }
  }

  Future<void> _fireNotification(NotificationEvent notification) async {
    // 중복 체크: 이미 발생한 알림인지 확인
    final isDuplicate = _firedNotifications.any((fired) =>
        fired.littenId == notification.littenId &&
        fired.triggerTime.isAtSameMomentAs(notification.triggerTime));

    if (isDuplicate) {
      debugPrint('   ⏭️ 중복 알림 스킵: ${notification.littenTitle} - ${notification.triggerTime}');
      return;
    }

    _firedNotifications.add(notification);
    _pendingNotifications.remove(notification);

    // ⭐ 저장소에서 알림을 acknowledged로 표시 (연속 발생 방지)
    final notificationId = StoredNotification.generateId(
      notification.littenId,
      notification.triggerTime,
    );
    await _orchestrator.acknowledgeNotification(notificationId);
    debugPrint('   ✅ 알림 acknowledged 처리: $notificationId');

    // 실제 시스템 알림 표시
    await _backgroundService.showNotification(
      title: '리튼 알림',
      body: notification.message,
      littenId: notification.littenId,
    );

    debugPrint('🔔 알림 발생: ${notification.message}');
    debugPrint('   시간: ${notification.timingDescription}');

    // 알림 발생 시 리튼의 updatedAt을 업데이트하여 최상위로 올림
    if (onNotificationFired != null) {
      debugPrint('📌 리튼을 최상위로 이동: ${notification.littenTitle}');
      onNotificationFired!(notification.littenId);
    }

    notifyListeners();
  }

  Future<void> scheduleNotifications(List<Litten> littens) async {
    try {
      debugPrint('🔔 알림 스케줄링 시작: ${littens.length}개 리튼');

      _pendingNotifications.clear(); // 메모리 기반 리스트는 더 이상 사용하지 않음 (하위 호환성을 위해 유지)
      _littenMap.clear();

      // ⭐ 리튼 맵을 먼저 업데이트 (놓친 알림 체크에서 사용하기 위해)
      for (final litten in littens) {
        _littenMap[litten.id] = litten;
      }

      // 서비스가 실행 중이 아니면 시작 (리튼 맵 업데이트 후에 시작)
      if (!_isRunning) {
        debugPrint('🔄 알림 서비스가 중지됨 - 재시작');
        startNotificationChecker();
      }

      // ⭐ 저장소 기반: 모든 리튼의 알림을 저장소에 저장 (1회성 1개, 반복 1년치)
      final success = await _orchestrator.scheduleNotificationsForLittens(littens);

      if (success) {
        debugPrint('✅ 알림 스케줄링 완료 (저장소 기반)');
        // 스케줄링 직후 즉시 체크: 방금 생성된 알림이 현재 시간과 일치하면 즉시 발생
        await _safeCheckNotifications();
      } else {
        debugPrint('⚠️ 알림 스케줄링 일부 실패');
      }

      // OS 네이티브 알림도 등록 (향후 30일간)
      await _scheduleNativeNotifications(littens);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ 알림 스케줄링 에러: $e');
    }
  }

  /// OS 네이티브 알림 등록 (향후 30일간)
  Future<void> _scheduleNativeNotifications(List<Litten> littens) async {
    try {
      debugPrint('📱 OS 네이티브 알림 등록 시작');

      // 기존 OS 네이티브 알림 모두 취소
      await _backgroundService.cancelAllNotifications();

      final now = DateTime.now();
      final thirtyDaysLater = now.add(const Duration(days: 30));
      int totalNativeScheduled = 0;

      // 저장소에서 모든 알림 가져오기
      final allStoredNotifications = await _orchestrator.getAllNotifications();

      // 향후 30일 이내의 알림만 OS에 등록
      final upcomingNotifications = allStoredNotifications
          .where((n) => n.triggerTime.isAfter(now) && n.triggerTime.isBefore(thirtyDaysLater))
          .toList();

      debugPrint('   ℹ️ 향후 30일 이내 알림: ${upcomingNotifications.length}개');

      for (int i = 0; i < upcomingNotifications.length; i++) {
        final stored = upcomingNotifications[i];
        final litten = _littenMap[stored.littenId];
        if (litten == null) continue;

        final event = NotificationEvent(
          littenId: stored.littenId,
          littenTitle: litten.title,
          schedule: litten.schedule!,
          rule: stored.rule,
          triggerTime: stored.triggerTime,
        );

        await _backgroundService.scheduleNotification(
          id: stored.id.hashCode,
          title: '리튼 알림',
          body: event.message,
          scheduledDate: stored.triggerTime,
          littenId: stored.littenId,
        );
        totalNativeScheduled++;
      }

      debugPrint('   ✅ OS 네이티브 알림 등록 완료: $totalNativeScheduled개');
    } catch (e) {
      debugPrint('   ❌ OS 네이티브 알림 등록 실패: $e');
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

  Future<void> dismissNotification(NotificationEvent notification) async {
    _firedNotifications.remove(notification);

    // ⭐ 저장소에서도 삭제 (알림 확인 처리)
    final notificationId = StoredNotification.generateId(
      notification.littenId,
      notification.triggerTime,
    );
    await _orchestrator.acknowledgeNotification(notificationId);

    notifyListeners();
  }

  /// 외부에서 뱃지 갱신이 필요할 때 리스너에게 알림
  void notifyBadgeChange() => notifyListeners();

  @override
  void dispose() {
    stopNotificationChecker();
    _pendingNotifications.clear();
    _firedNotifications.clear();
    _littenMap.clear();
    super.dispose();
  }
}