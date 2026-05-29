/// 요약 수준 — 백엔드 summary_type 컬럼과 1:1 매핑 (단일 선택)
/// SummaryRequestVo.summaryLevel: ONE_LINE=1, SHORT=2, NORMAL=3, DETAILED=4, FULL=5
class SummaryTypes {
  static const String oneLine  = 'ONE_LINE';
  static const String short    = 'SHORT';
  static const String normal   = 'NORMAL';
  static const String detailed = 'DETAILED';
  static const String full     = 'FULL';

  static const List<String> values = [oneLine, short, normal, detailed, full];
  static const String defaultValue = normal;

  static String label(String? type) {
    switch (type) {
      case oneLine:  return '한줄 요약';
      case short:    return '간단 요약';
      case normal:   return '일반 요약';
      case detailed: return '상세 요약';
      case full:     return '거의 전체';
      default:       return '일반 요약';
    }
  }
}

/// 리마인드 종류 — 백엔드 remind_type 컬럼과 매핑 (단일 선택)
/// CUSTOM 선택 시 remindCustomCount 사용
class RemindTypes {
  static const String one    = 'ONE';
  static const String three  = 'THREE';
  static const String five   = 'FIVE';
  static const String ten    = 'TEN';
  static const String twenty = 'TWENTY';
  static const String custom = 'CUSTOM';

  static const List<String> values = [one, three, five, ten, twenty, custom];
  static const String defaultValue = five;

  static String label(String? type, {int? customCount}) {
    switch (type) {
      case one:    return '1개 (꼭기억)';
      case three:  return '3개 (핵심)';
      case five:   return '5개 (기본)';
      case ten:    return '10개 (상세)';
      case twenty: return '20개 (전체)';
      case custom: return customCount != null ? '$customCount개' : 'N개 (직접입력)';
      default:     return '5개 (기본)';
    }
  }
}

class YoutubeChannel {
  final int id;
  final String memberId;
  final String channelId;
  final String channelName;
  final String channelThumbnail;
  final bool isActive;
  final bool autoTitle;
  final bool autoMemo;
  final bool autoSummary;
  final String? summaryType;
  final bool autoRemind;
  final String? remindType;
  final int? remindCustomCount;

  const YoutubeChannel({
    required this.id,
    required this.memberId,
    required this.channelId,
    required this.channelName,
    required this.channelThumbnail,
    required this.isActive,
    this.autoTitle = true,
    this.autoMemo = false,
    this.autoSummary = false,
    this.summaryType,
    this.autoRemind = false,
    this.remindType,
    this.remindCustomCount,
  });

  factory YoutubeChannel.fromJson(Map<String, dynamic> json) => YoutubeChannel(
        id: json['id'] ?? 0,
        memberId: json['memberId'] ?? '',
        channelId: json['channelId'] ?? '',
        channelName: json['channelName'] ?? '',
        channelThumbnail: json['channelThumbnail'] ?? '',
        isActive: json['isActive'] ?? true,
        autoTitle: json['autoTitle'] ?? true,
        autoMemo: json['autoMemo'] ?? false,
        autoSummary: json['autoSummary'] ?? false,
        summaryType: json['summaryType'] as String?,
        autoRemind: json['autoRemind'] ?? false,
        remindType: json['remindType'] as String?,
        remindCustomCount: (json['remindCustomCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'channelId': channelId,
        'channelName': channelName,
        'channelThumbnail': channelThumbnail,
        'isActive': isActive,
        'autoTitle': autoTitle,
        'autoMemo': autoMemo,
        'autoSummary': autoSummary,
        'summaryType': summaryType,
        'autoRemind': autoRemind,
        'remindType': remindType,
        'remindCustomCount': remindCustomCount,
      };

  YoutubeChannel copyWith({
    bool? autoTitle,
    bool? autoMemo,
    bool? autoSummary,
    String? summaryType,
    bool clearSummaryType = false,
    bool? autoRemind,
    String? remindType,
    bool clearRemindType = false,
    int? remindCustomCount,
    bool clearRemindCustomCount = false,
  }) => YoutubeChannel(
        id: id,
        memberId: memberId,
        channelId: channelId,
        channelName: channelName,
        channelThumbnail: channelThumbnail,
        isActive: isActive,
        autoTitle: autoTitle ?? this.autoTitle,
        autoMemo: autoMemo ?? this.autoMemo,
        autoSummary: autoSummary ?? this.autoSummary,
        summaryType: clearSummaryType ? null : (summaryType ?? this.summaryType),
        autoRemind: autoRemind ?? this.autoRemind,
        remindType: clearRemindType ? null : (remindType ?? this.remindType),
        remindCustomCount: clearRemindCustomCount
            ? null
            : (remindCustomCount ?? this.remindCustomCount),
      );
}

class YoutubeVideosResult {
  final List<YoutubeVideo> videos;
  final int totalPages;
  const YoutubeVideosResult({required this.videos, required this.totalPages});
}

class YoutubeVideo {
  final int id;
  final String channelId;
  final String videoId;
  final String title;
  final String? publishedAt;
  final String? transcriptText;
  final String? summary;
  final String status;
  /// 목록 API에서 서버가 내려주는 자막 존재 여부 (transcriptText가 null이어도 신뢰 가능)
  final bool hasTranscript;

  const YoutubeVideo({
    required this.id,
    required this.channelId,
    required this.videoId,
    required this.title,
    this.publishedAt,
    this.transcriptText,
    this.summary,
    required this.status,
    this.hasTranscript = false,
  });

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) => YoutubeVideo(
        id: json['id'] ?? 0,
        channelId: json['channelId'] ?? '',
        videoId: json['videoId'] ?? '',
        title: json['title'] ?? '',
        publishedAt: json['publishedAt'],
        transcriptText: json['transcriptText'],
        summary: json['summary'],
        status: json['status'] ?? 'pending',
        hasTranscript: json['hasTranscript'] == true,
      );

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
  bool get hasSummary => summary != null && summary!.isNotEmpty;
  bool get isDone => status == 'done';
  bool get hasNoTranscript => status == 'no_transcript';
}
