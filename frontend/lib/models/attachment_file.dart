import 'package:uuid/uuid.dart';
import 'audio_file.dart' show SyncStatus;

/// 임의의 첨부 파일 (분석/보관/공유 용)
/// - 노트의 파일 리스트에 추가되어 표시됨
class AttachmentFile {
  final String id;
  final String littenId;
  final String fileName; // 표시용 파일명 (확장자 포함)
  final String filePath; // 로컬 저장 경로 (절대 경로)
  final int sizeBytes;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final String? cloudId;
  final DateTime? cloudUpdatedAt;

  AttachmentFile({
    String? id,
    required this.littenId,
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    this.mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.none,
    this.cloudId,
    this.cloudUpdatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayTitle => fileName;
  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  AttachmentFile copyWith({
    String? fileName,
    String? filePath,
    int? sizeBytes,
    String? mimeType,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    String? cloudId,
    DateTime? cloudUpdatedAt,
  }) {
    return AttachmentFile(
      id: id,
      littenId: littenId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
      cloudId: cloudId ?? this.cloudId,
      cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'littenId': littenId,
        'fileName': fileName,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': syncStatus.name,
        'cloudId': cloudId,
        'cloudUpdatedAt': cloudUpdatedAt?.toIso8601String(),
      };

  factory AttachmentFile.fromJson(Map<String, dynamic> json) => AttachmentFile(
        id: json['id'],
        littenId: json['littenId'],
        fileName: json['fileName'],
        filePath: json['filePath'],
        sizeBytes: json['sizeBytes'] ?? 0,
        mimeType: json['mimeType'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.name == (json['syncStatus'] ?? 'none'),
          orElse: () => SyncStatus.none,
        ),
        cloudId: json['cloudId'],
        cloudUpdatedAt: json['cloudUpdatedAt'] != null
            ? DateTime.parse(json['cloudUpdatedAt'])
            : null,
      );
}
