import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_item.dart';

/// 퀴즈를 로컬에 '별도 파일'로 저장/관리하는 서비스.
///
/// 저장 위치: `{앱문서}/quizzes/{id}.json` — 퀴즈 1건당 파일 1개.
/// (요약 저장소 [SummaryStorageService]와 동일 패턴 — 파일 동기화 파이프라인에
///  fileType 'quiz'로 그대로 태우기 위함)
///
/// 기존에는 모든 퀴즈를 SharedPreferences('quiz_items')에 통째로 저장했으므로,
/// 최초 로드 시 1회 마이그레이션해 개별 파일로 이관한다.
class QuizStorageService {
  static final QuizStorageService _instance = QuizStorageService._internal();
  factory QuizStorageService() => _instance;
  QuizStorageService._internal();

  /// 기존 SharedPreferences 통짜 저장 키 (마이그레이션 원본)
  static const String _legacyPrefsKey = 'quiz_items';

  Directory? _dirCache;
  bool _migrated = false;

  /// quizzes 디렉토리 (없으면 생성)
  Future<Directory> _quizzesDir() async {
    if (_dirCache != null) return _dirCache!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/quizzes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dirCache = dir;
    return dir;
  }

  /// 특정 퀴즈 파일 경로 (동기화/공유 업로드용)
  Future<String> quizFilePath(String id) async {
    final dir = await _quizzesDir();
    return '${dir.path}/$id.json';
  }

  /// 퀴즈 1건 저장(신규/덮어쓰기). 같은 id면 갱신된다.
  Future<bool> saveQuiz(QuizItem item) async {
    try {
      final path = await quizFilePath(item.id);
      final file = File(path);
      await file.writeAsString(jsonEncode(item.toJson()), flush: true);
      debugPrint('✅ [QuizStorage] 퀴즈 저장: ${item.id} (${item.title})');
      return true;
    } catch (e) {
      debugPrint('❌ [QuizStorage] 퀴즈 저장 실패: $e');
      return false;
    }
  }

  /// 여러 퀴즈 일괄 저장
  Future<void> saveQuizzes(List<QuizItem> items) async {
    for (final item in items) {
      await saveQuiz(item);
    }
  }

  /// 모든 퀴즈 로드 (최초 1회 SharedPreferences → 파일 마이그레이션 포함)
  Future<List<QuizItem>> getAllQuizzes() async {
    await _migrateLegacyIfNeeded();
    try {
      final dir = await _quizzesDir();
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'));
      final items = <QuizItem>[];
      for (final f in files) {
        try {
          final content = await f.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          items.add(QuizItem.fromJson(json));
        } catch (e) {
          debugPrint('⚠️ [QuizStorage] 손상된 퀴즈 파일 건너뜀: ${f.path} ($e)');
        }
      }
      debugPrint('✅ [QuizStorage] 퀴즈 ${items.length}건 로드');
      return items;
    } catch (e) {
      debugPrint('❌ [QuizStorage] 퀴즈 로드 실패: $e');
      return [];
    }
  }

  /// 특정 리튼의 퀴즈만 조회 (동기화 업로드 스윕용)
  Future<List<QuizItem>> getByLitten(String littenId) async {
    final all = await getAllQuizzes();
    return all.where((q) => q.littenId == littenId).toList();
  }

  /// 단일 퀴즈 조회
  Future<QuizItem?> getQuiz(String id) async {
    try {
      final file = File(await quizFilePath(id));
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return QuizItem.fromJson(json);
    } catch (e) {
      debugPrint('❌ [QuizStorage] 퀴즈 조회 실패: $e');
      return null;
    }
  }

  /// 퀴즈 삭제 (파일 제거)
  Future<bool> deleteQuiz(String id) async {
    try {
      final file = File(await quizFilePath(id));
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('🗑️ [QuizStorage] 퀴즈 삭제: $id');
      return true;
    } catch (e) {
      debugPrint('❌ [QuizStorage] 퀴즈 삭제 실패: $e');
      return false;
    }
  }

  /// 기존 SharedPreferences('quiz_items') 통짜 저장본을 개별 파일로 1회 이관.
  /// 이관 완료 후 레거시 키를 제거해 중복 로드를 막는다.
  Future<void> _migrateLegacyIfNeeded() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPrefsKey);
      if (legacy == null || legacy.isEmpty) return;
      final list = jsonDecode(legacy) as List;
      int count = 0;
      for (final e in list) {
        try {
          final item = QuizItem.fromJson(e as Map<String, dynamic>);
          // 이미 파일이 있으면 덮어쓰지 않는다(재실행 안전)
          final path = await quizFilePath(item.id);
          if (!await File(path).exists()) {
            await saveQuiz(item);
            count++;
          }
        } catch (e) {
          debugPrint('⚠️ [QuizStorage] 마이그레이션 항목 건너뜀: $e');
        }
      }
      await prefs.remove(_legacyPrefsKey);
      debugPrint('✅ [QuizStorage] 레거시 마이그레이션 완료 — $count건 파일 이관');
    } catch (e) {
      debugPrint('❌ [QuizStorage] 레거시 마이그레이션 실패: $e');
    }
  }
}
