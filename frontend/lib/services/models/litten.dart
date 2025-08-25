import 'package:uuid/uuid.dart';

/// 리튼 공간 모델 - 디렉토리 개념으로 각 리튼 안에 듣기, 쓰기 데이터가 통합 관리됨
class Litten {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioFileIds;
  final List<String> textFileIds;
  final List<String> drawingFileIds;
  final Map<String, dynamic> metadata;
  
  Litten({
    String? id,
    required this.title,
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioFileIds,
    List<String>? textFileIds,
    List<String>? drawingFileIds,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        audioFileIds = audioFileIds ?? [],
        textFileIds = textFileIds ?? [],
        drawingFileIds = drawingFileIds ?? [],
        metadata = metadata ?? {};
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'audioFileIds': audioFileIds,
      'textFileIds': textFileIds,
      'drawingFileIds': drawingFileIds,
      'metadata': metadata,
    };
  }
  
  /// JSON에서 생성
  factory Litten.fromJson(Map<String, dynamic> json) {
    return Litten(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      audioFileIds: List<String>.from(json['audioFileIds'] ?? []),
      textFileIds: List<String>.from(json['textFileIds'] ?? []),
      drawingFileIds: List<String>.from(json['drawingFileIds'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  /// 복사본 생성
  Litten copyWith({
    String? title,
    String? description,
    DateTime? updatedAt,
    List<String>? audioFileIds,
    List<String>? textFileIds,
    List<String>? drawingFileIds,
    Map<String, dynamic>? metadata,
  }) {
    return Litten(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      audioFileIds: audioFileIds ?? this.audioFileIds,
      textFileIds: textFileIds ?? this.textFileIds,
      drawingFileIds: drawingFileIds ?? this.drawingFileIds,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 총 파일 개수
  int get totalFileCount => audioFileIds.length + textFileIds.length + drawingFileIds.length;
  
  /// 오디오 파일 개수
  int get audioFileCount => audioFileIds.length;
  
  /// 텍스트 파일 개수
  int get textFileCount => textFileIds.length;
  
  /// 드로잉 파일 개수
  int get drawingFileCount => drawingFileIds.length;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Litten && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'Litten(id: $id, title: $title, totalFiles: $totalFileCount)';
  }
}