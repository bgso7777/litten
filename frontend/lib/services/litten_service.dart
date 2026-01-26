import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/litten.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import 'notification_orchestrator_service.dart';

class LittenService {
  final NotificationOrchestratorService _notificationService = NotificationOrchestratorService();
  static const String _luttensKey = 'littens';
  static const String _audioFilesKey = 'audio_files';
  static const String _textFilesKey = 'text_files';
  static const String _selectedLittenKey = 'selected_litten';

  // 리튼 관리
  Future<List<Litten>> getAllLittens() async {
    final prefs = await SharedPreferences.getInstance();
    final littensJson = prefs.getStringList(_luttensKey) ?? [];
    final littens = littensJson.map((json) => Litten.fromJson(jsonDecode(json))).toList();
    
    // 최신순으로 정렬 (최신이 맨 위로)
    littens.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    return littens;
  }

  Future<void> saveLitten(Litten litten) async {
    debugPrint('💾 LittenService.saveLitten() 진입: littenId=${litten.id}, title=${litten.title}');

    final prefs = await SharedPreferences.getInstance();
    final littens = await getAllLittens();

    final existingIndex = littens.indexWhere((l) => l.id == litten.id);
    final isUpdate = existingIndex >= 0;

    if (isUpdate) {
      littens[existingIndex] = litten;
      debugPrint('   ℹ️ 기존 리튼 업데이트');
    } else {
      littens.add(litten);
      debugPrint('   ℹ️ 새 리튼 추가');
    }

    final littensJson = littens.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_luttensKey, littensJson);

    // 알림 처리: 리튼에 스케줄이 있으면 알림 재생성
    if (litten.schedule != null) {
      debugPrint('   🔔 리튼에 스케줄 존재 - 알림 재생성 시작');

      if (isUpdate) {
        // 수정된 리튼: 미래 알림 삭제 후 재생성
        final success = await _notificationService.recreateNotificationsForLitten(litten);
        if (success) {
          debugPrint('   ✅ 알림 재생성 완료');
        } else {
          debugPrint('   ❌ 알림 재생성 실패');
        }
      } else {
        // 새로운 리튼: 알림 생성
        final success = await _notificationService.scheduleNotificationsForLitten(litten);
        if (success) {
          debugPrint('   ✅ 알림 생성 완료');
        } else {
          debugPrint('   ❌ 알림 생성 실패');
        }
      }
    } else {
      debugPrint('   ℹ️ 스케줄 없음 - 알림 처리 생략');
    }

