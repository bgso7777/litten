import 'dart:async';
import '../../config/app_config.dart';
import '../models/litten.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import '../models/drawing_file.dart';

/// 리튼 공간 관리 서비스 - Clean Architecture의 Domain Layer
abstract class LittenService {
  /// 모든 리튼 목록 조회
  Future<List<Litten>> getAllLittens();
  
  /// ID로 리튼 조회
  Future<Litten?> getLittenById(String id);
  
  /// 리튼 생성
  Future<Litten> createLitten(String title, {String description = ''});
  
  /// 리튼 업데이트
  Future<Litten> updateLitten(Litten litten);
  
  /// 리튼 삭제
  Future<bool> deleteLitten(String id);
  
  /// 리튼에 오디오 파일 추가
  Future<Litten> addAudioFileToLitten(String littenId, String audioFileId);
  
  /// 리튼에서 오디오 파일 제거
  Future<Litten> removeAudioFileFromLitten(String littenId, String audioFileId);
  
  /// 리튼에 텍스트 파일 추가
  Future<Litten> addTextFileToLitten(String littenId, String textFileId);
  
  /// 리튼에서 텍스트 파일 제거
  Future<Litten> removeTextFileFromLitten(String littenId, String textFileId);
  
  /// 리튼에 드로잉 파일 추가
  Future<Litten> addDrawingFileToLitten(String littenId, String drawingFileId);
  
  /// 리튼에서 드로잉 파일 제거
  Future<Litten> removeDrawingFileFromLitten(String littenId, String drawingFileId);
  
  /// 리튼의 모든 오디오 파일 조회
  Future<List<AudioFile>> getAudioFilesByLittenId(String littenId);
  
  /// 리튼의 모든 텍스트 파일 조회
  Future<List<TextFile>> getTextFilesByLittenId(String littenId);
  
  /// 리튼의 모든 드로잉 파일 조회
  Future<List<DrawingFile>> getDrawingFilesByLittenId(String littenId);
  
  /// 구독 제한 확인
  Future<bool> canCreateLitten();
  
  /// 사용 통계 조회
  Future<LittenUsageStats> getUsageStats();
}

/// 리튼 서비스 구현체
class LittenServiceImpl implements LittenService {
  final LittenRepository _repository;
  
  LittenServiceImpl(this._repository);
  
