import 'dart:ui';
import '../config/app_config.dart';

class NoteModel {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FileModel> files;
  
  NoteModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.files = const [],
  });
  
  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'files': files.map((file) => file.toJson()).toList(),
    };
  }
  
  // JSON에서 생성
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      files: (json['files'] as List<dynamic>?)
          ?.map((fileJson) => FileModel.fromJson(fileJson))
          .toList() ?? [],
    );
  }
  
  // 복사 생성자
  NoteModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<FileModel>? files,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      files: files ?? this.files,
    );
  }
  
  // 파일 타입별 개수 계산
  int getFileCount(FileType type) {
    return files.where((file) => file.type == type).length;
  }
  
  // 오디오 파일 개수
  int get audioFileCount => getFileCount(FileType.audio);
  
  // 텍스트 파일 개수 (텍스트 + 필기 + 변환된 이미지)
  int get writingFileCount => 
      getFileCount(FileType.text) + 
      getFileCount(FileType.handwriting) + 
      getFileCount(FileType.convertedImage);
  
  // 전체 파일 개수
  int get totalFileCount => files.length;
  
  // 무료 버전 제한 확인
  bool canAddAudioFile() {
    return audioFileCount < AppConfig.maxAudioFilesPerNoteForFree;
  }
  
  bool canAddWritingFile() {
    final textCount = getFileCount(FileType.text);
    final handwritingCount = getFileCount(FileType.handwriting);
    
    return textCount < AppConfig.maxTextFilesPerNoteForFree ||
           handwritingCount < AppConfig.maxHandwritingFilesPerNoteForFree;
  }
  
  // 내용 미리보기 생성 (첫 번째 텍스트 파일에서)
  String get previewText {
    final textFiles = files.where((file) => file.type == FileType.text);
    if (textFiles.isNotEmpty) {
      final content = textFiles.first.content;
      if (content.length > 50) {
        return '${content.substring(0, 50)}...';
      }
      return content;
    }
    return description.isNotEmpty ? description : '내용 없음';
  }
}

class FileModel {
  final String id;
  final String noteId;
  final FileType type;
  final String name;
  final String content; // 텍스트 내용 또는 파일 경로
  final String? filePath; // 로컬 파일 경로
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata; // 추가 메타데이터
  
  FileModel({
    required this.id,
    required this.noteId,
    required this.type,
    required this.name,
    this.content = '',
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });
  
  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'type': type.name,
      'name': name,
      'content': content,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  // JSON에서 생성
  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'],
      noteId: json['noteId'],
      type: FileType.values.firstWhere((e) => e.name == json['type']),
      name: json['name'],
      content: json['content'] ?? '',
      filePath: json['filePath'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  // 복사 생성자
  FileModel copyWith({
    String? id,
    String? noteId,
    FileType? type,
    String? name,
    String? content,
    String? filePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FileModel(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      type: type ?? this.type,
      name: name ?? this.name,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  // 파일 크기 (메타데이터에서)
  int get fileSize => metadata['fileSize'] as int? ?? 0;
  
  // 오디오 파일 길이 (초)
  double get audioDuration => metadata['duration'] as double? ?? 0.0;
  
  // 이미지 해상도
  Size? get imageSize {
    final width = metadata['width'] as int?;
    final height = metadata['height'] as int?;
    if (width != null && height != null) {
      return Size(width.toDouble(), height.toDouble());
    }
    return null;
  }
}