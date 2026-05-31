import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기능별 사용량(횟수) 로컬 카운터.
///
/// - 월별(monthly): 'YYYY-MM' 키를 사용해 매월 자동으로 0부터 시작(리셋). 요약/리마인드.
/// - 누적(total): 리셋 없이 평생 누적. 파일변환.
///
/// 프리미엄(로그인) 확장 시 이 카운터를 서버와 동기화하면 기기 간 합산이 된다.
class UsageQuota {
  UsageQuota._();

  // feature 식별자
  static const String summary = 'summary';
  static const String remind = 'remind';
  static const String fileConvert = 'fileconvert';

  // ── 월별 (매월 리셋) ────────────────────────────────────────────
  static String _monthKey(String feature, DateTime now) =>
      'usage_${feature}_${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// 이번 달 사용 횟수
  static Future<int> monthlyUsed(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_monthKey(feature, DateTime.now())) ?? 0;
  }

  /// 이번 달 한도(limit) 내에서 더 사용 가능한지 (limit<0 이면 무제한)
  static Future<bool> monthlyCanUse(String feature, int limit) async {
    if (limit < 0) return true;
    return (await monthlyUsed(feature)) < limit;
  }

  /// 이번 달 사용 횟수 +1
  static Future<void> monthlyIncrement(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _monthKey(feature, DateTime.now());
    await prefs.setInt(k, (prefs.getInt(k) ?? 0) + 1);
    debugPrint('[UsageQuota] $k = ${prefs.getInt(k)}');
  }

  // ── 누적 (리셋 없음) ────────────────────────────────────────────
  static String _totalKey(String feature) => 'usage_total_$feature';

  static Future<int> totalUsed(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalKey(feature)) ?? 0;
  }

  static Future<bool> totalCanUse(String feature, int limit) async {
    if (limit < 0) return true;
    return (await totalUsed(feature)) < limit;
  }

  static Future<void> totalIncrement(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _totalKey(feature);
    await prefs.setInt(k, (prefs.getInt(k) ?? 0) + 1);
    debugPrint('[UsageQuota] $k = ${prefs.getInt(k)}');
  }

  // ── 플랜별 자동 분기 (무료=누적 / 그 외=월별) ───────────────────
  // 정책: 무료는 평생 누적 횟수 제한, 스탠다드는 매월 리셋.
  static Future<int> usedBy(String feature, {required bool cumulative}) =>
      cumulative ? totalUsed(feature) : monthlyUsed(feature);
  static Future<bool> canUseBy(String feature, int limit, {required bool cumulative}) =>
      cumulative ? totalCanUse(feature, limit) : monthlyCanUse(feature, limit);
  static Future<void> incrementBy(String feature, {required bool cumulative}) =>
      cumulative ? totalIncrement(feature) : monthlyIncrement(feature);
}
