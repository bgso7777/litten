import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/models/litten.dart';
import '../../services/models/audio_file.dart';
import '../../services/models/text_file.dart';
import '../../services/models/drawing_file.dart';
import '../../services/domain/litten_service.dart';

/// 리튼 관리 Provider
class LittenProvider with ChangeNotifier {
  final LittenService _littenService;
  
  List<Litten> _littens = [];
  Litten? _selectedLitten;
  bool _isLoading = false;
  String? _errorMessage;
  LittenUsageStats? _usageStats;
  
  LittenProvider(this._littenService) {
    _initializeProvider();
  }
  
  /// Getters
  List<Litten> get littens => _littens;
  Litten? get selectedLitten => _selectedLitten;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LittenUsageStats? get usageStats => _usageStats;
  bool get hasSelectedLitten => _selectedLitten != null;
  
  /// 프로바이더 초기화
  Future<void> _initializeProvider() async {
    AppConfig.logDebug('LittenProvider._initializeProvider - 프로바이더 초기화 시작');
    
    await loadLittens();
    await loadUsageStats();
  }
  
  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// 에러 상태 설정
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  /// 모든 리튼 로드
  Future<void> loadLittens() async {
    AppConfig.logDebug('LittenProvider.loadLittens - 리튼 목록 로드 시작');
    
    _setLoading(true);
    _setError(null);
    
    try {
      _littens = await _littenService.getAllLittens();
      
      // 선택된 리튼이 삭제된 경우 처리
      if (_selectedLitten != null && 
          !_littens.any((litten) => litten.id == _selectedLitten!.id)) {
        _selectedLitten = null;
      }
      
      AppConfig.logInfo('LittenProvider.loadLittens - 리튼 ${_littens.length}개 로드 완료');
      notifyListeners();
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.loadLittens - 리튼 로드 실패', error, stackTrace);
      _setError('리튼 목록을 불러오는데 실패했습니다: ${error.toString()}');
    } finally {
      _setLoading(false);
    }
  }
  
