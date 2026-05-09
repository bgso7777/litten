import 'package:uuid/uuid.dart';
import 'audio_file.dart' show SyncStatus;

class SummaryRecord {
  final String summary;
  final DateTime createdAt;
  final int level;
  final String summaryLanguage;
  final String textLanguage;

  const SummaryRecord({
    required this.summary,
    required this.createdAt,
    required this.level,
    required this.summaryLanguage,
    required this.textLanguage,
  });

  String get label {
    final d = createdAt;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'level': level,
        'summaryLanguage': summaryLanguage,
        'textLanguage': textLanguage,
      };

  factory SummaryRecord.fromJson(dynamic json) {
    // 하위 호환: 기존 String 타입이면 변환
    if (json is String) {
      return SummaryRecord(
        summary: json,
        createdAt: DateTime(2000),
        level: 3,
        summaryLanguage: 'ko',
        textLanguage: 'ko',
      );
    }
    final map = json as Map<String, dynamic>;
    return SummaryRecord(
      summary: map['summary'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      level: map['level'] as int? ?? 3,
      summaryLanguage: map['summaryLanguage'] as String? ?? 'ko',
      textLanguage: map['textLanguage'] as String? ?? 'ko',
    );
  }
}

class TextFile {
  final String id;
  final String littenId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AudioSyncMarker> syncMarkers;
  final String? summary;
  final List<SummaryRecord> summaryHistory; // 요약 이력 (최신순)
  final String? cloudId;
  final DateTime? cloudUpdatedAt;
  final SyncStatus syncStatus;
  final bool isFromSTT;

  TextFile({
    String? id,
    required this.littenId,
    String? title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AudioSyncMarker>? syncMarkers,
    this.summary,
    List<SummaryRecord>? summaryHistory,
    this.cloudId,
    this.cloudUpdatedAt,
    this.syncStatus = SyncStatus.none,
    this.isFromSTT = false,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? _generateTitleFromContent(content),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        syncMarkers = syncMarkers ?? [],
        summaryHistory = summaryHistory ?? [];

  static String _generateTitleFromContent(String content) {
    if (content.isEmpty) return '새 텍스트';
    final plainText = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return plainText.length > 10 ? '${plainText.substring(0, 10)}...' : plainText;
  }

  String get displayTitle => title.isNotEmpty ? title : '새 텍스트';
  String get fileName => title; // title을 fileName으로 사용
  String get preview => content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  String get shortPreview => preview.length > 10 ? '${preview.substring(0, 10)}...' : preview;
  int get characterCount => content.length;
  int get wordCount => content.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

  bool get hasSummary => summary != null && summary!.isNotEmpty;

  TextFile copyWith({
    String? title,
    String? content,
    List<AudioSyncMarker>? syncMarkers,
    String? summary,
    bool clearSummary = false,
    List<SummaryRecord>? summaryHistory,
    String? cloudId,
    DateTime? cloudUpdatedAt,
    SyncStatus? syncStatus,
    bool? isFromSTT,
  }) {
    return TextFile(
      id: id,
      littenId: littenId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      syncMarkers: syncMarkers ?? this.syncMarkers,
      summary: clearSummary ? null : (summary ?? this.summary),
      summaryHistory: summaryHistory ?? this.summaryHistory,
      cloudId: cloudId ?? this.cloudId,
      cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isFromSTT: isFromSTT ?? this.isFromSTT,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncMarkers': syncMarkers.map((marker) => marker.toJson()).toList(),
      if (summary != null) 'summary': summary,
      'summaryHistory': summaryHistory,
      'cloudId': cloudId,
      'cloudUpdatedAt': cloudUpdatedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'isFromSTT': isFromSTT,
    };
  }

  factory TextFile.fromJson(Map<String, dynamic> json) {
    return TextFile(
      id: json['id'],
      littenId: json['littenId'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncMarkers: (json['syncMarkers'] as List?)
          ?.map((marker) => AudioSyncMarker.fromJson(marker))
          .toList() ?? [],
      summary: json['summary'] as String?,
      summaryHistory: (json['summaryHistory'] as List?)
          ?.map((e) => SummaryRecord.fromJson(e))
          .toList() ?? [],
      cloudId: json['cloudId'] as String?,
      cloudUpdatedAt: json['cloudUpdatedAt'] != null ? DateTime.parse(json['cloudUpdatedAt']) : null,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == (json['syncStatus'] as String? ?? 'none'),
        orElse: () => SyncStatus.none,
      ),
      isFromSTT: json['isFromSTT'] as bool? ?? false,
    );
  }
}

class AudioSyncMarker {
  final String id;
  final int textOffset;
  final Duration audioTime;
  final DateTime createdAt;

  AudioSyncMarker({
    String? id,
    required this.textOffset,
    required this.audioTime,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String get audioTimeString {
    final minutes = audioTime.inMinutes;
    final seconds = audioTime.inSeconds % 60;
    final milliseconds = (audioTime.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'textOffset': textOffset,
      'audioTime': audioTime.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AudioSyncMarker.fromJson(Map<String, dynamic> json) {
    return AudioSyncMarker(
      id: json['id'],
      textOffset: json['textOffset'],
      audioTime: Duration(milliseconds: json['audioTime']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}