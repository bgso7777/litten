import '../services/app_state_provider.dart' show SubscriptionType;

/// 구독 플랜별 사용 제한값 중앙 정의.
///
/// 정책 (2026-06-01 갱신):
/// - 무료(free): 메모 2 / 녹음 2 / 녹음메모(STT) 2 / 필기 2 / 첨부 2 / 영상 2 / 일정 2 (모두 앱 전체 기준),
///   요약 2회·퀴즈 2회, 파일변환 4회 (누적)
/// - 스탠다드(standard): 요약 10회·퀴즈 10회 (월별), 나머지 무제한
/// - 프리미엄(premium): 전부 무제한
///
/// 반환값 -1 은 "무제한"을 의미한다.
class PlanLimits {
  PlanLimits._();

  static const int unlimited = -1;

  // ── 개수 제한 (앱 전체 보유 개수) ───────────────────────────────
  static int memos(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;
  static int audios(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;
  static int sttMemos(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;
  static int handwritings(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;
  static int attachments(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;
  static int youtubeChannels(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;
  static int schedules(SubscriptionType t) => t == SubscriptionType.free ? 2 : unlimited;

  // ── 월별 횟수 제한 (매월 리셋) ──────────────────────────────────
  static int summaryPerMonth(SubscriptionType t) => switch (t) {
        SubscriptionType.free => 2,
        SubscriptionType.standard => 10,
        SubscriptionType.premium => unlimited,
      };
  static int quizPerMonth(SubscriptionType t) => switch (t) {
        SubscriptionType.free => 2,
        SubscriptionType.standard => 10,
        SubscriptionType.premium => unlimited,
      };

  // ── 누적 횟수 제한 (리셋 없음) ──────────────────────────────────
  static int fileConvertTotal(SubscriptionType t) => t == SubscriptionType.free ? 4 : unlimited;
}
