import '../models/litten.dart';

/// 일정(LittenSchedule) 관련 공용 유틸.
/// 캘린더 하단 칩 바(home_screen)와 펼친 일정 목록(litten_unified_list_view)이
/// **동일한 규칙**으로 다음 발생 시각/남은 시간을 계산하도록 한 곳에서 관리한다.

/// 일정의 다음 발생 시각(주간 반복 반영). 더 이상 발생하지 않으면 null.
/// - 매주 반복(요일 지정): 오늘부터 7일 내 지정 요일 중 종료 시각이 아직 안 지난 가장 가까운 발생
/// - 비반복: 종료 시각이 안 지났으면 시작 시각, 지났으면 null
DateTime? nextScheduleOccurrence(LittenSchedule s, DateTime now) {
  final weekdays = <int>{};
  for (final r in s.notificationRules) {
    if (r.isEnabled &&
        r.frequency == NotificationFrequency.weekly &&
        r.weekdays != null) {
      weekdays.addAll(r.weekdays!);
    }
  }
  final start = s.startTime;
  final end = s.endTime;

  if (weekdays.isNotEmpty) {
    final base = DateTime(now.year, now.month, now.day);
    for (int i = 0; i <= 7; i++) {
      final day = base.add(Duration(days: i));
      if (!weekdays.contains(day.weekday)) continue;
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
  const oneDayInSec = 86400; // 24*60*60
  if (secs < oneDayInSec) {
    final minutes = secs ~/ 60;
    if (minutes == 0) return '${secs % 60}초 후';
    if (minutes < 60) return '$minutes분 후';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining > 0 ? '$hours시간 $remaining분 후' : '$hours시간 후';
  }
  final days = secs ~/ oneDayInSec;
  return '$days일 후';
}
