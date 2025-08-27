import 'package:uuid/uuid.dart';

class Litten {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioFileIds;
  final List<String> textFileIds;
  final List<String> handwritingFileIds;

  Litten({
    String? id,
    required this.title,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioFileIds,
    List<String>? textFileIds,
    List<String>? handwritingFileIds,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        audioFileIds = audioFileIds ?? [],
        textFileIds = textFileIds ?? [],
        handwritingFileIds = handwritingFileIds ?? [];

  int get totalFileCount => audioFileIds.length + textFileIds.length + handwritingFileIds.length;
  int get audioCount => audioFileIds.length;
  int get textCount => textFileIds.length;
  int get handwritingCount => handwritingFileIds.length;

  Litten copyWith({
    String? title,
    String? description,
    List<String>? audioFileIds,
    List<String>? textFileIds,
    List<String>? handwritingFileIds,
  }) {
    return Litten(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      audioFileIds: audioFileIds ?? this.audioFileIds,
      textFileIds: textFileIds ?? this.textFileIds,
      handwritingFileIds: handwritingFileIds ?? this.handwritingFileIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'audioFileIds': audioFileIds,
      'textFileIds': textFileIds,
      'handwritingFileIds': handwritingFileIds,
    };
  }

  factory Litten.fromJson(Map<String, dynamic> json) {
    return Litten(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      audioFileIds: List<String>.from(json['audioFileIds'] ?? []),
      textFileIds: List<String>.from(json['textFileIds'] ?? []),
      handwritingFileIds: List<String>.from(json['handwritingFileIds'] ?? []),
    );
  }
}