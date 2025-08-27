import 'package:uuid/uuid.dart';

class AudioFile {
  final String id;
  final String littenId;
  final String fileName;
  final String filePath;
  final Duration? duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? fileSize;
  
  AudioFile({
    String? id,
    required this.littenId,
    required this.fileName,
    required this.filePath,
    this.duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.fileSize,
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
    Duration? duration,
    int? fileSize,
  }) {
    return AudioFile(
      id: id,
      littenId: littenId,
      fileName: fileName ?? this.fileName,
      filePath: filePath,
      duration: duration ?? this.duration,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      fileSize: fileSize ?? this.fileSize,
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
    );
  }
}