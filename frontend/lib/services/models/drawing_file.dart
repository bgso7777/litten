import 'package:uuid/uuid.dart';

/// 필기/드로잉 파일 모델 - PDF → PNG 변환 이미지 위에 필기
class DrawingFile {
  final String id;
  final String littenId;
  final String title;
  final String backgroundImagePath; // PNG 파일 경로
  final String drawingDataPath; // 필기 데이터 저장 경로 (JSON)
  final DrawingType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioTimestampIds; // 연결된 오디오 타임스탬프들
  final Map<String, dynamic> metadata;
  
  DrawingFile({
    String? id,
    required this.littenId,
    required this.title,
    required this.backgroundImagePath,
    required this.drawingDataPath,
    this.type = DrawingType.annotation,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioTimestampIds,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        audioTimestampIds = audioTimestampIds ?? [],
        metadata = metadata ?? {};
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'title': title,
      'backgroundImagePath': backgroundImagePath,
      'drawingDataPath': drawingDataPath,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'audioTimestampIds': audioTimestampIds,
      'metadata': metadata,
    };
  }
  
  /// JSON에서 생성
  factory DrawingFile.fromJson(Map<String, dynamic> json) {
    return DrawingFile(
      id: json['id'],
      littenId: json['littenId'],
      title: json['title'],
      backgroundImagePath: json['backgroundImagePath'],
      drawingDataPath: json['drawingDataPath'],
      type: DrawingType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => DrawingType.annotation,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      audioTimestampIds: List<String>.from(json['audioTimestampIds'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  /// 복사본 생성
  DrawingFile copyWith({
    String? title,
    String? drawingDataPath,
    DateTime? updatedAt,
    List<String>? audioTimestampIds,
    Map<String, dynamic>? metadata,
  }) {
    return DrawingFile(
      id: id,
      littenId: littenId,
      title: title ?? this.title,
      backgroundImagePath: backgroundImagePath,
      drawingDataPath: drawingDataPath ?? this.drawingDataPath,
      type: type,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      audioTimestampIds: audioTimestampIds ?? this.audioTimestampIds,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 오디오 타임스탬프 추가
  DrawingFile addAudioTimestamp(String timestampId) {
    if (audioTimestampIds.contains(timestampId)) {
      return this;
    }
    
    return copyWith(
      audioTimestampIds: [...audioTimestampIds, timestampId],
    );
  }
  
  /// 오디오 타임스탬프 제거
  DrawingFile removeAudioTimestamp(String timestampId) {
    return copyWith(
      audioTimestampIds: audioTimestampIds.where((id) => id != timestampId).toList(),
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DrawingFile && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'DrawingFile(id: $id, title: $title, type: ${type.name})';
  }
}

/// 필기 파일 타입
enum DrawingType {
  annotation, // PDF 주석
  sketch,     // 자유 스케치
  note,       // 필기 노트
}

/// 필기 도구 설정
class DrawingTool {
  final DrawingToolType type;
  final double strokeWidth;
  final int color; // Color.value 형태로 저장
  final double opacity;
  final Map<String, dynamic> properties;
  
  const DrawingTool({
    required this.type,
    this.strokeWidth = 2.0,
    this.color = 0xFF000000, // 검정색
    this.opacity = 1.0,
    this.properties = const {},
  });
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'strokeWidth': strokeWidth,
      'color': color,
      'opacity': opacity,
      'properties': properties,
    };
  }
  
  /// JSON에서 생성
  factory DrawingTool.fromJson(Map<String, dynamic> json) {
    return DrawingTool(
      type: DrawingToolType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => DrawingToolType.pen,
      ),
      strokeWidth: json['strokeWidth']?.toDouble() ?? 2.0,
      color: json['color'] ?? 0xFF000000,
      opacity: json['opacity']?.toDouble() ?? 1.0,
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
    );
  }
  
  /// 복사본 생성
  DrawingTool copyWith({
    DrawingToolType? type,
    double? strokeWidth,
    int? color,
    double? opacity,
    Map<String, dynamic>? properties,
  }) {
    return DrawingTool(
      type: type ?? this.type,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      properties: properties ?? this.properties,
    );
  }
}

/// 필기 도구 타입
enum DrawingToolType {
  pen,        // 펜
  pencil,     // 연필
  marker,     // 마커
  highlighter,// 하이라이터
  eraser,     // 지우개
  line,       // 직선
  rectangle,  // 사각형
  circle,     // 원
  arrow,      // 화살표
  text,       // 텍스트
}

/// 필기 데이터 포인트
class DrawingPoint {
  final double x;
  final double y;
  final double pressure;
  final DateTime timestamp;
  
  const DrawingPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const Duration().inMilliseconds != 0 
       ? timestamp! 
       : const Duration(milliseconds: 0) as DateTime;
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  /// JSON에서 생성
  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      x: json['x'].toDouble(),
      y: json['y'].toDouble(),
      pressure: json['pressure']?.toDouble() ?? 1.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

/// 필기 스트로크 (한 번의 연속된 그리기)
class DrawingStroke {
  final String id;
  final List<DrawingPoint> points;
  final DrawingTool tool;
  final DateTime createdAt;
  
  DrawingStroke({
    String? id,
    required this.points,
    required this.tool,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points.map((p) => p.toJson()).toList(),
      'tool': tool.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  /// JSON에서 생성
  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      id: json['id'],
      points: (json['points'] as List)
          .map((p) => DrawingPoint.fromJson(p))
          .toList(),
      tool: DrawingTool.fromJson(json['tool']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}