import 'package:uuid/uuid.dart';
import 'audio_file.dart' show SyncStatus;

/// 요약 1건 — 리마인드 '요약' 섹션 표시 + 로컬 별도 파일 저장용 모델.
///
/// (text_file.dart의 SummaryRecord(텍스트 파일 내부 요약 이력)와는 다른, 독립 저장 단위)
///
/// 향후 동기화/공유를 감안한 설계:
///  - [id]는 안정적 UUID (파일명·서버 매칭 키)
///  - [cloudId]는 서버 동기화용 슬롯(미동기화 시 null)
///  - [toJson]/[fromJson]으로 파일 단위 직렬화 → 개별 업로드/공유 가능
///  - [toShareText]로 공유용 평문 생성
class SummaryEntry {
  final String id;
  final String littenId;
  final String sourceFileId; // 원본 파일 id (텍스트/오디오/유튜브)
  final String sourceType;   // 'text' | 'audio' | 'youtube'
  final String title;        // 원본 파일/영상 제목
  final String summaryText;  // 순수 요약 본문
  final int? summaryLevel;   // 요약 수준 1~5
  final String? contentType; // 회의/강의/발표/...
  final String? summaryGroupId; // 퀴즈 그룹과 연결 (중복 기록 방지/매칭)
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDone;         // 확인(완료) 여부 — 리마인드 하단(확인함) 영역 분류용
  final String? cloudId;     // 서버 동기화용 (미동기화 시 null)
  final DateTime? cloudUpdatedAt; // 서버 버전 수정시각 (LWW 비교용)
  final SyncStatus syncStatus;    // 동기화 상태 (파일 모델과 동일)

  SummaryEntry({
    String? id,
    required this.littenId,
    required this.sourceFileId,
    required this.sourceType,
    required this.title,
    required this.summaryText,
    this.summaryLevel,
    this.contentType,
    this.summaryGroupId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDone = false,
    this.cloudId,
    this.cloudUpdatedAt,
    this.syncStatus = SyncStatus.none,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  SummaryEntry copyWith({
    String? title,
    String? summaryText,
    int? summaryLevel,
    String? contentType,
    String? summaryGroupId,
    DateTime? updatedAt,
    bool? isDone,
    String? cloudId,
    DateTime? cloudUpdatedAt,
    SyncStatus? syncStatus,
    bool clearCloud = false, // true면 클라우드 동기화 상태(cloudId 등) 초기화
  }) {
    return SummaryEntry(
      id: id,
      littenId: littenId,
      sourceFileId: sourceFileId,
      sourceType: sourceType,
      title: title ?? this.title,
      summaryText: summaryText ?? this.summaryText,
      summaryLevel: summaryLevel ?? this.summaryLevel,
      contentType: contentType ?? this.contentType,
      summaryGroupId: summaryGroupId ?? this.summaryGroupId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDone: isDone ?? this.isDone,
      cloudId: clearCloud ? null : (cloudId ?? this.cloudId),
      cloudUpdatedAt: clearCloud ? null : (cloudUpdatedAt ?? this.cloudUpdatedAt),
      syncStatus: clearCloud ? SyncStatus.none : (syncStatus ?? this.syncStatus),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1, // 스키마 버전 (향후 마이그레이션/동기화용)
        'id': id,
        'littenId': littenId,
        'sourceFileId': sourceFileId,
        'sourceType': sourceType,
        'title': title,
        'summaryText': summaryText,
        'summaryLevel': summaryLevel,
        'contentType': contentType,
        'summaryGroupId': summaryGroupId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDone': isDone,
        'cloudId': cloudId,
        'cloudUpdatedAt': cloudUpdatedAt?.toIso8601String(),
        'syncStatus': syncStatus.name,
      };

  factory SummaryEntry.fromJson(Map<String, dynamic> json) => SummaryEntry(
        id: json['id'] as String?,
        littenId: json['littenId'] as String? ?? '',
        sourceFileId: json['sourceFileId'] as String? ?? '',
        sourceType: json['sourceType'] as String? ?? 'text',
        title: json['title'] as String? ?? '',
        summaryText: json['summaryText'] as String? ?? '',
        summaryLevel: (json['summaryLevel'] as num?)?.toInt(),
        contentType: json['contentType'] as String?,
        summaryGroupId: json['summaryGroupId'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        isDone: json['isDone'] as bool? ?? false,
        cloudId: json['cloudId'] as String?,
        cloudUpdatedAt: json['cloudUpdatedAt'] != null
            ? DateTime.parse(json['cloudUpdatedAt'] as String)
            : null,
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.name == (json['syncStatus'] as String? ?? 'none'),
          orElse: () => SyncStatus.none,
        ),
      );

  /// 공유용 평문 (제목 + 날짜 + 요약 본문)
  String toShareText() {
    final d = createdAt;
    final dateLabel =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    final buffer = StringBuffer()
      ..writeln('[요약] $title')
      ..writeln(dateLabel)
      ..writeln('')
      ..writeln(summaryText);
    return buffer.toString().trim();
  }
}
