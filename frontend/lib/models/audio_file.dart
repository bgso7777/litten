import 'package:uuid/uuid.dart';

enum SyncStatus { none, pending, syncing, synced, error }

class AudioFile {
  final String id;
  final String littenId;
  final String fileName;
  final String filePath;
  final Duration? duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? fileSize;
  final String? cloudId;
  final DateTime? cloudUpdatedAt;
  final SyncStatus syncStatus;
  final bool isFromSTT; // 음성메모(STT 동시 녹음)로 생성된 파일 여부

  AudioFile({
    String? id,
    required this.littenId,
    required this.fileName,
    required this.filePath,
    this.duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.fileSize,
    this.cloudId,
    this.cloudUpdatedAt,
    this.syncStatus = SyncStatus.none,
    this.isFromSTT = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayName {
    if (fileName.isNotEmpty) return fileName;
    final dateStr = createdAt.toString().substring(0, 19).replaceAll(':', '').replaceAll(' ', '_').replaceAll('-', '');
    return 'recording_$dateStr';
  }

  String get durationString {
    if (duration == null) return '--:--';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  AudioFile copyWith({
    String? fileName,
    String? filePath,
    Duration? duration,
    int? fileSize,
    String? cloudId,
    DateTime? cloudUpdatedAt,
    SyncStatus? syncStatus,
    bool? isFromSTT,
  }) {
    return AudioFile(
      id: id,
      littenId: littenId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      fileSize: fileSize ?? this.fileSize,
      cloudId: cloudId ?? this.cloudId,
      cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isFromSTT: isFromSTT ?? this.isFromSTT,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'fileName': fileName,
      'filePath': filePath,
      'duration': duration?.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'fileSize': fileSize,
      'cloudId': cloudId,
      'cloudUpdatedAt': cloudUpdatedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'isFromSTT': isFromSTT,
    };
  }

  factory AudioFile.fromJson(Map<String, dynamic> json) {
    return AudioFile(
      id: json['id'],
      littenId: json['littenId'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      duration: json['duration'] != null ? Duration(milliseconds: json['duration']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      fileSize: json['fileSize'],
      cloudId: json['cloudId'] as String?,
      cloudUpdatedAt: json['cloudUpdatedAt'] != null ? DateTime.parse(json['cloudUpdatedAt']) : null,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == (json['syncStatus'] as String? ?? 'none'),
        orElse: () => SyncStatus.none,
      ),
      isFromSTT: json['isFromSTT'] as bool? ?? false,
    );
  }
}