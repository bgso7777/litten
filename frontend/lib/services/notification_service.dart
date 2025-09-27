import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/litten.dart';

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
  final List<NotificationEvent> _pendingNotifications = [];
  final List<NotificationEvent> _firedNotifications = [];
  final Map<String, Litten> _littenMap = {}; // 리튼 ID -> 리튼 객체 매핑

  // 반복 알림 발생 시 자식 리튼 생성을 위한 콜백
  Function(Litten parentLitten, NotificationEvent notification)? onCreateChildLitten;

  List<NotificationEvent> get pendingNotifications => List.unmodifiable(_pendingNotifications);
  List<NotificationEvent> get firedNotifications => List.unmodifiable(_firedNotifications);

  void startNotificationChecker() {
    // 30초마다 알림 체크 (웹에서 더 자주 체크)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkNotifications();
    });

    // 즉시 한 번 체크
    _checkNotifications();
  }

  void stopNotificationChecker() {
    _timer?.cancel();
    _timer = null;
  }

  void _checkNotifications() {
    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    // 현재 시간과 정확히 일치하거나 1분 이내에 지난 알림을 찾습니다
    final checkStartTime = currentMinute.subtract(const Duration(minutes: 1));
    final checkEndTime = currentMinute.add(const Duration(minutes: 1));

    final notifications = _pendingNotifications.where((notification) {
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
    debugPrint('🕒 알림 체크: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}');
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
      _fireNotification(notification);
    }
  }

  void _fireNotification(NotificationEvent notification) {
    if (!_firedNotifications.any((fired) =>
        fired.littenId == notification.littenId &&
        fired.rule.frequency == notification.rule.frequency &&
        fired.rule.timing == notification.rule.timing &&
        fired.triggerTime.isAtSameMomentAs(notification.triggerTime))) {

      _firedNotifications.add(notification);
      _pendingNotifications.remove(notification);

      // 알림 표시 (실제 구현에서는 플랫폼별 알림을 사용)
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

  void scheduleNotifications(List<Litten> littens) {
    try {
      debugPrint('🔔 알림 스케줄링 시작: ${littens.length}개 리튼');

      _pendingNotifications.clear();
      _littenMap.clear();
      final now = DateTime.now();
      int totalScheduled = 0;

      // 리튼 맵 업데이트
      for (final litten in littens) {
        _littenMap[litten.id] = litten;
      }

      for (final litten in littens) {
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
            debugPrint('✅ 알림 추가: ${notifications.length}개 (${rule.frequency.label} ${rule.timing.label})');
          } catch (e) {
            debugPrint('❌ 알림 계산 실패: "${litten.title}" - $e');
          }
        }
      }

      debugPrint('🔔 알림 스케줄링 완료: 총 $totalScheduled개 알림 예약');
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
  void manualCheckNotifications() {
    debugPrint('🔍 수동 알림 체크 실행');
    _checkNotifications();
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

  void dismissNotification(NotificationEvent notification) {
    _firedNotifications.remove(notification);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}