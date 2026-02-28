import 'package:flutter/foundation.dart';
import '../models/litten.dart';
import '../models/stored_notification.dart';

/// 알림 생성 서비스
/// 1회성 알림(1개) 또는 반복 알림(1년치)을 생성합니다.
class NotificationGeneratorService {

  /// 리튼의 스케줄에 따라 알림 생성
  /// - 1회성 알림 (onDay, oneDayBefore): 1개만 생성
  /// - 반복 알림 (daily, weekly, monthly, yearly): 1년치(365일) 생성
  List<StoredNotification> generateNotificationsForLitten(Litten litten) {
    debugPrint('🔔 NotificationGeneratorService.generateNotificationsForLitten() 진입: littenId=${litten.id}, title=${litten.title}');

    if (litten.schedule == null) {
      debugPrint('   ⚠️ 스케줄이 없어서 알림 생성 불가');
      return [];
    }

    final schedule = litten.schedule!;
    debugPrint('   📅 스케줄 정보: date=${schedule.date}, startTime=${schedule.startTime}');
    debugPrint('   📋 알림 규칙 수: ${schedule.notificationRules.length}');

    final List<StoredNotification> allNotifications = [];

    for (final rule in schedule.notificationRules) {
      debugPrint('   🔍 규칙 확인: ${rule.frequency.label} ${rule.timing.label}, enabled=${rule.isEnabled}');

      if (!rule.isEnabled) {
        debugPrint('   ⏸️ 비활성화된 알림 규칙 건너뛰기: ${rule.frequency.label} ${rule.timing.label}');
        continue;
      }

      final notifications = _generateNotificationsForRule(litten, schedule, rule);
      allNotifications.addAll(notifications);

      debugPrint('   ✅ ${rule.frequency.label} ${rule.timing.label}: ${notifications.length}개 알림 생성');
    }

    debugPrint('   📊 총 ${allNotifications.length}개 알림 생성 완료');
    return allNotifications;
  }

