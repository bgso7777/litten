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

  List<NotificationEvent> get pendingNotifications => List.unmodifiable(_pendingNotifications);
  List<NotificationEvent> get firedNotifications => List.unmodifiable(_firedNotifications);

  void startNotificationChecker() {
    // 1분마다 알림 체크 (웹에서 더 자주 체크)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
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

    // 1분 간격으로 체크하므로 현재 시간부터 2분 이내의 알림을 찾습니다
    final endTime = currentMinute.add(const Duration(minutes: 2));

    final notifications = _pendingNotifications.where((notification) {
      return notification.triggerTime.isAfter(currentMinute.subtract(const Duration(minutes: 1))) &&
             notification.triggerTime.isBefore(endTime);
    }).toList();

    // 디버그 정보 출력
    debugPrint('🕒 알림 체크: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
    debugPrint('   대기 중인 알림: ${_pendingNotifications.length}개');
    debugPrint('   이번에 발생할 알림: ${notifications.length}개');

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

      notifyListeners();
    }
  }

  void scheduleNotifications(List<Litten> littens) {
    _pendingNotifications.clear();
    final now = DateTime.now();

    for (final litten in littens) {
      if (litten.schedule == null) continue;

      final schedule = litten.schedule!;
      for (final rule in schedule.notificationRules) {
        if (!rule.isEnabled) continue;

        final notifications = _calculateNotificationTimes(litten, schedule, rule, now);
        _pendingNotifications.addAll(notifications);
      }
    }

    notifyListeners();
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
    final testNotification = NotificationEvent(
      littenId: 'test',
      littenTitle: title,
      schedule: LittenSchedule(
        date: now,
        startTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
        endTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 2))),
      ),
      rule: NotificationRule(
        frequency: NotificationFrequency.onDay,
        timing: NotificationTiming.onTime,
        isEnabled: true,
      ),
      triggerTime: now.add(const Duration(minutes: 1)),
    );

    _pendingNotifications.add(testNotification);
    debugPrint('🧪 테스트 알림 생성: 1분 후 발생 예정');
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