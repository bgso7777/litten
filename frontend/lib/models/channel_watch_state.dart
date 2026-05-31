/// 채널별 "확인 상태" — 사용자가 마지막으로 확인한 최신 영상 시각을 추적한다.
///
/// 스탠다드(비로그인)는 이 상태를 단말 로컬(SharedPreferences)에만 저장한다.
/// 프리미엄(로그인) 확장 시, 이 모델 구조를 그대로 백엔드 테이블
/// (예: channel_watch_state)로 업로드/다운로드만 추가하면 동기화가 된다.
/// → 그래서 필드를 서버 컬럼과 1:1 매핑 가능하도록 단순/명시적으로 설계했다.
class ChannelWatchState {
  /// 채널 식별자 (YoutubeChannel.channelId)
  final String channelId;

  /// 마지막으로 "확인함" 처리한 시점의 최신 영상 게시일.
  /// 채널의 최신 영상 게시일이 이 값보다 나중이면 "새 영상 있음"으로 판단한다.
  final DateTime? lastSeenAt;

  /// 마지막으로 확인한 최신 영상의 videoId (보조 식별/디버깅용)
  final String? lastSeenVideoId;

  /// 이 상태가 갱신된 시각 (서버 동기화 시 충돌 해결 기준)
  final DateTime updatedAt;

  const ChannelWatchState({
    required this.channelId,
    this.lastSeenAt,
    this.lastSeenVideoId,
    required this.updatedAt,
  });

  ChannelWatchState copyWith({
    DateTime? lastSeenAt,
    String? lastSeenVideoId,
    DateTime? updatedAt,
  }) =>
      ChannelWatchState(
        channelId: channelId,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        lastSeenVideoId: lastSeenVideoId ?? this.lastSeenVideoId,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
        'lastSeenVideoId': lastSeenVideoId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChannelWatchState.fromJson(Map<String, dynamic> json) => ChannelWatchState(
        channelId: json['channelId'] as String? ?? '',
        lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt'] as String) : null,
        lastSeenVideoId: json['lastSeenVideoId'] as String?,
        updatedAt: json['updatedAt'] != null
            ? (DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.fromMillisecondsSinceEpoch(0))
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
}
