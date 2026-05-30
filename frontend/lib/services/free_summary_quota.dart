import 'package:shared_preferences/shared_preferences.dart';

/// 무료 플랜 요약 체험 횟수 쿼터.
/// 유튜브/텍스트 등 모든 요약 버튼이 같은 카운트를 공유한다 (무분별한 사용 방지).
class FreeSummaryQuota {
  /// 무료 체험 최대 횟수
  static const int limit = 3;
  static const String _key = 'free_summary_count';

  /// 현재까지 사용한 횟수 (0..limit)
  static Future<int> used() async {
    final p = await SharedPreferences.getInstance();
    return (p.getInt(_key) ?? 0).clamp(0, limit);
  }

  /// 아직 사용 가능한지
  static Future<bool> canUse() async => (await used()) < limit;

  /// 사용 횟수 +1 (반환: 증가 후 값)
  static Future<int> increment() async {
    final p = await SharedPreferences.getInstance();
    final next = (p.getInt(_key) ?? 0) + 1;
    await p.setInt(_key, next);
    return next;
  }

  /// 버튼 라벨 접미사 — "(무료 2/3)"
  static String label(int usedCount) => '(무료 ${usedCount.clamp(0, limit)}/$limit)';
}
