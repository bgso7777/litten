class YoutubeChannel {
  final int id;
  final String memberId;
  final String channelId;
  final String channelName;
  final String channelThumbnail;
  final bool isActive;

  const YoutubeChannel({
    required this.id,
    required this.memberId,
    required this.channelId,
    required this.channelName,
    required this.channelThumbnail,
    required this.isActive,
  });

  factory YoutubeChannel.fromJson(Map<String, dynamic> json) => YoutubeChannel(
        id: json['id'] ?? 0,
        memberId: json['memberId'] ?? '',
        channelId: json['channelId'] ?? '',
        channelName: json['channelName'] ?? '',
        channelThumbnail: json['channelThumbnail'] ?? '',
        isActive: json['isActive'] ?? true,
      );
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

  const YoutubeVideo({
    required this.id,
    required this.channelId,
    required this.videoId,
    required this.title,
    this.publishedAt,
    this.transcriptText,
    this.summary,
    required this.status,
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
      );

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
  bool get hasSummary => summary != null && summary!.isNotEmpty;
  bool get isDone => status == 'done';
  bool get hasNoTranscript => status == 'no_transcript';
}
