import 'package:uuid/uuid.dart';

class HandwritingFile {
  final String id;
  final String littenId;
  final String title;
  final String imagePath; // PNG 파일 경로
  final String? backgroundImagePath; // 배경 이미지 경로 (PDF에서 변환된 경우)
  final DateTime createdAt;
  final DateTime updatedAt;
  final HandwritingType type; // PDF에서 변환된 것인지, 직접 그린 것인지
  
  HandwritingFile({
    String? id,
    required this.littenId,
    String? title,
    required this.imagePath,
    this.backgroundImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    HandwritingType? type,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? _generateTitleFromPath(imagePath),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        type = type ?? HandwritingType.drawing;

  static String _generateTitleFromPath(String path) {
    final fileName = path.split('/').last;
    final nameWithoutExtension = fileName.replaceAll('.png', '');
    return nameWithoutExtension.isNotEmpty ? nameWithoutExtension : '새 필기';
  }

  String get displayTitle => title.isNotEmpty ? title : '새 필기';
  String get fileName => imagePath.split('/').last;
  bool get isFromPdf => backgroundImagePath != null;

  HandwritingFile copyWith({
    String? title,
    String? imagePath,
    String? backgroundImagePath,
    HandwritingType? type,
  }) {
    return HandwritingFile(
      id: id,
      littenId: littenId,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'title': title,
      'imagePath': imagePath,
      'backgroundImagePath': backgroundImagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'type': type.toString(),
    };
  }

  factory HandwritingFile.fromJson(Map<String, dynamic> json) {
    return HandwritingFile(
      id: json['id'],
      littenId: json['littenId'],
      title: json['title'],
      imagePath: json['imagePath'],
      backgroundImagePath: json['backgroundImagePath'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      type: HandwritingType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => HandwritingType.drawing,
      ),
    );
  }
}

enum HandwritingType {
  drawing,    // 직접 그린 필기
  pdfConvert, // PDF에서 변환된 필기
}