    debugPrint('   ✅ 리튼 저장 완료');
  }

  Future<void> deleteLitten(String littenId) async {
    debugPrint('🗑️ LittenService.deleteLitten() 진입: littenId=$littenId');

    final prefs = await SharedPreferences.getInstance();
    final littens = await getAllLittens();
    littens.removeWhere((l) => l.id == littenId);

    final littensJson = littens.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_luttensKey, littensJson);

    // 관련 알림 삭제
    debugPrint('   🔔 관련 알림 삭제 시작');
    final notificationDeleteSuccess = await _notificationService.deleteNotificationsForLitten(littenId);
    if (notificationDeleteSuccess) {
      debugPrint('   ✅ 알림 삭제 완료');
    } else {
      debugPrint('   ❌ 알림 삭제 실패');
    }

    // 관련 파일들도 삭제
    await _deleteAudioFilesByLittenId(littenId);
    await _deleteTextFilesByLittenId(littenId);

    debugPrint('   ✅ 리튼 삭제 완료');
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

  Future<void> _updateLittenHandwritingFiles(String littenId, String fileId, bool add) async {
    print('[LittenService] _updateLittenHandwritingFiles 시작 - littenId: $littenId, fileId: $fileId, add: $add');

    final litten = await getLittenById(littenId);
    if (litten == null) {
      print('[LittenService] ERROR: 리튼을 찾을 수 없음 - ID: $littenId');
      return;
    }

    print('[LittenService] 리튼 찾음 - 제목: ${litten.title}, 기존 필기 파일 수: ${litten.handwritingFileIds.length}');

    final handwritingFileIds = List<String>.from(litten.handwritingFileIds);
    if (add && !handwritingFileIds.contains(fileId)) {
      handwritingFileIds.add(fileId);
      print('[LittenService] 필기 파일 ID 추가됨 - 새 목록 크기: ${handwritingFileIds.length}');
    } else if (!add) {
      handwritingFileIds.remove(fileId);
      print('[LittenService] 필기 파일 ID 제거됨 - 새 목록 크기: ${handwritingFileIds.length}');
    } else {
      print('[LittenService] 필기 파일 ID 이미 존재함 - 변경 없음');
    }

    print('[LittenService] 리튼 저장 시작...');
    final updatedLitten = litten.copyWith(handwritingFileIds: handwritingFileIds);
    await saveLitten(updatedLitten);
    print('[LittenService] 리튼 저장 완료');
  }

  // 공개 API 메서드들
  Future<void> addAudioFileToLitten(String littenId, String fileId) async {
    await _updateLittenAudioFiles(littenId, fileId, true);
  }

  Future<void> removeAudioFileFromLitten(String littenId, String fileId) async {
    await _updateLittenAudioFiles(littenId, fileId, false);
  }

  Future<void> addTextFileToLitten(String littenId, String fileId) async {
    await _updateLittenTextFiles(littenId, fileId, true);
  }

  Future<void> removeTextFileFromLitten(String littenId, String fileId) async {
    await _updateLittenTextFiles(littenId, fileId, false);
  }

  Future<void> addHandwritingFileToLitten(String littenId, String fileId) async {
    print('[LittenService] addHandwritingFileToLitten 호출됨');
    await _updateLittenHandwritingFiles(littenId, fileId, true);
    print('[LittenService] addHandwritingFileToLitten 완료');
  }

  Future<void> removeHandwritingFileFromLitten(String littenId, String fileId) async {
    await _updateLittenHandwritingFiles(littenId, fileId, false);
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
    final defaultTitles = <String>[];

    // defaultLittenTitle이 null이 아닌 경우에만 추가 (기본리튼 제거)
    if (defaultLittenTitle != null) {
      defaultTitles.add(defaultLittenTitle);
    }

    // 강의와 회의는 항상 추가
    defaultTitles.add(lectureTitle ?? '강의');
    defaultTitles.add(meetingTitle ?? '회의');

    final existingTitles = littens.map((l) => l.title).toSet();

    for (int i = 0; i < defaultTitles.length; i++) {
      final title = defaultTitles[i];
      if (!existingTitles.contains(title)) {
        String description;
        LittenSchedule? schedule;

        if (defaultLittenTitle != null && title == defaultLittenTitle) {
          description = defaultLittenDescription ?? '리튼을 선택하지 않고 생성된 파일들이 저장되는 기본 공간입니다.';
        } else if (title == (lectureTitle ?? '강의')) {
          description = lectureDescription ?? '강의에 관련된 파일들을 저장하세요.';
          // 강의 리튼: 스케줄 없음, 알림 없음
        } else if (title == (meetingTitle ?? '회의')) {
          description = meetingDescription ?? '회의에 관련된 파일들을 저장하세요.';

          // 모임 리튼: 설치 시점 + 10분 스케줄, 정시 및 10분 전 알림
          final now = DateTime.now();
          final scheduleTime = now.add(const Duration(minutes: 10));

          // 5분 단위로 반올림
          final minute = (scheduleTime.minute / 5).round() * 5;
          final roundedTime = DateTime(
            scheduleTime.year,
            scheduleTime.month,
            scheduleTime.day,
            scheduleTime.hour,
            minute >= 60 ? 0 : minute,
          ).add(minute >= 60 ? const Duration(hours: 1) : Duration.zero);

          final startTime = TimeOfDay(hour: roundedTime.hour, minute: roundedTime.minute);
          final endTime = TimeOfDay(
            hour: (roundedTime.hour + 1) % 24,
            minute: roundedTime.minute,
          );

          // 알림 규칙: 정시와 10분 전
          final notificationRules = [
            NotificationRule(
              frequency: NotificationFrequency.onDay,
              timing: NotificationTiming.onTime,
              isEnabled: true,
            ),
            NotificationRule(
              frequency: NotificationFrequency.onDay,
              timing: NotificationTiming.tenMinutesBefore,
              isEnabled: true,
            ),
          ];

          schedule = LittenSchedule(
            date: roundedTime,
            startTime: startTime,
            endTime: endTime,
            notificationRules: notificationRules,
          );
        } else {
          description = '$title에 관련된 파일들을 저장하세요.';
        }

        final defaultLitten = Litten(
          title: title,
          description: description,
          schedule: schedule,
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