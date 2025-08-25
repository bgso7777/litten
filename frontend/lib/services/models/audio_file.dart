import 'package:uuid/uuid.dart';

/// 오디오 파일 모델 - 음성 듣기 및 재생 기능
class AudioFile {
  final String id;
  final String littenId;
  final String title;
  final String filePath;
  final Duration duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AudioTimestamp> timestamps;
  final Map<String, dynamic> metadata;
  
  AudioFile({
    String? id,
    required this.littenId,
    required this.title,
    required this.filePath,
    this.duration = Duration.zero,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AudioTimestamp>? timestamps,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        timestamps = timestamps ?? [],
        metadata = metadata ?? {};
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'title': title,
      'filePath': filePath,
      'duration': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'timestamps': timestamps.map((t) => t.toJson()).toList(),
      'metadata': metadata,
    };
  }
  
  /// JSON에서 생성
  factory AudioFile.fromJson(Map<String, dynamic> json) {
    return AudioFile(
      id: json['id'],
      littenId: json['littenId'],
      title: json['title'],
      filePath: json['filePath'],
      duration: Duration(milliseconds: json['duration'] ?? 0),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      timestamps: (json['timestamps'] as List? ?? [])
          .map((t) => AudioTimestamp.fromJson(t))
          .toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  /// 복사본 생성
  AudioFile copyWith({
    String? title,
    Duration? duration,
    DateTime? updatedAt,
    List<AudioTimestamp>? timestamps,
    Map<String, dynamic>? metadata,
  }) {
    return AudioFile(
      id: id,
      littenId: littenId,
      title: title ?? this.title,
      filePath: filePath,
      duration: duration ?? this.duration,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      timestamps: timestamps ?? this.timestamps,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 타임스탬프 추가
  AudioFile addTimestamp(Duration position, String content, String type) {
    final newTimestamp = AudioTimestamp(
      position: position,
      content: content,
      type: type,
      createdAt: DateTime.now(),
    );
    
    final newTimestamps = [...timestamps, newTimestamp];
    newTimestamps.sort((a, b) => a.position.compareTo(b.position));
    
    return copyWith(timestamps: newTimestamps);
  }
  
  /// 포맷된 재생 시간
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioFile && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'AudioFile(id: $id, title: $title, duration: $formattedDuration)';
  }
}

/// 오디오 타임스탬프 - 음성-쓰기 동기화를 위한 시간 마커
class AudioTimestamp {
  final String id;
  final Duration position;
  final String content;
  final String type; // 'text', 'drawing', 'bookmark'
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  
  AudioTimestamp({
    String? id,
    required this.position,
    required this.content,
    required this.type,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        metadata = metadata ?? {};
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': position.inMilliseconds,
      'content': content,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// JSON에서 생성
  factory AudioTimestamp.fromJson(Map<String, dynamic> json) {
    return AudioTimestamp(
      id: json['id'],
      position: Duration(milliseconds: json['position']),
      content: json['content'],
      type: json['type'],
      createdAt: DateTime.parse(json['createdAt']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  /// 포맷된 위치 시간
  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTimestamp && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}