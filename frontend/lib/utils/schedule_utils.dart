import 'dart:convert';
import '../models/litten.dart';

/// 일정(LittenSchedule) 관련 공용 유틸.
/// 캘린더 하단 칩 바(home_screen)와 펼친 일정 목록(litten_unified_list_view)이
/// **동일한 규칙**으로 다음 발생 시각/남은 시간을 계산하도록 한 곳에서 관리한다.

/// 일정의 다음 발생 시각. 더 이상 발생하지 않으면 null.
///
/// 반복 규칙(활성 알림 규칙)을 모두 반영한다 — 캘린더 표시와 같은 규칙.
///   매일   : 기준일 이후 매일
///   매주   : 지정 요일
///   매월   : 기준일과 같은 '일'
///   매년   : 기준일과 같은 '월/일'
/// 반복 규칙이 없으면 원래 일정 구간(시작~종료일)만 본다.
///
/// 무한정 앞을 보지 않도록 **1년(366일)까지만** 탐색한다.
DateTime? nextScheduleOccurrence(LittenSchedule s, DateTime now) {
  final start = s.startTime;
  final end = s.endTime;
  final base = DateTime(s.date.year, s.date.month, s.date.day);

  final weekdays = <int>{};
  bool hasDaily = false, hasMonthly = false, hasYearly = false;
  for (final r in s.notificationRules) {
    if (!r.isEnabled) continue;
    switch (r.frequency) {
      case NotificationFrequency.daily:
        hasDaily = true;
        break;
      case NotificationFrequency.weekly:
        if (r.weekdays != null) weekdays.addAll(r.weekdays!);
        break;
      case NotificationFrequency.monthly:
        hasMonthly = true;
        break;
      case NotificationFrequency.yearly:
        hasYearly = true;
        break;
      case NotificationFrequency.onDay:
      case NotificationFrequency.oneDayBefore:
        break; // 반복이 아니라 '언제 알릴지'라서 발생일에 영향 없음
    }
  }

  final repeats = hasDaily || weekdays.isNotEmpty || hasMonthly || hasYearly;

  if (repeats) {
    final today = DateTime(now.year, now.month, now.day);
    // 최대 1년까지만 탐색 — 캘린더 표시 범위와 맞춘다.
    for (int i = 0; i <= 366; i++) {
      final day = today.add(Duration(days: i));
      if (day.isBefore(base)) continue; // 일정 시작 전에는 발생하지 않음

      final matched = hasDaily ||
          (weekdays.isNotEmpty && weekdays.contains(day.weekday)) ||
          (hasMonthly && day.day == base.day) ||
          (hasYearly && day.month == base.month && day.day == base.day);
      if (!matched) continue;

      final endDt = DateTime(day.year, day.month, day.day, end.hour, end.minute);
      if (endDt.isAfter(now)) {
        return DateTime(day.year, day.month, day.day, start.hour, start.minute);
      }
    }
    return null;
  }

  final d = s.endDate ?? s.date;
  final endDt = DateTime(d.year, d.month, d.day, end.hour, end.minute);
  if (endDt.isAfter(now)) {
    return DateTime(s.date.year, s.date.month, s.date.day, start.hour, start.minute);
  }
  return null;
}

/// 일정 시작 시각까지 남은 기간/시간 라벨.
/// - 24시간 이내: 분/시간(+분), 1분 미만은 초
/// - 24시간 이상: 일 단위
/// 이미 지난(시작 시각이 과거) 일정은 null (표시하지 않음).
String? remainingLabel(DateTime start, DateTime now) {
  final diff = start.difference(now);
  if (diff.isNegative) return null;
  final secs = diff.inSeconds;
  // 가장 큰 단위 하나만 표시: 일이 있으면 일만, 없으면 시간만, 분만, 초만.
  final days = secs ~/ 86400; // 24*60*60
  if (days >= 1) return '$days일 후';
  final hours = secs ~/ 3600;
  if (hours >= 1) return '$hours시간 후';
  final minutes = secs ~/ 60;
  if (minutes >= 1) return '$minutes분 후';
  return '$secs초 후';
}

