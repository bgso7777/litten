class Bookmark {
  final String id;
  final String title;
  final String url;
  final DateTime createdAt;
  final String? favicon; // 웹사이트 아이콘 URL (선택사항)

  Bookmark({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
    this.favicon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'createdAt': createdAt.toIso8601String(),
      'favicon': favicon,
    };
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'],
      title: json['title'],
      url: json['url'],
      createdAt: DateTime.parse(json['createdAt']),
      favicon: json['favicon'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}