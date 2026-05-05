import 'package:uuid/uuid.dart';

enum RemindFileType { audio, text }

class RemindItem {
  final String id;
  final String fileId;
  final RemindFileType fileType;
  final String fileName;
  final String littenId;
  final String title;
  final DateTime? remindAt;
  final String content;
  final bool isDone;
  final DateTime createdAt;

  RemindItem({
    String? id,
    required this.fileId,
    required this.fileType,
    required this.fileName,
    required this.littenId,
    required this.title,
    this.remindAt,
    this.content = '',
    this.isDone = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  RemindItem copyWith({
    String? title,
    DateTime? remindAt,
    bool clearRemindAt = false,
    String? content,
    bool? isDone,
  }) {
    return RemindItem(
      id: id,
      fileId: fileId,
      fileType: fileType,
      fileName: fileName,
      littenId: littenId,
      title: title ?? this.title,
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      content: content ?? this.content,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileId': fileId,
        'fileType': fileType.name,
        'fileName': fileName,
        'littenId': littenId,
        'title': title,
        'remindAt': remindAt?.toIso8601String(),
        'content': content,
        'isDone': isDone,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RemindItem.fromJson(Map<String, dynamic> json) => RemindItem(
        id: json['id'],
        fileId: json['fileId'],
        fileType: RemindFileType.values.firstWhere(
          (t) => t.name == (json['fileType'] as String? ?? 'text'),
          orElse: () => RemindFileType.text,
        ),
        fileName: json['fileName'] ?? '',
        littenId: json['littenId'],
        title: json['title'],
        remindAt: json['remindAt'] != null ? DateTime.parse(json['remindAt']) : null,
        content: json['content'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );
}

/// 특정 파일(오디오 or 텍스트)에 속한 리마인드 항목 그룹
class RemindTarget {
  final String fileId;
  final RemindFileType fileType;
  final String fileName;
  final List<RemindItem> items;

  const RemindTarget({
    required this.fileId,
    required this.fileType,
    required this.fileName,
    required this.items,
  });

  int get pendingCount => items.where((i) => !i.isDone).length;
}
