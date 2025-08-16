/// 음성-텍스트 동기화 Use Case
/// 
/// 핵심 기능: 음성 재생 중 텍스트 작성 시 해당 위치를 기록하고 
/// 나중에 텍스트 클릭 시 해당 위치부터 재생
class AudioTextSyncUseCase {
  // 현재 재생 중인 오디오 위치 (초)
  double? _currentAudioPosition;
  
  // 오디오 파일 ID
  String? _currentAudioFileId;
  
  /// 오디오 재생 시작 시 호출
  void startAudioSync(String audioFileId) {
    _currentAudioFileId = audioFileId;
    _currentAudioPosition = 0.0;
  }
  
  /// 오디오 위치 업데이트
  void updateAudioPosition(double position) {
    _currentAudioPosition = position;
  }
  
  /// 텍스트 작성 시 현재 오디오 위치 반환
  AudioSyncData? captureCurrentPosition() {
    if (_currentAudioFileId == null || _currentAudioPosition == null) {
      return null;
    }
    
    return AudioSyncData(
      audioFileId: _currentAudioFileId!,
      position: _currentAudioPosition!,
      timestamp: DateTime.now(),
    );
  }
  
  /// 동기화 중지
  void stopAudioSync() {
    _currentAudioFileId = null;
    _currentAudioPosition = null;
  }
  
  /// 동기화 활성 상태 확인
  bool get isSyncActive => _currentAudioFileId != null;
  
  /// 현재 오디오 위치 반환
  double? get currentPosition => _currentAudioPosition;
  
  /// 현재 오디오 파일 ID 반환
  String? get currentAudioFileId => _currentAudioFileId;
}

/// 오디오-텍스트 동기화 데이터
class AudioSyncData {
  final String audioFileId;
  final double position; // 초 단위
  final DateTime timestamp;
  
  AudioSyncData({
    required this.audioFileId,
    required this.position,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'audioFileId': audioFileId,
      'position': position,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory AudioSyncData.fromJson(Map<String, dynamic> json) {
    return AudioSyncData(
      audioFileId: json['audioFileId'],
      position: json['position'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}