import 'package:uuid/uuid.dart';

class TextFile {
  final String id;
  final String littenId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AudioSyncMarker> syncMarkers;
  
  TextFile({
    String? id,
    required this.littenId,
    String? title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AudioSyncMarker>? syncMarkers,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? _generateTitleFromContent(content),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        syncMarkers = syncMarkers ?? [];

  static String _generateTitleFromContent(String content) {
    if (content.isEmpty) return '새 텍스트';
    final plainText = content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return plainText.length > 10 ? '${plainText.substring(0, 10)}...' : plainText;
  }

  String get displayTitle => title.isNotEmpty ? title : '새 텍스트';
  String get preview => content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  String get shortPreview => preview.length > 30 ? '${preview.substring(0, 30)}...' : preview;
  int get characterCount => content.length;
  int get wordCount => content.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

  TextFile copyWith({
    String? title,
    String? content,
    List<AudioSyncMarker>? syncMarkers,
  }) {
    return TextFile(
      id: id,
      littenId: littenId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      syncMarkers: syncMarkers ?? this.syncMarkers,
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