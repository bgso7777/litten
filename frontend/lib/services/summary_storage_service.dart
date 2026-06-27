import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/summary_entry.dart';

/// 요약을 로컬에 '별도 파일'로 저장/관리하는 서비스.
///
/// 저장 위치: `{앱문서}/summaries/{id}.json` — 요약 1건당 파일 1개.
/// 리튼/퀴즈 저장소와 분리하여, 향후 개별 동기화·공유가 쉽도록 설계.
class SummaryStorageService {
  static final SummaryStorageService _instance =
      SummaryStorageService._internal();
  factory SummaryStorageService() => _instance;
  SummaryStorageService._internal();

  Directory? _dirCache;

  /// summaries 디렉토리 (없으면 생성)
  Future<Directory> _summariesDir() async {
    if (_dirCache != null) return _dirCache!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/summaries');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dirCache = dir;
    return dir;
  }

  /// 특정 요약 파일 경로 (향후 동기화/공유 업로드용)
  Future<String> summaryFilePath(String id) async {
    final dir = await _summariesDir();
    return '${dir.path}/$id.json';
  }

  /// 요약 1건 저장(신규/덮어쓰기). 같은 id면 갱신된다.
  Future<bool> saveSummary(SummaryEntry record) async {
    try {
      final path = await summaryFilePath(record.id);
      final file = File(path);
      await file.writeAsString(jsonEncode(record.toJson()), flush: true);
      debugPrint('✅ [SummaryStorage] 요약 저장: ${record.id} (${record.title})');
      return true;
    } catch (e) {
      debugPrint('❌ [SummaryStorage] 요약 저장 실패: $e');
      return false;
    }
  }

  /// 모든 요약 로드 (최신순 정렬)
  Future<List<SummaryEntry>> getAllSummaries() async {
    try {
      final dir = await _summariesDir();
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'));
      final records = <SummaryEntry>[];
      for (final f in files) {
        try {
          final content = await f.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          records.add(SummaryEntry.fromJson(json));
        } catch (e) {
          debugPrint('⚠️ [SummaryStorage] 손상된 요약 파일 건너뜀: ${f.path} ($e)');
        }
      }
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('✅ [SummaryStorage] 요약 ${records.length}건 로드');
      return records;
    } catch (e) {
      debugPrint('❌ [SummaryStorage] 요약 로드 실패: $e');
      return [];
    }
  }

  /// 특정 리튼의 요약만 조회 (동기화 업로드 스윕용)
  Future<List<SummaryEntry>> getByLitten(String littenId) async {
    final all = await getAllSummaries();
    return all.where((s) => s.littenId == littenId).toList();
  }

  /// 단일 요약 조회
  Future<SummaryEntry?> getSummary(String id) async {
    try {
      final file = File(await summaryFilePath(id));
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SummaryEntry.fromJson(json);
    } catch (e) {
      debugPrint('❌ [SummaryStorage] 요약 조회 실패: $e');
      return null;
    }
  }

  /// 요약 삭제 (파일 제거)
  Future<bool> deleteSummary(String id) async {
    try {
      final file = File(await summaryFilePath(id));
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('🗑️ [SummaryStorage] 요약 삭제: $id');
      return true;
    } catch (e) {
      debugPrint('❌ [SummaryStorage] 요약 삭제 실패: $e');
      return false;
    }
  }
}