  /// 리튼 생성
  Future<Litten?> createLitten(String title, {String description = ''}) async {
    AppConfig.logDebug('LittenProvider.createLitten - 리튼 생성: $title');
    
    if (title.trim().isEmpty) {
      _setError('리튼 제목을 입력해주세요.');
      return null;
    }
    
    _setLoading(true);
    _setError(null);
    
    try {
      // 생성 가능 여부 확인
      final canCreate = await _littenService.canCreateLitten();
      if (!canCreate) {
        _setError('리튼 생성 한도에 달했습니다. 프리미엄으로 업그레이드하세요.');
        return null;
      }
      
      final newLitten = await _littenService.createLitten(title.trim(), description: description);
      _littens.add(newLitten);
      
      // 새로 생성된 리튼 선택
      await selectLitten(newLitten);
      
      // 사용 통계 업데이트
      await loadUsageStats();
      
      AppConfig.logInfo('LittenProvider.createLitten - 리튼 생성 완료: ${newLitten.title}');
      notifyListeners();
      
      return newLitten;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.createLitten - 리튼 생성 실패', error, stackTrace);
      _setError('리튼 생성에 실패했습니다: ${error.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 리튼 선택
  Future<void> selectLitten(Litten litten) async {
    AppConfig.logDebug('LittenProvider.selectLitten - 리튼 선택: ${litten.title}');
    
    if (_selectedLitten?.id == litten.id) {
      AppConfig.logDebug('LittenProvider.selectLitten - 이미 선택된 리튼');
      return;
    }
    
    _selectedLitten = litten;
    AppConfig.logInfo('LittenProvider.selectLitten - 리튼 선택 완료: ${litten.title}');
    notifyListeners();
  }
  
  /// 리튼 선택 해제
  void unselectLitten() {
    AppConfig.logDebug('LittenProvider.unselectLitten - 리튼 선택 해제');
    
    if (_selectedLitten == null) return;
    
    _selectedLitten = null;
    AppConfig.logInfo('LittenProvider.unselectLitten - 리튼 선택 해제 완료');
    notifyListeners();
  }
  
  /// 리튼 업데이트
  Future<bool> updateLitten(Litten updatedLitten) async {
    AppConfig.logDebug('LittenProvider.updateLitten - 리튼 업데이트: ${updatedLitten.title}');
    
    _setLoading(true);
    _setError(null);
    
    try {
      final result = await _littenService.updateLitten(updatedLitten);
      
      // 로컬 리스트 업데이트
      final index = _littens.indexWhere((litten) => litten.id == result.id);
      if (index >= 0) {
        _littens[index] = result;
      }
      
      // 선택된 리튼 업데이트
      if (_selectedLitten?.id == result.id) {
        _selectedLitten = result;
      }
      
      AppConfig.logInfo('LittenProvider.updateLitten - 리튼 업데이트 완료: ${result.title}');
      notifyListeners();
      
      return true;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.updateLitten - 리튼 업데이트 실패', error, stackTrace);
      _setError('리튼 업데이트에 실패했습니다: ${error.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 리튼 삭제
  Future<bool> deleteLitten(String littenId) async {
    AppConfig.logDebug('LittenProvider.deleteLitten - 리튼 삭제: $littenId');
    
    _setLoading(true);
    _setError(null);
    
    try {
      final success = await _littenService.deleteLitten(littenId);
      
      if (success) {
        // 로컬 리스트에서 제거
        _littens.removeWhere((litten) => litten.id == littenId);
        
        // 선택된 리튼이 삭제된 경우 선택 해제
        if (_selectedLitten?.id == littenId) {
          _selectedLitten = null;
        }
        
        // 사용 통계 업데이트
        await loadUsageStats();
        
        AppConfig.logInfo('LittenProvider.deleteLitten - 리튼 삭제 완료: $littenId');
        notifyListeners();
      }
      
      return success;
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.deleteLitten - 리튼 삭제 실패', error, stackTrace);
      _setError('리튼 삭제에 실패했습니다: ${error.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 오디오 파일 추가
  Future<bool> addAudioFileToLitten(String littenId, String audioFileId) async {
    AppConfig.logDebug('LittenProvider.addAudioFileToLitten - 오디오 파일 추가: $littenId, $audioFileId');
    
    try {
      final updatedLitten = await _littenService.addAudioFileToLitten(littenId, audioFileId);
      return await updateLitten(updatedLitten);
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.addAudioFileToLitten - 오디오 파일 추가 실패', error, stackTrace);
      _setError('오디오 파일 추가에 실패했습니다: ${error.toString()}');
      return false;
    }
  }
  
  /// 텍스트 파일 추가
  Future<bool> addTextFileToLitten(String littenId, String textFileId) async {
    AppConfig.logDebug('LittenProvider.addTextFileToLitten - 텍스트 파일 추가: $littenId, $textFileId');
    
    try {
      final updatedLitten = await _littenService.addTextFileToLitten(littenId, textFileId);
      return await updateLitten(updatedLitten);
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.addTextFileToLitten - 텍스트 파일 추가 실패', error, stackTrace);
      _setError('텍스트 파일 추가에 실패했습니다: ${error.toString()}');
      return false;
    }
  }
  
  /// 드로잉 파일 추가
  Future<bool> addDrawingFileToLitten(String littenId, String drawingFileId) async {
    AppConfig.logDebug('LittenProvider.addDrawingFileToLitten - 드로잉 파일 추가: $littenId, $drawingFileId');
    
    try {
      final updatedLitten = await _littenService.addDrawingFileToLitten(littenId, drawingFileId);
      return await updateLitten(updatedLitten);
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.addDrawingFileToLitten - 드로잉 파일 추가 실패', error, stackTrace);
      _setError('드로잉 파일 추가에 실패했습니다: ${error.toString()}');
      return false;
    }
  }
  
  /// 사용 통계 로드
  Future<void> loadUsageStats() async {
    AppConfig.logDebug('LittenProvider.loadUsageStats - 사용 통계 로드');
    
    try {
      _usageStats = await _littenService.getUsageStats();
      AppConfig.logInfo('LittenProvider.loadUsageStats - 사용 통계 로드 완료: 리튼 ${_usageStats!.littenCount}개');
      notifyListeners();
    } catch (error, stackTrace) {
      AppConfig.logError('LittenProvider.loadUsageStats - 사용 통계 로드 실패', error, stackTrace);
    }
  }
  
  /// 에러 클리어
  void clearError() {
    if (_errorMessage != null) {
      _setError(null);
    }
  }
  
  /// 새로고침
  Future<void> refresh() async {
    AppConfig.logDebug('LittenProvider.refresh - 새로고침');
    
    await Future.wait([
      loadLittens(),
      loadUsageStats(),
    ]);
  }
}