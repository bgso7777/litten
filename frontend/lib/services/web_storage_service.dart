import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';

class WebStorageService {
  static const String _keyNotes = 'web_notes';
  
  // SharedPreferences 인스턴스
  static SharedPreferences? _prefs;
  
  // SharedPreferences 초기화
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  // 노트 저장
  static Future<void> saveNote(NoteModel note) async {
    await init();
    
    try {
      final notes = await loadNotes();
      final existingIndex = notes.indexWhere((n) => n.id == note.id);
      
      if (existingIndex != -1) {
        notes[existingIndex] = note;
        print('WebStorageService.saveNote - 기존 노트 업데이트: ${note.title}');
      } else {
        notes.add(note);
        print('WebStorageService.saveNote - 새 노트 추가: ${note.title}');
      }
      
      final notesJson = notes.map((note) => note.toJson()).toList();
      await _prefs!.setString(_keyNotes, jsonEncode(notesJson));
      print('WebStorageService.saveNote - 저장 완료. 총 노트 수: ${notes.length}');
    } catch (e) {
      print('WebStorageService.saveNote - 저장 실패: $e');
      throw e;
    }
  }
  
  // 노트 목록 로드
  static Future<List<NoteModel>> loadNotes() async {
    await init();
    
    try {
      final notesString = _prefs!.getString(_keyNotes);
      print('WebStorageService.loadNotes - notesString: $notesString');
      
      if (notesString == null || notesString.isEmpty) {
        print('WebStorageService.loadNotes - 빈 상태 반환');
        return [];
      }
      
      final notesJson = jsonDecode(notesString) as List;
      final notes = notesJson.map((json) => NoteModel.fromJson(json)).toList();
      print('WebStorageService.loadNotes - 로드된 노트 수: ${notes.length}');
      return notes;
    } catch (e) {
      print('웹 스토리지에서 노트 로드 실패: $e');
      return [];
    }
  }
  
  // 노트 삭제
  static Future<void> deleteNote(String noteId) async {
    await init();
    
    final notes = await loadNotes();
    notes.removeWhere((note) => note.id == noteId);
    
    final notesJson = notes.map((note) => note.toJson()).toList();
    await _prefs!.setString(_keyNotes, jsonEncode(notesJson));
  }
  
  // 파일 삭제 (웹에서는 실제 파일이 없으므로 빈 구현)
  static Future<void> deleteFile(String fileId) async {
    // 웹 환경에서는 실제 파일 시스템이 없으므로 아무것도 하지 않음
  }
  
  // 모든 데이터 삭제
  static Future<void> clearAllData() async {
    await init();
    await _prefs!.remove(_keyNotes);
  }
}