/// 서버가 준 셀(공유) 일정 payload → LittenSchedule 변환.
///
/// 셀 일정은 리튼에 종속되지 않지만, 날짜·시각·알림 규칙 형식이 개인 일정과 같아
/// 반복 발생 계산(nextScheduleOccurrence)과 입력 위젯(SchedulePicker)을 그대로 재사용한다.
/// 형식이 깨져 있으면 null.
LittenSchedule? roomScheduleToLittenSchedule(Map<String, dynamic> rs) {
  try {
    final rulesRaw = rs['notificationRules'];
    final rules = (rulesRaw is String && rulesRaw.isNotEmpty)
        ? jsonDecode(rulesRaw) as List<dynamic>
        : const <dynamic>[];
    return LittenSchedule.fromJson({
      'date': rs['date'],
      'endDate': rs['endDate'],
      'startTime': rs['startTime'],
      'endTime': rs['endTime'],
      'notes': rs['notes'],
      'notificationRules': rules,
      'notificationStartTime': rs['notificationStartTime'],
      'notificationEndTime': rs['notificationEndTime'],
    });
  } catch (_) {
    return null;
  }
}

/// 지정 기간(now ~ until) 안에 발생하는 일정 시각을 **모두** 돌려준다.
///
/// nextScheduleOccurrence 가 "가장 가까운 1회"만 주는 데 비해,
/// 이 함수는 반복 일정을 회차별로 펼친다(알약 표시용).
/// 규칙은 nextScheduleOccurrence 와 동일하며, 반복이 없으면 최대 1회만 담긴다.
List<DateTime> scheduleOccurrencesBetween(
  LittenSchedule s,
  DateTime now,
  DateTime until,
) {
  final result = <DateTime>[];
  final start = s.startTime;
  final end = s.endTime;
  final base = DateTime(s.date.year, s.date.month, s.date.day);

  final weekdays = <int>{};
  bool hasDaily = false, hasMonthly = false, hasYearly = false;
  for (final r in s.notificationRules) {
    if (!r.isEnabled) continue;
    switch (r.frequency) {
      case NotificationFrequency.daily:
        hasDaily = true;
        break;
      case NotificationFrequency.weekly:
        if (r.weekdays != null) weekdays.addAll(r.weekdays!);
        break;
      case NotificationFrequency.monthly:
        hasMonthly = true;
        break;
      case NotificationFrequency.yearly:
        hasYearly = true;
        break;
      case NotificationFrequency.onDay:
      case NotificationFrequency.oneDayBefore:
        break;
    }
  }
  final repeats = hasDaily || weekdays.isNotEmpty || hasMonthly || hasYearly;

  if (!repeats) {
    final next = nextScheduleOccurrence(s, now);
    if (next != null && next.isBefore(until)) result.add(next);
    return result;
  }

  final today = DateTime(now.year, now.month, now.day);
  for (var day = today;
      !day.isAfter(until);
      day = day.add(const Duration(days: 1))) {
    if (day.isBefore(base)) continue;

    final matched = hasDaily ||
        (weekdays.isNotEmpty && weekdays.contains(day.weekday)) ||
        (hasMonthly && day.day == base.day) ||
        (hasYearly && day.month == base.month && day.day == base.day);
    if (!matched) continue;

    final startDt = DateTime(day.year, day.month, day.day, start.hour, start.minute);
    final endDt = DateTime(day.year, day.month, day.day, end.hour, end.minute);
    // 아직 끝나지 않았고, 시작이 미래인 회차만(진행 중인 회차는 남은시간 표시가 불가)
    if (!endDt.isAfter(now)) continue;
    if (!startDt.isAfter(now)) continue;
    if (startDt.isAfter(until)) break;
    result.add(startDt);
  }
  return result;
}