  @override
  Future<List<Litten>> getAllLittens() async {
    AppConfig.logDebug('LittenServiceImpl.getAllLittens - 리튼 목록 조회 시작');
    
    try {
      final littens = await _repository.findAll();
      AppConfig.logInfo('LittenServiceImpl.getAllLittens - 리튼 ${littens.length}개 조회 완료');
      return littens;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.getAllLittens - 리튼 조회 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten?> getLittenById(String id) async {
    AppConfig.logDebug('LittenServiceImpl.getLittenById - ID: $id');
    
    try {
      final litten = await _repository.findById(id);
      if (litten != null) {
        AppConfig.logInfo('LittenServiceImpl.getLittenById - 리튼 조회 성공: ${litten.title}');
      } else {
        AppConfig.logWarning('LittenServiceImpl.getLittenById - 리튼을 찾을 수 없음: $id');
      }
      return litten;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.getLittenById - 리튼 조회 실패: $id', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> createLitten(String title, {String description = ''}) async {
    AppConfig.logDebug('LittenServiceImpl.createLitten - 제목: $title');
    
    try {
      // 구독 제한 확인
      final canCreate = await canCreateLitten();
      if (!canCreate) {
        throw LittenServiceException('리튼 생성 한도에 달했습니다. 프리미엄으로 업그레이드하세요.');
      }
      
      final litten = Litten(
        title: title,
        description: description,
      );
      
      final createdLitten = await _repository.create(litten);
      AppConfig.logInfo('LittenServiceImpl.createLitten - 리튼 생성 성공: ${createdLitten.id}');
      
      return createdLitten;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.createLitten - 리튼 생성 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> updateLitten(Litten litten) async {
    AppConfig.logDebug('LittenServiceImpl.updateLitten - ID: ${litten.id}');
    
    try {
      final updatedLitten = await _repository.update(litten);
      AppConfig.logInfo('LittenServiceImpl.updateLitten - 리튼 업데이트 성공: ${updatedLitten.title}');
      return updatedLitten;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.updateLitten - 리튼 업데이트 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<bool> deleteLitten(String id) async {
    AppConfig.logDebug('LittenServiceImpl.deleteLitten - ID: $id');
    
    try {
      final result = await _repository.delete(id);
      if (result) {
        AppConfig.logInfo('LittenServiceImpl.deleteLitten - 리튼 삭제 성공: $id');
      } else {
        AppConfig.logWarning('LittenServiceImpl.deleteLitten - 리튼 삭제 실패: $id');
      }
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.deleteLitten - 리튼 삭제 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> addAudioFileToLitten(String littenId, String audioFileId) async {
    AppConfig.logDebug('LittenServiceImpl.addAudioFileToLitten - 리튼: $littenId, 오디오: $audioFileId');
    
    try {
      final litten = await getLittenById(littenId);
      if (litten == null) {
        throw LittenServiceException('리튼을 찾을 수 없습니다: $littenId');
      }
      
      final updatedLitten = litten.copyWith(
        audioFileIds: [...litten.audioFileIds, audioFileId],
      );
      
      final result = await updateLitten(updatedLitten);
      AppConfig.logInfo('LittenServiceImpl.addAudioFileToLitten - 오디오 파일 추가 성공');
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.addAudioFileToLitten - 오디오 파일 추가 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> removeAudioFileFromLitten(String littenId, String audioFileId) async {
    AppConfig.logDebug('LittenServiceImpl.removeAudioFileFromLitten - 리튼: $littenId, 오디오: $audioFileId');
    
    try {
      final litten = await getLittenById(littenId);
      if (litten == null) {
        throw LittenServiceException('리튼을 찾을 수 없습니다: $littenId');
      }
      
      final updatedLitten = litten.copyWith(
        audioFileIds: litten.audioFileIds.where((id) => id != audioFileId).toList(),
      );
      
      final result = await updateLitten(updatedLitten);
      AppConfig.logInfo('LittenServiceImpl.removeAudioFileFromLitten - 오디오 파일 제거 성공');
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.removeAudioFileFromLitten - 오디오 파일 제거 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> addTextFileToLitten(String littenId, String textFileId) async {
    AppConfig.logDebug('LittenServiceImpl.addTextFileToLitten - 리튼: $littenId, 텍스트: $textFileId');
    
    try {
      final litten = await getLittenById(littenId);
      if (litten == null) {
        throw LittenServiceException('리튼을 찾을 수 없습니다: $littenId');
      }
      
      final updatedLitten = litten.copyWith(
        textFileIds: [...litten.textFileIds, textFileId],
      );
      
      final result = await updateLitten(updatedLitten);
      AppConfig.logInfo('LittenServiceImpl.addTextFileToLitten - 텍스트 파일 추가 성공');
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.addTextFileToLitten - 텍스트 파일 추가 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> removeTextFileFromLitten(String littenId, String textFileId) async {
    AppConfig.logDebug('LittenServiceImpl.removeTextFileFromLitten - 리튼: $littenId, 텍스트: $textFileId');
    
    try {
      final litten = await getLittenById(littenId);
      if (litten == null) {
        throw LittenServiceException('리튼을 찾을 수 없습니다: $littenId');
      }
      
      final updatedLitten = litten.copyWith(
        textFileIds: litten.textFileIds.where((id) => id != textFileId).toList(),
      );
      
      final result = await updateLitten(updatedLitten);
      AppConfig.logInfo('LittenServiceImpl.removeTextFileFromLitten - 텍스트 파일 제거 성공');
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.removeTextFileFromLitten - 텍스트 파일 제거 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> addDrawingFileToLitten(String littenId, String drawingFileId) async {
    AppConfig.logDebug('LittenServiceImpl.addDrawingFileToLitten - 리튼: $littenId, 드로잉: $drawingFileId');
    
    try {
      final litten = await getLittenById(littenId);
      if (litten == null) {
        throw LittenServiceException('리튼을 찾을 수 없습니다: $littenId');
      }
      
      final updatedLitten = litten.copyWith(
        drawingFileIds: [...litten.drawingFileIds, drawingFileId],
      );
      
      final result = await updateLitten(updatedLitten);
      AppConfig.logInfo('LittenServiceImpl.addDrawingFileToLitten - 드로잉 파일 추가 성공');
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.addDrawingFileToLitten - 드로잉 파일 추가 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<Litten> removeDrawingFileFromLitten(String littenId, String drawingFileId) async {
    AppConfig.logDebug('LittenServiceImpl.removeDrawingFileFromLitten - 리튼: $littenId, 드로잉: $drawingFileId');
    
    try {
      final litten = await getLittenById(littenId);
      if (litten == null) {
        throw LittenServiceException('리튼을 찾을 수 없습니다: $littenId');
      }
      
      final updatedLitten = litten.copyWith(
        drawingFileIds: litten.drawingFileIds.where((id) => id != drawingFileId).toList(),
      );
      
      final result = await updateLitten(updatedLitten);
      AppConfig.logInfo('LittenServiceImpl.removeDrawingFileFromLitten - 드로잉 파일 제거 성공');
      return result;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.removeDrawingFileFromLitten - 드로잉 파일 제거 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<List<AudioFile>> getAudioFilesByLittenId(String littenId) async {
    AppConfig.logDebug('LittenServiceImpl.getAudioFilesByLittenId - 리튼: $littenId');
    
    try {
      final audioFiles = await _repository.getAudioFilesByLittenId(littenId);
      AppConfig.logInfo('LittenServiceImpl.getAudioFilesByLittenId - 오디오 파일 ${audioFiles.length}개 조회');
      return audioFiles;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.getAudioFilesByLittenId - 오디오 파일 조회 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<List<TextFile>> getTextFilesByLittenId(String littenId) async {
    AppConfig.logDebug('LittenServiceImpl.getTextFilesByLittenId - 리튼: $littenId');
    
    try {
      final textFiles = await _repository.getTextFilesByLittenId(littenId);
      AppConfig.logInfo('LittenServiceImpl.getTextFilesByLittenId - 텍스트 파일 ${textFiles.length}개 조회');
      return textFiles;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.getTextFilesByLittenId - 텍스트 파일 조회 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<List<DrawingFile>> getDrawingFilesByLittenId(String littenId) async {
    AppConfig.logDebug('LittenServiceImpl.getDrawingFilesByLittenId - 리튼: $littenId');
    
    try {
      final drawingFiles = await _repository.getDrawingFilesByLittenId(littenId);
      AppConfig.logInfo('LittenServiceImpl.getDrawingFilesByLittenId - 드로잉 파일 ${drawingFiles.length}개 조회');
      return drawingFiles;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.getDrawingFilesByLittenId - 드로잉 파일 조회 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<bool> canCreateLitten() async {
    AppConfig.logDebug('LittenServiceImpl.canCreateLitten - 리튼 생성 가능 여부 확인');
    
    try {
      final stats = await getUsageStats();
      final userSettings = await _repository.getUserSettings();
      
      if (userSettings.subscriptionTier != SubscriptionTier.free) {
        AppConfig.logInfo('LittenServiceImpl.canCreateLitten - 유료 사용자 - 생성 가능');
        return true;
      }
      
      final canCreate = stats.littenCount < userSettings.subscriptionTier.maxLittens;
      AppConfig.logInfo('LittenServiceImpl.canCreateLitten - 무료 사용자 - 생성 가능: $canCreate (${stats.littenCount}/${userSettings.subscriptionTier.maxLittens})');
      
      return canCreate;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.canCreateLitten - 확인 실패', error, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<LittenUsageStats> getUsageStats() async {
    AppConfig.logDebug('LittenServiceImpl.getUsageStats - 사용 통계 조회');
    
    try {
      final stats = await _repository.getUsageStats();
      AppConfig.logInfo('LittenServiceImpl.getUsageStats - 통계 조회 성공: 리튼 ${stats.littenCount}개');
      return stats;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenServiceImpl.getUsageStats - 통계 조회 실패', error, stackTrace);
      rethrow;
    }
  }
}

/// 리튼 저장소 인터페이스 - Clean Architecture의 Interface
abstract class LittenRepository {
  Future<List<Litten>> findAll();
  Future<Litten?> findById(String id);
  Future<Litten> create(Litten litten);
  Future<Litten> update(Litten litten);
  Future<bool> delete(String id);
  
  Future<List<AudioFile>> getAudioFilesByLittenId(String littenId);
  Future<List<TextFile>> getTextFilesByLittenId(String littenId);
  Future<List<DrawingFile>> getDrawingFilesByLittenId(String littenId);
  
  Future<UserSettings> getUserSettings();
  Future<LittenUsageStats> getUsageStats();
}

/// 리튼 사용 통계
class LittenUsageStats {
  final int littenCount;
  final int audioFileCount;
  final int textFileCount;
  final int drawingFileCount;
  final int totalFileCount;
  
  const LittenUsageStats({
    this.littenCount = 0,
    this.audioFileCount = 0,
    this.textFileCount = 0,
    this.drawingFileCount = 0,
  }) : totalFileCount = audioFileCount + textFileCount + drawingFileCount;
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'littenCount': littenCount,
      'audioFileCount': audioFileCount,
      'textFileCount': textFileCount,
      'drawingFileCount': drawingFileCount,
      'totalFileCount': totalFileCount,
    };
  }
  
  /// JSON에서 생성
  factory LittenUsageStats.fromJson(Map<String, dynamic> json) {
    return LittenUsageStats(
      littenCount: json['littenCount'] ?? 0,
      audioFileCount: json['audioFileCount'] ?? 0,
      textFileCount: json['textFileCount'] ?? 0,
      drawingFileCount: json['drawingFileCount'] ?? 0,
    );
  }
}

/// 리튼 서비스 예외
class LittenServiceException implements Exception {
  final String message;
  final Object? cause;
  
  const LittenServiceException(this.message, [this.cause]);
  
  @override
  String toString() => 'LittenServiceException: $message';
}