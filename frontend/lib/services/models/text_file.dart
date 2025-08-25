import 'package:uuid/uuid.dart';

/// 텍스트 파일 모델 - HTML 에디터를 통한 텍스트 작성
class TextFile {
  final String id;
  final String littenId;
  final String title;
  final String content; // HTML 형식으로 저장
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioTimestampIds; // 연결된 오디오 타임스탬프들
  final Map<String, dynamic> metadata;
  
  TextFile({
    String? id,
    required this.littenId,
    String? title,
    this.content = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioTimestampIds,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? _generateTitleFromContent(content),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        audioTimestampIds = audioTimestampIds ?? [],
        metadata = metadata ?? {};
  
  /// 내용의 첫 10글자로 제목 생성
  static String _generateTitleFromContent(String content) {
    if (content.isEmpty) return '새 텍스트';
    
    // HTML 태그 제거
    final plainText = content
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
    
    if (plainText.isEmpty) return '새 텍스트';
    
    // 첫 10글자 추출
    final title = plainText.length > 10 
        ? '${plainText.substring(0, 10)}...' 
        : plainText;
    
    return title.replaceAll('\n', ' ').trim();
  }
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'audioTimestampIds': audioTimestampIds,
      'metadata': metadata,
    };
  }
  
  /// JSON에서 생성
  factory TextFile.fromJson(Map<String, dynamic> json) {
    return TextFile(
      id: json['id'],
      littenId: json['littenId'],
      title: json['title'],
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      audioTimestampIds: List<String>.from(json['audioTimestampIds'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  /// 복사본 생성
  TextFile copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    List<String>? audioTimestampIds,
    Map<String, dynamic>? metadata,
  }) {
    final newContent = content ?? this.content;
    
    return TextFile(
      id: id,
      littenId: littenId,
      title: title ?? (newContent != this.content ? _generateTitleFromContent(newContent) : this.title),
      content: newContent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      audioTimestampIds: audioTimestampIds ?? this.audioTimestampIds,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 오디오 타임스탬프 추가
  TextFile addAudioTimestamp(String timestampId) {
    if (audioTimestampIds.contains(timestampId)) {
      return this;
    }
    
    return copyWith(
      audioTimestampIds: [...audioTimestampIds, timestampId],
    );
  }
  
  /// 오디오 타임스탬프 제거
  TextFile removeAudioTimestamp(String timestampId) {
    return copyWith(
      audioTimestampIds: audioTimestampIds.where((id) => id != timestampId).toList(),
    );
  }
  
  /// 텍스트 내용의 순수 텍스트 버전
  String get plainTextContent {
    return content
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }
  
  /// 텍스트 내용 미리보기 (30자 제한)
  String get preview {
    final plain = plainTextContent;
    if (plain.isEmpty) return '내용 없음';
    
    return plain.length > 30
        ? '${plain.substring(0, 30)}...'
        : plain;
  }
  
  /// 글자 수
  int get characterCount => plainTextContent.length;
  
  /// 단어 수 (영어 기준)
  int get wordCount {
    final words = plainTextContent.split(RegExp(r'\s+'));
    return words.where((word) => word.isNotEmpty).length;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextFile && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'TextFile(id: $id, title: $title, length: $characterCount)';
  }
}