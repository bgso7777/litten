import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../services/models/litten.dart';
import '../../services/models/audio_file.dart';
import '../../services/models/text_file.dart';
import '../../services/models/drawing_file.dart';
import '../../services/models/user_settings.dart';
import '../../services/domain/litten_service.dart';

/// 로컬 저장소 기반 리튼 리포지토리 구현체
class LocalLittenRepository implements LittenRepository {
  static const String _littenKey = 'littens';
  static const String _userSettingsKey = 'user_settings';
  
  @override
  Future<List<Litten>> findAll() async {
    AppConfig.logDebug('LocalLittenRepository.findAll - 모든 리튼 조회');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final littensJson = prefs.getStringList(_littenKey) ?? [];
      
      final littens = littensJson
          .map((jsonString) => Litten.fromJson(json.decode(jsonString)))
          .toList();
      
      // 최신 업데이트순으로 정렬
      littens.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      AppConfig.logInfo('LocalLittenRepository.findAll - 리튼 ${littens.length}개 조회');
      return littens;
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.findAll - 조회 실패', error, stackTrace);
      return [];
    }
  }
  
  @override
  Future<Litten?> findById(String id) async {
    AppConfig.logDebug('LocalLittenRepository.findById - ID로 리튼 조회: $id');
    
    try {
      final littens = await findAll();
      final litten = littens.cast<Litten?>().firstWhere(
        (litten) => litten?.id == id,
        orElse: () => null,
      );
      
      if (litten != null) {
        AppConfig.logInfo('LocalLittenRepository.findById - 리튼 조회 성공: ${litten.title}');
      } else {
        AppConfig.logWarning('LocalLittenRepository.findById - 리튼 없음: $id');
      }
      
      return litten;
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.findById - 조회 실패', error, stackTrace);
      return null;
    }
  }
  
  @override
  Future<Litten> create(Litten litten) async {
    AppConfig.logDebug('LocalLittenRepository.create - 리튼 생성: ${litten.title}');
    
    try {
      final littens = await findAll();
      littens.add(litten);
      
      await _saveLittens(littens);
      
      AppConfig.logInfo('LocalLittenRepository.create - 리튼 생성 성공: ${litten.id}');
      return litten;
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.create - 생성 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> update(Litten litten) async {
    AppConfig.logDebug('LocalLittenRepository.update - 리튼 업데이트: ${litten.title}');
    
    try {
      final littens = await findAll();
      final index = littens.indexWhere((l) => l.id == litten.id);
      
      if (index >= 0) {
        littens[index] = litten;
        await _saveLittens(littens);
        AppConfig.logInfo('LocalLittenRepository.update - 리튼 업데이트 성공: ${litten.id}');
        return litten;
      } else {
        throw Exception('리튼을 찾을 수 없습니다: ${litten.id}');
      }
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.update - 업데이트 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<bool> delete(String id) async {
    AppConfig.logDebug('LocalLittenRepository.delete - 리튼 삭제: $id');
    
    try {
      final littens = await findAll();
      final initialLength = littens.length;
      
      littens.removeWhere((litten) => litten.id == id);
      
      if (littens.length < initialLength) {
        await _saveLittens(littens);
        AppConfig.logInfo('LocalLittenRepository.delete - 리튼 삭제 성공: $id');
        return true;
      } else {
        AppConfig.logWarning('LocalLittenRepository.delete - 삭제할 리튼 없음: $id');
        return false;
      }
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.delete - 삭제 실패', error, stackTrace);
      return false;
    }
  }
  
  @override
  Future<List<AudioFile>> getAudioFilesByLittenId(String littenId) async {
    AppConfig.logDebug('LocalLittenRepository.getAudioFilesByLittenId - 오디오 파일 조회: $littenId');
    
    // TODO: 실제 오디오 파일 저장소에서 조회
    return [];
  }
  
  @override
  Future<List<TextFile>> getTextFilesByLittenId(String littenId) async {
    AppConfig.logDebug('LocalLittenRepository.getTextFilesByLittenId - 텍스트 파일 조회: $littenId');
    
    // TODO: 실제 텍스트 파일 저장소에서 조회
    return [];
  }
  
  @override
  Future<List<DrawingFile>> getDrawingFilesByLittenId(String littenId) async {
    AppConfig.logDebug('LocalLittenRepository.getDrawingFilesByLittenId - 드로잉 파일 조회: $littenId');
    
    // TODO: 실제 드로잉 파일 저장소에서 조회
    return [];
  }
  
  @override
  Future<UserSettings> getUserSettings() async {
    AppConfig.logDebug('LocalLittenRepository.getUserSettings - 사용자 설정 조회');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_userSettingsKey);
      
      if (settingsJson != null) {
        final settings = UserSettings.fromJson(json.decode(settingsJson));
        AppConfig.logInfo('LocalLittenRepository.getUserSettings - 설정 조회 성공');
        return settings;
      } else {
        // 기본 설정 생성
        final defaultSettings = UserSettings();
        await _saveUserSettings(defaultSettings);
        AppConfig.logInfo('LocalLittenRepository.getUserSettings - 기본 설정 생성');
        return defaultSettings;
      }
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.getUserSettings - 설정 조회 실패', error, stackTrace);
      return UserSettings();
    }
  }
  
  @override
  Future<LittenUsageStats> getUsageStats() async {
    AppConfig.logDebug('LocalLittenRepository.getUsageStats - 사용 통계 조회');
    
    try {
      final littens = await findAll();
      final stats = LittenUsageStats(
        littenCount: littens.length,
        audioFileCount: littens.fold(0, (sum, litten) => sum + litten.audioFileCount),
        textFileCount: littens.fold(0, (sum, litten) => sum + litten.textFileCount),
        drawingFileCount: littens.fold(0, (sum, litten) => sum + litten.drawingFileCount),
      );
      
      AppConfig.logInfo('LocalLittenRepository.getUsageStats - 통계 조회 성공: 리튼 ${stats.littenCount}개');
      return stats;
    } catch (error, stackTrace) {
      AppConfig.logError('LocalLittenRepository.getUsageStats - 통계 조회 실패', error, stackTrace);
      return const LittenUsageStats();
    }
  }
  
  /// 리튼 목록을 로컬 저장소에 저장
  Future<void> _saveLittens(List<Litten> littens) async {
    final prefs = await SharedPreferences.getInstance();
    final littensJson = littens
        .map((litten) => json.encode(litten.toJson()))
        .toList();
    
    await prefs.setStringList(_littenKey, littensJson);
  }
  
  /// 사용자 설정을 로컬 저장소에 저장
  Future<void> _saveUserSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userSettingsKey, json.encode(settings.toJson()));
  }
}