import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SearchHistory {
  final String query;
  final DateTime timestamp;

  SearchHistory({
    required this.query,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SearchHistory.fromJson(Map<String, dynamic> json) => SearchHistory(
        query: json['query'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class SearchHistoryService {
  static const String _key = 'search_history';
  static const int _maxHistoryItems = 50;

  Future<void> addSearchQuery(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();

    // 중복 제거 (같은 쿼리가 있으면 제거)
    history.removeWhere((item) => item.query == query);

    // 새 검색어를 맨 앞에 추가
    history.insert(
      0,
      SearchHistory(
        query: query,
        timestamp: DateTime.now(),
      ),
    );

    // 최대 개수 제한
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    // 저장
    final jsonList = history.map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonList.toString());

    debugPrint('🔍 검색 히스토리 추가: $query (총 ${history.length}개)');
  }

  Future<List<SearchHistory>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      // 문자열을 리스트로 파싱
      final List<dynamic> jsonList = _parseJsonList(jsonString);
      return jsonList
          .map((json) => SearchHistory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ 검색 히스토리 로드 오류: $e');
      return [];
    }
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    debugPrint('🗑️ 검색 히스토리 삭제 완료');
  }

  Future<void> removeSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();

    history.removeWhere((item) => item.query == query);

    final jsonList = history.map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonList.toString());

    debugPrint('🗑️ 검색 히스토리 항목 제거: $query');
  }

  // 간단한 JSON 파싱 (toString()으로 저장된 형태를 파싱)
  List<dynamic> _parseJsonList(String jsonString) {
    try {
      // toString()으로 저장된 형태: [{key: value, ...}, ...]
      jsonString = jsonString.trim();
      if (jsonString.startsWith('[') && jsonString.endsWith(']')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
      }

      if (jsonString.isEmpty) return [];

      final List<dynamic> result = [];
      final items = jsonString.split('}, {');

      for (var item in items) {
        item = item.trim();
        if (!item.startsWith('{')) item = '{$item';
        if (!item.endsWith('}')) item = '$item}';

        final map = <String, dynamic>{};
        final pairs = item
            .substring(1, item.length - 1)
            .split(', ')
            .where((s) => s.contains(':'));

        for (var pair in pairs) {
          final parts = pair.split(': ');
          if (parts.length == 2) {
            final key = parts[0].trim();
            final value = parts[1].trim();
            map[key] = value;
          }
        }

        if (map.isNotEmpty) {
          result.add(map);
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ JSON 파싱 오류: $e');
      return [];
    }
  }
}