  /// 특정 알림 규칙에 대한 알림 생성
  List<StoredNotification> _generateNotificationsForRule(
    Litten litten,
    LittenSchedule schedule,
    NotificationRule rule,
  ) {
    debugPrint('   🔄 _generateNotificationsForRule() 진입: ${rule.frequency.label} ${rule.timing.label}');

    final now = DateTime.now();
    final List<StoredNotification> notifications = [];

    // 스케줄 시작 시간 계산
    final scheduleDateTime = DateTime(
      schedule.date.year,
      schedule.date.month,
      schedule.date.day,
      schedule.startTime.hour,
      schedule.startTime.minute,
    );

    debugPrint('      ⏰ 현재 시간: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    debugPrint('      📅 스케줄 시간: ${scheduleDateTime.year}-${scheduleDateTime.month.toString().padLeft(2, '0')}-${scheduleDateTime.day.toString().padLeft(2, '0')} ${scheduleDateTime.hour.toString().padLeft(2, '0')}:${scheduleDateTime.minute.toString().padLeft(2, '0')}');

    // 1회성 알림인지 반복 알림인지 판단
    final isRepeating = _isRepeatingFrequency(rule.frequency);

    if (isRepeating) {
      // 반복 알림: 종료일자가 있으면 그 날짜까지, 없으면 1년치 생성
      final DateTime limitDate;
      if (schedule.endDate != null) {
        // 종료일자가 있으면 종료일자의 endTime까지 알림 생성
        limitDate = DateTime(
          schedule.endDate!.year,
          schedule.endDate!.month,
          schedule.endDate!.day,
          schedule.endTime.hour,
          schedule.endTime.minute,
        );
        debugPrint('      📅 반복 알림 종료일자까지 생성: ${now.year}-${now.month}-${now.day} ~ ${limitDate.year}-${limitDate.month}-${limitDate.day}');
      } else {
        // 종료일자가 없으면 1년치 생성
        limitDate = now.add(const Duration(days: 365));
        debugPrint('      📅 반복 알림 1년치 생성: ${now.year}-${now.month}-${now.day} ~ ${limitDate.year}-${limitDate.month}-${limitDate.day}');
      }

      DateTime? nextTrigger = _getNextTriggerTime(scheduleDateTime, rule, now);

      while (nextTrigger != null && (nextTrigger.isBefore(limitDate) || nextTrigger.isAtSameMomentAs(limitDate))) {
        // 알림 발생 시간 범위 검증 (notificationStartTime ~ notificationEndTime)
        if (_isWithinNotificationTimeRange(schedule, nextTrigger)) {
          final notification = StoredNotification(
            id: StoredNotification.generateId(litten.id, nextTrigger),
            littenId: litten.id,
            triggerTime: nextTrigger,
            rule: rule,
            isRepeating: true,
          );
          notifications.add(notification);

          debugPrint('         - ${nextTrigger.year}-${nextTrigger.month.toString().padLeft(2, '0')}-${nextTrigger.day.toString().padLeft(2, '0')} ${nextTrigger.hour.toString().padLeft(2, '0')}:${nextTrigger.minute.toString().padLeft(2, '0')}');
        }

        // 다음 발생 시간 계산
        nextTrigger = _getNextOccurrence(nextTrigger, rule.frequency, rule.weekdays);
      }
    } else {
      // 1회성 알림: 1개만 생성
      debugPrint('      📅 1회성 알림 생성');

      final triggerTime = _getNextTriggerTime(scheduleDateTime, rule, now);

      debugPrint('      🔍 트리거 시간 계산 결과: ${triggerTime != null ? '${triggerTime.year}-${triggerTime.month.toString().padLeft(2, '0')}-${triggerTime.day.toString().padLeft(2, '0')} ${triggerTime.hour.toString().padLeft(2, '0')}:${triggerTime.minute.toString().padLeft(2, '0')}' : 'null'}');

      if (triggerTime != null) {
        final isInRange = _isWithinNotificationTimeRange(schedule, triggerTime);
        debugPrint('      🔍 알림 시간 범위 체크: $isInRange');

        if (isInRange) {
          final notification = StoredNotification(
            id: StoredNotification.generateId(litten.id, triggerTime),
            littenId: litten.id,
            triggerTime: triggerTime,
            rule: rule,
            isRepeating: false,
          );
          notifications.add(notification);

          debugPrint('         ✅ 알림 생성: ${triggerTime.year}-${triggerTime.month.toString().padLeft(2, '0')}-${triggerTime.day.toString().padLeft(2, '0')} ${triggerTime.hour.toString().padLeft(2, '0')}:${triggerTime.minute.toString().padLeft(2, '0')}');
        } else {
          debugPrint('         ⚠️ 알림 시간 범위 밖');
        }
      } else {
        debugPrint('         ⚠️ 트리거 시간이 null (이미 지난 알림)');
      }
    }

    return notifications;
  }

  /// 반복 알림 빈도인지 확인
  bool _isRepeatingFrequency(NotificationFrequency frequency) {
    return frequency == NotificationFrequency.daily ||
           frequency == NotificationFrequency.weekly ||
           frequency == NotificationFrequency.monthly ||
           frequency == NotificationFrequency.yearly;
  }

  /// 다음 트리거 시간 계산
  DateTime? _getNextTriggerTime(DateTime scheduleTime, NotificationRule rule, DateTime now) {
    final baseTime = scheduleTime.add(Duration(minutes: rule.timing.minutesOffset));

    switch (rule.frequency) {
      case NotificationFrequency.onDay:
        // 당일 알림: 스케줄 시간 기준
        return baseTime.isAfter(now) ? baseTime : null;

      case NotificationFrequency.oneDayBefore:
        // 1일 전 알림
        final oneDayBefore = baseTime.subtract(const Duration(days: 1));
        return oneDayBefore.isAfter(now) ? oneDayBefore : null;

      case NotificationFrequency.daily:
        // 매일 알림
        DateTime candidate = baseTime;
        while (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;

      case NotificationFrequency.weekly:
        // 매주 알림
        // ⚠️ weekdays가 null이거나 빈 배열이면 알림 생성하지 않음 (잘못된 설정)
        if (rule.weekdays == null || rule.weekdays!.isEmpty) {
          debugPrint('      ⚠️ 주별 알림: weekdays가 설정되지 않음 - 알림 생성 불가');
          return null;
        }
        final allowedWeekdays = rule.weekdays!;

        DateTime candidate = baseTime;

        // ⭐ 수정: 먼저 현재 시간 이후로 이동
        while (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }

        // ⭐ 수정: 그 다음 허용된 요일을 찾기
        int attempts = 0;
        while (attempts < 7) { // 무한 루프 방지: 최대 7일 검색 (한 주 내에 반드시 찾아야 함)
          if (allowedWeekdays.contains(candidate.weekday)) {
            debugPrint('      ✅ 주별 알림: 다음 발생일 ${candidate.year}-${candidate.month.toString().padLeft(2, '0')}-${candidate.day.toString().padLeft(2, '0')} (요일: ${candidate.weekday})');
            return candidate;
          }
          candidate = candidate.add(const Duration(days: 1));
          attempts++;
        }
        debugPrint('      ⚠️ 주별 알림: 7일 내에 유효한 요일을 찾지 못함');
        return null;

      case NotificationFrequency.monthly:
        // 매월 알림
        DateTime candidate = baseTime;
        while (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
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
        // 매년 알림
        DateTime candidate = baseTime;
        while (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
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

  /// 다음 발생 시간 계산 (반복 알림용)
  DateTime? _getNextOccurrence(DateTime current, NotificationFrequency frequency, List<int>? weekdays) {
    switch (frequency) {
      case NotificationFrequency.onDay:
      case NotificationFrequency.oneDayBefore:
        return null; // 일회성 알림

      case NotificationFrequency.daily:
        return current.add(const Duration(days: 1));

      case NotificationFrequency.weekly:
        // 주별 알림: 다음 허용된 요일까지
        // ⚠️ weekdays가 null이거나 빈 배열이면 null 반환 (잘못된 설정)
        if (weekdays == null || weekdays.isEmpty) {
          debugPrint('      ⚠️ 주별 알림: weekdays가 설정되지 않음');
          return null;
        }
        final allowedWeekdays = weekdays;
        DateTime candidate = current.add(const Duration(days: 1));

        int attempts = 0;
        while (attempts < 7) { // 최대 7일 검색
          if (allowedWeekdays.contains(candidate.weekday)) {
            return candidate;
          }
          candidate = candidate.add(const Duration(days: 1));
          attempts++;
        }

        // 7일 내에 못 찾으면 다음 주 같은 요일
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

  /// 알림 시간 범위 내에 있는지 확인
  bool _isWithinNotificationTimeRange(LittenSchedule schedule, DateTime triggerTime) {
    if (schedule.notificationStartTime == null && schedule.notificationEndTime == null) {
      return true; // 제한 없음
    }

    final triggerMinutes = triggerTime.hour * 60 + triggerTime.minute;

    // 시작 시간 체크
    if (schedule.notificationStartTime != null) {
      final startMinutes = schedule.notificationStartTime!.hour * 60 +
                          schedule.notificationStartTime!.minute;
      if (triggerMinutes < startMinutes) {
        return false;
      }
    }

    // 종료 시간 체크
    if (schedule.notificationEndTime != null) {
      final endMinutes = schedule.notificationEndTime!.hour * 60 +
                        schedule.notificationEndTime!.minute;
      if (triggerMinutes > endMinutes) {
        return false;
      }
    }

    return true;
  }
}
