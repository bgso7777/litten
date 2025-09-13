import 'package:uuid/uuid.dart';

class HandwritingFile {
  final String id;
  final String littenId;
  final String title;
  final String imagePath; // PNG 파일 경로
  final String? backgroundImagePath; // 배경 이미지 경로 (PDF에서 변환된 경우)
  final List<String> pageImagePaths; // 다중 페이지 이미지 경로들 (PDF 변환 시)
  final int totalPages; // 전체 페이지 수
  final int currentPageIndex; // 현재 보고 있는 페이지 인덱스
  final DateTime createdAt;
  final DateTime updatedAt;
  final HandwritingType type; // PDF에서 변환된 것인지, 직접 그린 것인지
  final double? aspectRatio; // 이미지의 가로세로 비율 (width / height)
  
  HandwritingFile({
    String? id,
    required this.littenId,
    String? title,
    required this.imagePath,
    this.backgroundImagePath,
    List<String>? pageImagePaths,
    int? totalPages,
    int? currentPageIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    HandwritingType? type,
    this.aspectRatio,
  })  : id = id ?? const Uuid().v4(),
        title = title ?? _generateTitleFromPath(imagePath),
        pageImagePaths = pageImagePaths ?? [imagePath],
        totalPages = totalPages ?? 1,
        currentPageIndex = currentPageIndex ?? 0,
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
  bool get isMultiPage => totalPages > 1;
  String get currentPagePath => pageImagePaths.isNotEmpty ? pageImagePaths[currentPageIndex] : imagePath;
  String get pageInfo => isMultiPage ? '${currentPageIndex + 1}/$totalPages' : '';

  // 페이지 네비게이션을 위한 편의 메서드들
  bool get canGoPreviousPage => currentPageIndex > 0;
  bool get canGoNextPage => currentPageIndex < totalPages - 1;

  HandwritingFile goToNextPage() {
    if (canGoNextPage) {
      return copyWith(currentPageIndex: currentPageIndex + 1);
    }
    return this;
  }

  HandwritingFile goToPreviousPage() {
    if (canGoPreviousPage) {
      return copyWith(currentPageIndex: currentPageIndex - 1);
    }
    return this;
  }

  HandwritingFile goToPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < totalPages) {
      return copyWith(currentPageIndex: pageIndex);
    }
    return this;
  }

  HandwritingFile copyWith({
    String? title,
    String? imagePath,
    String? backgroundImagePath,
    List<String>? pageImagePaths,
    int? totalPages,
    int? currentPageIndex,
    HandwritingType? type,
    double? aspectRatio,
  }) {
    return HandwritingFile(
      id: id,
      littenId: littenId,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      pageImagePaths: pageImagePaths ?? this.pageImagePaths,
      totalPages: totalPages ?? this.totalPages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      type: type ?? this.type,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'title': title,
      'imagePath': imagePath,
      'backgroundImagePath': backgroundImagePath,
      'pageImagePaths': pageImagePaths,
      'totalPages': totalPages,
      'currentPageIndex': currentPageIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'type': type.toString(),
      'aspectRatio': aspectRatio,
    };
  }

  factory HandwritingFile.fromJson(Map<String, dynamic> json) {
    return HandwritingFile(
      id: json['id'],
      littenId: json['littenId'],
      title: json['title'],
      imagePath: json['imagePath'],
      backgroundImagePath: json['backgroundImagePath'],
      pageImagePaths: json['pageImagePaths'] != null
          ? List<String>.from(json['pageImagePaths'])
          : [json['imagePath']],
      totalPages: json['totalPages'] ?? 1,
      currentPageIndex: json['currentPageIndex'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      type: HandwritingType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => HandwritingType.drawing,
      ),
      aspectRatio: json['aspectRatio']?.toDouble(),
    );
  }
}

enum HandwritingType {
  drawing,    // 직접 그린 필기
  pdfConvert, // PDF에서 변환된 필기
}