import 'package:uuid/uuid.dart';
import 'audio_file.dart' show SyncStatus;

enum QuizFileType { audio, text }

class QuizItem {
  final String id;
  final String fileId;
  final QuizFileType fileType;
  final String fileName;
  final String littenId;
  final String title;
  final DateTime? quizAt;
  final String content;
  final bool isDone;
  final DateTime createdAt;
  // ⭐ 신규: 요약 그룹화용 필드 (요약 호출마다 동일 ID 부여)
  final String? summaryGroupId; // 같은 요약 결과로 추출된 항목들 묶음
  final int? summaryLevel;      // 요약 수준 (1~5)
  final String? contentType;    // 콘텐츠 유형 (회의/강의/발표/...)
  final String? summaryText;    // 전체 요약 텍스트 (그룹 첫 항목에만 저장)
  // ⭐ 동기화용 필드 (파일 모델과 동일)
  final DateTime updatedAt;        // 로컬 수정시각 (수정 감지/LWW)
  final String? cloudId;           // 서버 동기화용 (미동기화 시 null)
  final DateTime? cloudUpdatedAt;  // 서버 버전 수정시각 (LWW 비교용)
  final SyncStatus syncStatus;     // 동기화 상태

  QuizItem({
    String? id,
    required this.fileId,
    required this.fileType,
    required this.fileName,
    required this.littenId,
    required this.title,
    this.quizAt,
    this.content = '',
    this.isDone = false,
    DateTime? createdAt,
    this.summaryGroupId,
    this.summaryLevel,
    this.contentType,
    this.summaryText,
    DateTime? updatedAt,
    this.cloudId,
    this.cloudUpdatedAt,
    this.syncStatus = SyncStatus.none,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  QuizItem copyWith({
    String? title,
    DateTime? quizAt,
    bool clearQuizAt = false,
    String? content,
    bool? isDone,
    String? summaryGroupId,
    int? summaryLevel,
    String? contentType,
    String? summaryText,
    DateTime? updatedAt,
    String? cloudId,
    DateTime? cloudUpdatedAt,
    SyncStatus? syncStatus,
    bool clearCloud = false, // true면 클라우드 동기화 상태(cloudId 등) 초기화
  }) {
    return QuizItem(
      id: id,
      fileId: fileId,
      fileType: fileType,
      fileName: fileName,
      littenId: littenId,
      title: title ?? this.title,
      quizAt: clearQuizAt ? null : (quizAt ?? this.quizAt),
      content: content ?? this.content,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
      summaryGroupId: summaryGroupId ?? this.summaryGroupId,
      summaryLevel: summaryLevel ?? this.summaryLevel,
      contentType: contentType ?? this.contentType,
      summaryText: summaryText ?? this.summaryText,
      // 명시하면 그 값 유지(다운로드 머지 시 cloud 시각), 아니면 수정 시각 갱신
      updatedAt: updatedAt ?? DateTime.now(),
      cloudId: clearCloud ? null : (cloudId ?? this.cloudId),
      cloudUpdatedAt: clearCloud ? null : (cloudUpdatedAt ?? this.cloudUpdatedAt),
      syncStatus: clearCloud ? SyncStatus.none : (syncStatus ?? this.syncStatus),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileId': fileId,
        'fileType': fileType.name,
        'fileName': fileName,
        'littenId': littenId,
        'title': title,
        'quizAt': quizAt?.toIso8601String(),
        'content': content,
        'isDone': isDone,
        'createdAt': createdAt.toIso8601String(),
        'summaryGroupId': summaryGroupId,
        'summaryLevel': summaryLevel,
        'contentType': contentType,
        'summaryText': summaryText,
        'updatedAt': updatedAt.toIso8601String(),
        'cloudId': cloudId,
        'cloudUpdatedAt': cloudUpdatedAt?.toIso8601String(),
        'syncStatus': syncStatus.name,
      };

  factory QuizItem.fromJson(Map<String, dynamic> json) => QuizItem(
        id: json['id'],
        fileId: json['fileId'],
        fileType: QuizFileType.values.firstWhere(
          (t) => t.name == (json['fileType'] as String? ?? 'text'),
          orElse: () => QuizFileType.text,
        ),
        fileName: json['fileName'] ?? '',
        littenId: json['littenId'],
        title: json['title'],
        quizAt: json['quizAt'] != null ? DateTime.parse(json['quizAt']) : null,
        content: json['content'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        summaryGroupId: json['summaryGroupId'] as String?,
        summaryLevel: json['summaryLevel'] as int?,
        contentType: json['contentType'] as String?,
        summaryText: json['summaryText'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        cloudId: json['cloudId'] as String?,
        cloudUpdatedAt: json['cloudUpdatedAt'] != null
            ? DateTime.parse(json['cloudUpdatedAt'] as String)
            : null,
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.name == (json['syncStatus'] as String? ?? 'none'),
          orElse: () => SyncStatus.none,
        ),
      );
}

/// 한 번의 요약으로 추출된 퀴즈 항목 그룹 (요약 단위로 그룹화)
class QuizTarget {
  final String fileId;
  final QuizFileType fileType;
  final String fileName;
  final List<QuizItem> items;
  final String? summaryGroupId;
  final int? summaryLevel;     // 요약 수준
  final String? contentType;   // 콘텐츠 유형
  final String? summaryText;   // 전체 요약 텍스트

  const QuizTarget({
    required this.fileId,
    required this.fileType,
    required this.fileName,
    required this.items,
    this.summaryGroupId,
    this.summaryLevel,
    this.contentType,
    this.summaryText,
  });

  int get pendingCount => items.where((i) => !i.isDone).length;
}
