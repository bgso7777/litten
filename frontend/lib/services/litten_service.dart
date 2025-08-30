import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/litten.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';

class LittenService {
  static const String _luttensKey = 'littens';
  static const String _audioFilesKey = 'audio_files';
  static const String _textFilesKey = 'text_files';
  static const String _selectedLittenKey = 'selected_litten';

  // 리튼 관리
  Future<List<Litten>> getAllLittens() async {
    final prefs = await SharedPreferences.getInstance();
    final littensJson = prefs.getStringList(_luttensKey) ?? [];
    final littens = littensJson.map((json) => Litten.fromJson(jsonDecode(json))).toList();
    
    // 최신순으로 정렬 (최신이 아래로)
    littens.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    
    return littens;
  }

  Future<void> saveLitten(Litten litten) async {
    final prefs = await SharedPreferences.getInstance();
    final littens = await getAllLittens();
    
    final existingIndex = littens.indexWhere((l) => l.id == litten.id);
    if (existingIndex >= 0) {
      littens[existingIndex] = litten;
    } else {
      littens.add(litten);
    }
    
    final littensJson = littens.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_luttensKey, littensJson);
  }

  Future<void> deleteLitten(String littenId) async {
    final prefs = await SharedPreferences.getInstance();
    final littens = await getAllLittens();
    littens.removeWhere((l) => l.id == littenId);
    
    final littensJson = littens.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_luttensKey, littensJson);

    // 관련 파일들도 삭제
    await _deleteAudioFilesByLittenId(littenId);
    await _deleteTextFilesByLittenId(littenId);
  }

  Future<void> renameLitten(String littenId, String newTitle) async {
    final litten = await getLittenById(littenId);
    if (litten == null) {
      throw Exception('리튼을 찾을 수 없습니다');
    }
    
    final updatedLitten = litten.copyWith(title: newTitle);
    await saveLitten(updatedLitten);
  }

  Future<Litten?> getLittenById(String id) async {
    final littens = await getAllLittens();
    try {
      return littens.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }

  // 선택된 리튼 관리
  Future<String?> getSelectedLittenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedLittenKey);
  }

  Future<void> setSelectedLittenId(String? littenId) async {
    final prefs = await SharedPreferences.getInstance();
    if (littenId == null) {
      await prefs.remove(_selectedLittenKey);
    } else {
      await prefs.setString(_selectedLittenKey, littenId);
    }
  }

  Future<Litten?> getSelectedLitten() async {
    final selectedId = await getSelectedLittenId();
    if (selectedId == null) return null;
    return await getLittenById(selectedId);
  }

  // 오디오 파일 관리
  Future<List<AudioFile>> getAudioFilesByLittenId(String littenId) async {
    final prefs = await SharedPreferences.getInstance();
    final audioFilesJson = prefs.getStringList(_audioFilesKey) ?? [];
    final audioFiles = audioFilesJson.map((json) => AudioFile.fromJson(jsonDecode(json))).toList();
    return audioFiles.where((file) => file.littenId == littenId).toList();
  }

  // 선택된 리튼이 없을 때 기본리튼에 오디오 파일 저장
  Future<void> saveAudioFileToDefaultLitten(AudioFile audioFile) async {
    final defaultLittenId = await getOrCreateDefaultLittenId();
    final audioFileWithDefaultLitten = AudioFile(
      id: audioFile.id,
      fileName: audioFile.fileName,
      filePath: audioFile.filePath,
      duration: audioFile.duration,
      createdAt: audioFile.createdAt,
      littenId: defaultLittenId,
      fileSize: audioFile.fileSize,
    );
    await saveAudioFile(audioFileWithDefaultLitten);
  }

  Future<void> saveAudioFile(AudioFile audioFile) async {
    final prefs = await SharedPreferences.getInstance();
    final audioFilesJson = prefs.getStringList(_audioFilesKey) ?? [];
    final audioFiles = audioFilesJson.map((json) => AudioFile.fromJson(jsonDecode(json))).toList();
    
    final existingIndex = audioFiles.indexWhere((f) => f.id == audioFile.id);
    if (existingIndex >= 0) {
      audioFiles[existingIndex] = audioFile;
    } else {
      audioFiles.add(audioFile);
      // 리튼의 오디오 파일 목록도 업데이트
      await _updateLittenAudioFiles(audioFile.littenId, audioFile.id, true);
    }
    
    final updatedJson = audioFiles.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_audioFilesKey, updatedJson);
  }

  Future<void> deleteAudioFile(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final audioFilesJson = prefs.getStringList(_audioFilesKey) ?? [];
    final audioFiles = audioFilesJson.map((json) => AudioFile.fromJson(jsonDecode(json))).toList();
    
    final fileToDelete = audioFiles.firstWhere((f) => f.id == fileId);
    audioFiles.removeWhere((f) => f.id == fileId);
    
    final updatedJson = audioFiles.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_audioFilesKey, updatedJson);
    
    // 리튼의 오디오 파일 목록도 업데이트
    await _updateLittenAudioFiles(fileToDelete.littenId, fileId, false);
  }

  Future<void> _deleteAudioFilesByLittenId(String littenId) async {
    final prefs = await SharedPreferences.getInstance();
    final audioFilesJson = prefs.getStringList(_audioFilesKey) ?? [];
    final audioFiles = audioFilesJson.map((json) => AudioFile.fromJson(jsonDecode(json))).toList();
    
    audioFiles.removeWhere((f) => f.littenId == littenId);
    
    final updatedJson = audioFiles.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_audioFilesKey, updatedJson);
  }

  // 텍스트 파일 관리
  Future<List<TextFile>> getTextFilesByLittenId(String littenId) async {
    final prefs = await SharedPreferences.getInstance();
    final textFilesJson = prefs.getStringList(_textFilesKey) ?? [];
    final textFiles = textFilesJson.map((json) => TextFile.fromJson(jsonDecode(json))).toList();
    return textFiles.where((file) => file.littenId == littenId).toList();
  }

  // 선택된 리튼이 없을 때 기본리튼에 텍스트 파일 저장
  Future<void> saveTextFileToDefaultLitten(TextFile textFile) async {
    final defaultLittenId = await getOrCreateDefaultLittenId();
    final textFileWithDefaultLitten = TextFile(
      id: textFile.id,
      title: textFile.title,
      content: textFile.content,
      createdAt: textFile.createdAt,
      littenId: defaultLittenId,
      syncMarkers: textFile.syncMarkers,
    );
    await saveTextFile(textFileWithDefaultLitten);
  }

  Future<void> saveTextFile(TextFile textFile) async {
    final prefs = await SharedPreferences.getInstance();
    final textFilesJson = prefs.getStringList(_textFilesKey) ?? [];
    final textFiles = textFilesJson.map((json) => TextFile.fromJson(jsonDecode(json))).toList();
    
    final existingIndex = textFiles.indexWhere((f) => f.id == textFile.id);
    if (existingIndex >= 0) {
      textFiles[existingIndex] = textFile;
    } else {
      textFiles.add(textFile);
      // 리튼의 텍스트 파일 목록도 업데이트
      await _updateLittenTextFiles(textFile.littenId, textFile.id, true);
    }
    
    final updatedJson = textFiles.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_textFilesKey, updatedJson);
  }

  Future<void> deleteTextFile(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final textFilesJson = prefs.getStringList(_textFilesKey) ?? [];
    final textFiles = textFilesJson.map((json) => TextFile.fromJson(jsonDecode(json))).toList();
    
    final fileToDelete = textFiles.firstWhere((f) => f.id == fileId);
    textFiles.removeWhere((f) => f.id == fileId);
    
    final updatedJson = textFiles.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_textFilesKey, updatedJson);
    
    // 리튼의 텍스트 파일 목록도 업데이트
    await _updateLittenTextFiles(fileToDelete.littenId, fileId, false);
  }

  Future<void> _deleteTextFilesByLittenId(String littenId) async {
    final prefs = await SharedPreferences.getInstance();
    final textFilesJson = prefs.getStringList(_textFilesKey) ?? [];
    final textFiles = textFilesJson.map((json) => TextFile.fromJson(jsonDecode(json))).toList();
    
    textFiles.removeWhere((f) => f.littenId == littenId);
    
    final updatedJson = textFiles.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_textFilesKey, updatedJson);
  }

  // 리튼의 파일 목록 업데이트 헬퍼 메소드
  Future<void> _updateLittenAudioFiles(String littenId, String fileId, bool add) async {
    final litten = await getLittenById(littenId);
    if (litten == null) return;

    final audioFileIds = List<String>.from(litten.audioFileIds);
    if (add && !audioFileIds.contains(fileId)) {
      audioFileIds.add(fileId);
    } else if (!add) {
      audioFileIds.remove(fileId);
    }

    final updatedLitten = litten.copyWith(audioFileIds: audioFileIds);
    await saveLitten(updatedLitten);
  }

  Future<void> _updateLittenTextFiles(String littenId, String fileId, bool add) async {
    final litten = await getLittenById(littenId);
    if (litten == null) return;

    final textFileIds = List<String>.from(litten.textFileIds);
    if (add && !textFileIds.contains(fileId)) {
      textFileIds.add(fileId);
    } else if (!add) {
      textFileIds.remove(fileId);
    }

    final updatedLitten = litten.copyWith(textFileIds: textFileIds);
    await saveLitten(updatedLitten);
  }

  // 기본 리튼들 생성
  Future<void> createDefaultLittensIfNeeded({
    String? defaultLittenTitle,
    String? lectureTitle,
    String? meetingTitle,
    String? defaultLittenDescription,
    String? lectureDescription,
    String? meetingDescription,
  }) async {
    final littens = await getAllLittens();
    
    // 기본 리튼이 이미 존재하는지 확인
    final defaultTitles = [
      defaultLittenTitle ?? '기본리튼',
      lectureTitle ?? '강의',
      meetingTitle ?? '회의'
    ];
    final existingTitles = littens.map((l) => l.title).toSet();
    
    for (int i = 0; i < defaultTitles.length; i++) {
      final title = defaultTitles[i];
      if (!existingTitles.contains(title)) {
        String description;
        if (title == (defaultLittenTitle ?? '기본리튼')) {
          description = defaultLittenDescription ?? '리튼을 선택하지 않고 생성된 파일들이 저장되는 기본 공간입니다.';
        } else if (title == (lectureTitle ?? '강의')) {
          description = lectureDescription ?? '강의에 관련된 파일들을 저장하세요.';
        } else if (title == (meetingTitle ?? '회의')) {
          description = meetingDescription ?? '회의에 관련된 파일들을 저장하세요.';
        } else {
          description = '$title에 관련된 파일들을 저장하세요.';
        }
        
        final defaultLitten = Litten(
          title: title,
          description: description,
        );
        await saveLitten(defaultLitten);
      }
    }
  }

  // 기본리튼 ID 가져오기
  Future<String?> getDefaultLittenId() async {
    final littens = await getAllLittens();
    final defaultLitten = littens.where((l) => l.title == '기본리튼').firstOrNull;
    return defaultLitten?.id;
  }

  // 기본리튼이 없으면 생성하고 ID 반환
  Future<String> getOrCreateDefaultLittenId() async {
    String? defaultId = await getDefaultLittenId();
    if (defaultId == null) {
      await createDefaultLittensIfNeeded();
      defaultId = await getDefaultLittenId();
      if (defaultId == null) {
        throw Exception('기본리튼을 생성할 수 없습니다');
      }
    }
    return defaultId;
  }
}