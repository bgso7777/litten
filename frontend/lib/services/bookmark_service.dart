import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/bookmark.dart';

class BookmarkService {
  static const String _bookmarksKey = 'bookmarks';
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  final Uuid _uuid = const Uuid();

  /// 모든 즐겨찾기를 가져옵니다
  Future<List<Bookmark>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getStringList(_bookmarksKey) ?? [];

      // 첫 실행 시 기본 즐겨찾기 추가
      if (bookmarksJson.isEmpty) {
        await _addDefaultBookmarks();
        final updatedBookmarksJson = prefs.getStringList(_bookmarksKey) ?? [];
        return updatedBookmarksJson
            .map((jsonString) => Bookmark.fromJson(json.decode(jsonString)))
            .toList();
      }

      return bookmarksJson
          .map((jsonString) => Bookmark.fromJson(json.decode(jsonString)))
          .toList();
    } catch (e) {
      print('❌ 즐겨찾기 로드 에러: $e');
      return [];
    }
  }

  /// 즐겨찾기를 추가합니다
  Future<bool> addBookmark(String title, String url, {String? favicon}) async {
    try {
      // 중복 URL 체크
      final existingBookmarks = await getBookmarks();
      if (existingBookmarks.any((bookmark) => bookmark.url == url)) {
        print('⚠️ 이미 즐겨찾기에 추가된 URL입니다: $url');
        return false;
      }

      final bookmark = Bookmark(
        id: _uuid.v4(),
        title: title.isEmpty ? _extractDomainFromUrl(url) : title,
        url: url,
        createdAt: DateTime.now(),
        favicon: favicon,
      );

      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getStringList(_bookmarksKey) ?? [];
      bookmarksJson.add(json.encode(bookmark.toJson()));

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
      print('✅ 즐겨찾기 추가 완료: ${bookmark.title}');
      return true;
    } catch (e) {
      print('❌ 즐겨찾기 추가 에러: $e');
      return false;
    }
  }

  /// 즐겨찾기를 삭제합니다
  Future<bool> removeBookmark(String bookmarkId) async {
    try {
      final bookmarks = await getBookmarks();
      final updatedBookmarks = bookmarks
          .where((bookmark) => bookmark.id != bookmarkId)
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = updatedBookmarks
          .map((bookmark) => json.encode(bookmark.toJson()))
          .toList();

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
      print('✅ 즐겨찾기 삭제 완료: $bookmarkId');
      return true;
    } catch (e) {
      print('❌ 즐겨찾기 삭제 에러: $e');
      return false;
    }
  }

  /// URL이 즐겨찾기에 있는지 확인합니다
  Future<bool> isBookmarked(String url) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.any((bookmark) => bookmark.url == url);
    } catch (e) {
      print('❌ 즐겨찾기 확인 에러: $e');
      return false;
    }
  }

  /// 즐겨찾기를 업데이트합니다
  Future<bool> updateBookmark(String bookmarkId, String title, String url) async {
    try {
      final bookmarks = await getBookmarks();
      final bookmarkIndex = bookmarks.indexWhere((bookmark) => bookmark.id == bookmarkId);

      if (bookmarkIndex == -1) {
        print('❌ 즐겨찾기를 찾을 수 없습니다: $bookmarkId');
        return false;
      }

      final updatedBookmark = Bookmark(
        id: bookmarks[bookmarkIndex].id,
        title: title,
        url: url,
        createdAt: bookmarks[bookmarkIndex].createdAt,
        favicon: bookmarks[bookmarkIndex].favicon,
      );

      bookmarks[bookmarkIndex] = updatedBookmark;

      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = bookmarks
          .map((bookmark) => json.encode(bookmark.toJson()))
          .toList();

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
      print('✅ 즐겨찾기 업데이트 완료: ${updatedBookmark.title}');
      return true;
    } catch (e) {
      print('❌ 즐겨찾기 업데이트 에러: $e');
      return false;
    }
  }

  /// URL에서 도메인을 추출합니다
  String _extractDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (e) {
      return url;
    }
  }

  /// 기본 즐겨찾기를 추가합니다
  Future<void> _addDefaultBookmarks() async {
    try {
      final defaultBookmarks = [
        Bookmark(
          id: _uuid.v4(),
          title: 'Google',
          url: 'https://www.google.com',
          createdAt: DateTime.now(),
          favicon: 'https://www.google.com/favicon.ico',
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = defaultBookmarks
          .map((bookmark) => json.encode(bookmark.toJson()))
          .toList();

      await prefs.setStringList(_bookmarksKey, bookmarksJson);
      print('✅ 기본 즐겨찾기 추가 완료: ${defaultBookmarks.length}개');
    } catch (e) {
      print('❌ 기본 즐겨찾기 추가 에러: $e');
    }
  }

  /// 모든 즐겨찾기를 삭제합니다 (개발/테스트 용도)
  Future<void> clearAllBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookmarksKey);
      print('✅ 모든 즐겨찾기 삭제 완료');
    } catch (e) {
      print('❌ 즐겨찾기 전체 삭제 에러: $e');
    }
  }
}