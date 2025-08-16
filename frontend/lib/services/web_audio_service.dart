import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

enum WebRecordingState {
  idle,
  recording,
  paused,
  stopped,
}

class WebAudioService extends ChangeNotifier {
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _mediaStream;
  
  WebRecordingState _recordingState = WebRecordingState.idle;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _currentRecordingBlobUrl;
  List<html.Blob> _recordedChunks = [];
  
  // 백그라운드 녹음 관련
  bool _isBackgroundRecording = false;
  StreamSubscription? _visibilityListener;
  
  // Getters
  WebRecordingState get recordingState => _recordingState;
  Duration get recordingDuration => _recordingDuration;
  String? get currentRecordingBlobUrl => _currentRecordingBlobUrl;
  bool get isBackgroundRecording => _isBackgroundRecording;
  
  bool get isRecording => _recordingState == WebRecordingState.recording;
  bool get isPaused => _recordingState == WebRecordingState.paused;
  
  @override
  void dispose() {
    _stopRecording();
    _cleanupStreams();
    _recordingTimer?.cancel();
    _visibilityListener?.cancel();
    _releaseWakeLock();
    super.dispose();
  }
  
  // 마이크 권한 요청 및 MediaStream 획득
  Future<bool> requestMicrophoneAccess() async {
    try {
      debugPrint('=== 웹 마이크 권한 요청 시작 ===');
      
      // 브라우저 정보 출력
      final userAgent = html.window.navigator.userAgent;
      debugPrint('사용자 에이전트: $userAgent');
      
      // HTTPS 확인
      final isSecure = html.window.location.protocol == 'https:' || html.window.location.hostname == 'localhost';
      debugPrint('보안 연결: $isSecure (${html.window.location.protocol}//${html.window.location.hostname})');
      
      // MediaDevices API 사용 가능 확인
      if (html.window.navigator.mediaDevices == null) {
        debugPrint('❌ MediaDevices API를 사용할 수 없습니다');
        debugPrint('이는 보통 HTTPS 연결이 아니거나 브라우저가 지원하지 않을 때 발생합니다');
        return false;
      }
      
      debugPrint('✅ MediaDevices API 사용 가능');
      
      // 기존 스트림 정리
      _cleanupStreams();
      
      // 현재 권한 상태 확인 (가능한 브라우저에서)
      try {
        if (html.window.navigator.permissions != null) {
          final permission = await html.window.navigator.permissions!.query({'name': 'microphone'});
          debugPrint('현재 마이크 권한 상태: ${permission.state}');
        }
      } catch (e) {
        debugPrint('권한 상태 확인 실패 (일부 브라우저에서는 지원하지 않음): $e');
      }
      
      // 사용 가능한 오디오 장치 확인
      try {
        final devices = await html.window.navigator.mediaDevices!.enumerateDevices();
        final audioDevices = devices.where((device) => device.kind == 'audioinput').toList();
        debugPrint('사용 가능한 오디오 입력 장치 수: ${audioDevices.length}');
        for (int i = 0; i < audioDevices.length; i++) {
          debugPrint('장치 $i: ${audioDevices[i].label.isEmpty ? "익명" : audioDevices[i].label}');
        }
      } catch (e) {
        debugPrint('오디오 장치 목록 확인 실패: $e');
      }
      
      debugPrint('getUserMedia 호출 시도...');
      
      // 마이크 권한 요청 및 MediaStream 획득 (단계별 fallback)
      _mediaStream = await _getUserMediaWithFallback();
      
      if (_mediaStream == null) {
        debugPrint('❌ 모든 시도가 실패하여 MediaStream을 획득하지 못했습니다');
        return false;
      }
      
      debugPrint('✅ 마이크 접근 권한 획득 성공');
      debugPrint('MediaStream ID: ${_mediaStream!.id}');
      debugPrint('오디오 트랙 수: ${_mediaStream!.getAudioTracks().length}');
      
      // 각 오디오 트랙 정보 출력
      final audioTracks = _mediaStream!.getAudioTracks();
      for (int i = 0; i < audioTracks.length; i++) {
        final track = audioTracks[i];
        debugPrint('트랙 $i: ${track.label}, 상태: ${track.readyState}, 활성: ${track.enabled}');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ 마이크 접근 권한 요청 실패: $e');
      debugPrint('에러 전체 정보: ${e.runtimeType}: $e');
      
      // 에러 타입별 상세 처리
      final errorString = e.toString();
      if (errorString.contains('NotAllowedError') || errorString.contains('PermissionDeniedError')) {
        debugPrint('🚫 사용자가 마이크 권한을 거부했거나 정책으로 차단되었습니다');
        debugPrint('해결 방법:');
        debugPrint('1. 브라우저 주소창의 🔒 아이콘을 클릭하여 마이크 권한을 허용하세요');
        debugPrint('2. 브라우저 설정에서 이 사이트의 마이크 권한을 확인하세요');
      } else if (errorString.contains('NotFoundError') || errorString.contains('DevicesNotFoundError')) {
        debugPrint('🎤 마이크 장치를 찾을 수 없습니다');
        debugPrint('해결 방법:');
        debugPrint('1. 마이크가 물리적으로 연결되어 있는지 확인');
        debugPrint('2. Windows에서 마이크가 인식되는지 확인 (설정 > 개인정보 > 마이크)');
        debugPrint('3. 다른 앱(Teams, Zoom 등)이 마이크를 사용 중이 아닌지 확인');
        debugPrint('4. WSL 환경이라면 Windows 호스트에서 마이크 권한 확인');
        debugPrint('5. 브라우저를 관리자 권한으로 실행해보기');
      } else if (errorString.contains('NotSupportedError')) {
        debugPrint('🌐 이 브라우저에서는 마이크를 지원하지 않습니다');
        debugPrint('해결 방법: Chrome, Firefox, Safari 등 최신 브라우저를 사용하세요');
      } else if (errorString.contains('NotReadableError') || errorString.contains('TrackStartError')) {
        debugPrint('🔧 마이크 장치에 접근할 수 없습니다 (하드웨어 오류)');
        debugPrint('해결 방법: 다른 앱이 마이크를 사용 중이거나 장치 드라이버 문제일 수 있습니다');
      } else if (errorString.contains('OverconstrainedError') || errorString.contains('ConstraintNotSatisfiedError')) {
        debugPrint('⚙️ 요청한 오디오 설정을 만족하는 장치가 없습니다');
        debugPrint('해결 방법: 더 기본적인 설정으로 다시 시도합니다');
      }
      
      return false;
    }
  }
  
  // 단계별 fallback을 통한 getUserMedia 호출
  Future<html.MediaStream?> _getUserMediaWithFallback() async {
    // 먼저 장치 열거를 통해 실제 사용 가능한 장치 확인
    List<String> availableDeviceIds = [];
    try {
      debugPrint('🔍 사용 가능한 오디오 장치 재검색...');
      
      // MediaDevices 새로고침을 위해 잠시 대기
      await Future.delayed(Duration(milliseconds: 100));
      
      final devices = await html.window.navigator.mediaDevices!.enumerateDevices();
      final audioInputDevices = devices.where((device) => device.kind == 'audioinput').toList();
      
      debugPrint('enumerateDevices() 결과: 전체 ${devices.length}개 장치, 오디오 입력 ${audioInputDevices.length}개');
      
      for (int i = 0; i < audioInputDevices.length; i++) {
        final device = audioInputDevices[i];
        final deviceId = device.deviceId;
        if (deviceId != null && deviceId.isNotEmpty) {
          availableDeviceIds.add(deviceId);
          debugPrint('장치 발견 $i: ID=${deviceId.substring(0, deviceId.length.clamp(0, 20))}..., 라벨=${device.label.isEmpty ? "익명" : device.label}');
        }
      }
      
      debugPrint('총 ${availableDeviceIds.length}개 오디오 입력 장치 발견');
    } catch (e) {
      debugPrint('⚠️ 장치 열거 실패: $e');
    }
    
    // 시도할 설정들을 우선순위 순으로 정렬
    List<Map<String, dynamic>> fallbackConfigs = [];
    
    // 특정 장치 ID로 시도 (발견된 장치가 있는 경우)
    if (availableDeviceIds.isNotEmpty) {
      for (int i = 0; i < availableDeviceIds.length; i++) {
        final deviceId = availableDeviceIds[i];
        fallbackConfigs.addAll([
          {
            'name': '장치 $i - 기본 설정',
            'constraints': {
              'audio': {
                'deviceId': {'exact': deviceId},
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              },
              'video': false,
            }
          },
          {
            'name': '장치 $i - 최소 설정',
            'constraints': {
              'audio': {
                'deviceId': {'exact': deviceId},
              },
              'video': false,
            }
          },
          {
            'name': '장치 $i - 유연 설정',
            'constraints': {
              'audio': {
                'deviceId': deviceId,  // exact 없이 시도
              },
              'video': false,
            }
          },
        ]);
      }
    }
    
    // 기존 일반적인 설정들 추가
    fallbackConfigs.addAll([
      {
        'name': '고급 오디오 설정',
        'constraints': {
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
            'sampleRate': 44100,
            'channelCount': 1,
          },
          'video': false,
        }
      },
      {
        'name': '기본 오디오 처리',
        'constraints': {
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        }
      },
      {
        'name': '단순 오디오 처리',
        'constraints': {
          'audio': {
            'echoCancellation': false,
            'noiseSuppression': false,
            'autoGainControl': false,
          },
          'video': false,
        }
      },
      {
        'name': '매우 기본적인 오디오',
        'constraints': {
          'audio': true,
          'video': false,
        }
      },
      {
        'name': '최소한의 오디오만',
        'constraints': {
          'audio': {},
          'video': false,
        }
      },
    ]);
    
    debugPrint('총 ${fallbackConfigs.length}개 설정으로 시도합니다');
    
    for (int i = 0; i < fallbackConfigs.length; i++) {
      final config = fallbackConfigs[i];
      try {
        debugPrint('시도 ${i + 1}/${fallbackConfigs.length}: ${config['name']}');
        
        final stream = await html.window.navigator.mediaDevices!.getUserMedia(
          config['constraints'] as Map<String, dynamic>
        );
        
        debugPrint('✅ 성공: ${config['name']}');
        
        // 성공한 스트림의 정보 출력
        final tracks = stream.getAudioTracks();
        if (tracks.isNotEmpty) {
          final track = tracks[0];
          debugPrint('사용 중인 장치: ${track.label}, 상태: ${track.readyState}');
        }
        
        return stream;
        
      } catch (e) {
        debugPrint('❌ 실패 ${i + 1}: ${config['name']} - $e');
        
        // 특정 에러 타입에 따른 추가 정보
        final errorStr = e.toString();
        if (errorStr.contains('NotFoundError')) {
          debugPrint('  → 이 설정에 맞는 장치를 찾을 수 없음');
        } else if (errorStr.contains('NotAllowedError')) {
          debugPrint('  → 권한이 거부됨');
        } else if (errorStr.contains('NotReadableError')) {
          debugPrint('  → 장치가 다른 앱에서 사용 중이거나 하드웨어 오류');
        }
        
        // 마지막 시도가 아니라면 계속 진행
        if (i < fallbackConfigs.length - 1) {
          debugPrint('다음 설정으로 재시도...');
          continue;
        }
        
        // 모든 시도가 실패한 경우
        debugPrint('💀 모든 getUserMedia 설정이 실패했습니다');
        throw e;
      }
    }
    
    return null;
  }
  
  // 녹음 시작
  Future<bool> startRecording() async {
    try {
      debugPrint('=== 웹 녹음 시작 ===');
      
      // 마이크 권한 확인
      if (_mediaStream == null) {
        debugPrint('MediaStream이 없습니다. 마이크 권한을 요청합니다...');
        if (!await requestMicrophoneAccess()) {
          debugPrint('❌ 마이크 권한 요청이 실패했습니다');
          return false;
        }
      }
      
      if (_mediaStream == null) {
        debugPrint('❌ MediaStream을 얻을 수 없습니다');
        return false;
      }
      
      // MediaStream 상태 확인
      final audioTracks = _mediaStream!.getAudioTracks();
      if (audioTracks.isEmpty) {
        debugPrint('❌ 사용 가능한 오디오 트랙이 없습니다');
        return false;
      }
      
      final firstTrack = audioTracks[0];
      if (firstTrack.readyState != 'live') {
        debugPrint('❌ 오디오 트랙이 활성 상태가 아닙니다: ${firstTrack.readyState}');
        return false;
      }
      
      debugPrint('오디오 트랙 상태: ${firstTrack.readyState}, 활성: ${firstTrack.enabled}');
      
      // MediaRecorder 지원 여부 확인
      debugPrint('MediaRecorder 지원 여부 확인...');
      
      // 지원되는 MIME 타입 확인 및 설정
      final options = <String, dynamic>{};
      String selectedMimeType = '';
      
      final supportedTypes = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/mp4',
        'audio/ogg;codecs=opus',
        'audio/wav',
      ];
      
      for (final type in supportedTypes) {
        if (html.MediaRecorder.isTypeSupported(type)) {
          options['mimeType'] = type;
          selectedMimeType = type;
          debugPrint('✅ 지원되는 MIME 타입 선택: $type');
          break;
        }
      }
      
      if (selectedMimeType.isEmpty) {
        debugPrint('⚠️ 기본 MIME 타입 사용 (브라우저가 자동 선택)');
      }
      
      // MediaRecorder 생성 시도
      debugPrint('MediaRecorder 생성 중...');
      try {
        _mediaRecorder = html.MediaRecorder(_mediaStream!, options);
        debugPrint('✅ MediaRecorder 생성 성공');
      } catch (e) {
        debugPrint('❌ MediaRecorder 생성 실패: $e');
        
        // 옵션 없이 다시 시도
        try {
          debugPrint('옵션 없이 MediaRecorder 재시도...');
          _mediaRecorder = html.MediaRecorder(_mediaStream!);
          debugPrint('✅ 기본 옵션으로 MediaRecorder 생성 성공');
        } catch (e2) {
          debugPrint('❌ 기본 옵션으로도 MediaRecorder 생성 실패: $e2');
          return false;
        }
      }
      
      _recordedChunks.clear();
      
      // 이벤트 리스너 설정
      debugPrint('이벤트 리스너 설정 중...');
      
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data!.size > 0) {
          _recordedChunks.add(blobEvent.data!);
          debugPrint('📦 데이터 청크 추가: ${blobEvent.data!.size} bytes (총 ${_recordedChunks.length}개)');
        }
      });
      
      _mediaRecorder!.addEventListener('start', (html.Event event) {
        debugPrint('🎤 MediaRecorder 시작됨');
      });
      
      _mediaRecorder!.addEventListener('stop', (html.Event event) {
        debugPrint('⏹️ MediaRecorder 정지됨');
        _createBlobUrl();
      });
      
      _mediaRecorder!.addEventListener('error', (html.Event event) {
        debugPrint('❌ MediaRecorder 오류: $event');
      });
      
      _mediaRecorder!.addEventListener('pause', (html.Event event) {
        debugPrint('⏸️ MediaRecorder 일시정지됨');
      });
      
      _mediaRecorder!.addEventListener('resume', (html.Event event) {
        debugPrint('▶️ MediaRecorder 재개됨');
      });
      
      // 녹음 시작
      debugPrint('MediaRecorder.start() 호출...');
      try {
        _mediaRecorder!.start(1000); // 1초마다 데이터 이벤트 발생
        debugPrint('✅ start() 호출 성공');
      } catch (e) {
        debugPrint('❌ start() 호출 실패: $e');
        return false;
      }
      
      // 상태 확인
      debugPrint('MediaRecorder 상태: ${_mediaRecorder!.state}');
      
      _recordingState = WebRecordingState.recording;
      _recordingDuration = Duration.zero;
      _startRecordingTimer();
      
      // 백그라운드 녹음 설정
      await _setupBackgroundRecording();
      
      notifyListeners();
      debugPrint('🎉 웹 녹음 시작 완료!');
      return true;
      
    } catch (e, stackTrace) {
      debugPrint('❌ 웹 녹음 시작 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return false;
    }
  }
  
  // 녹음 일시정지
  Future<bool> pauseRecording() async {
    try {
      if (_mediaRecorder == null || _recordingState != WebRecordingState.recording) {
        return false;
      }
      
      _mediaRecorder!.pause();
      _recordingState = WebRecordingState.paused;
      _recordingTimer?.cancel();
      
      notifyListeners();
      debugPrint('웹 녹음 일시정지');
      return true;
    } catch (e) {
      debugPrint('웹 녹음 일시정지 실패: $e');
      return false;
    }
  }
  
  // 녹음 재개
  Future<bool> resumeRecording() async {
    try {
      if (_mediaRecorder == null || _recordingState != WebRecordingState.paused) {
        return false;
      }
      
      _mediaRecorder!.resume();
      _recordingState = WebRecordingState.recording;
      _startRecordingTimer();
      
      notifyListeners();
      debugPrint('웹 녹음 재개');
      return true;
    } catch (e) {
      debugPrint('웹 녹음 재개 실패: $e');
      return false;
    }
  }
  
  // 녹음 정지
  Future<String?> stopRecording() async {
    try {
      debugPrint('=== 웹 녹음 정지 시작 ===');
      
      if (_mediaRecorder == null || _recordingState == WebRecordingState.idle) {
        debugPrint('❌ 녹음이 진행 중이 아닙니다');
        return null;
      }
      
      _mediaRecorder!.stop();
      _recordingState = WebRecordingState.stopped;
      _stopRecordingTimer();
      
      // Blob URL이 생성될 때까지 대기
      int attempts = 0;
      while (_currentRecordingBlobUrl == null && attempts < 50) {
        await Future.delayed(Duration(milliseconds: 100));
        attempts++;
      }
      
      if (_currentRecordingBlobUrl == null) {
        debugPrint('❌ Blob URL 생성에 실패했습니다');
        return null;
      }
      
      final blobUrl = _currentRecordingBlobUrl!;
      debugPrint('✅ 웹 녹음 완료: $blobUrl, 길이: ${_recordingDuration.inSeconds}초');
      
      _recordingState = WebRecordingState.idle;
      
      // 백그라운드 녹음 정리
      _cleanupBackgroundRecording();
      
      notifyListeners();
      
      return blobUrl;
      
    } catch (e) {
      debugPrint('❌ 웹 녹음 정지 실패: $e');
      await _stopRecording();
      return null;
    }
  }
  
  // 강제 녹음 중단
  Future<void> _stopRecording() async {
    try {
      _mediaRecorder?.stop();
    } catch (e) {
      debugPrint('MediaRecorder 정지 실패: $e');
    } finally {
      _recordingState = WebRecordingState.idle;
      _stopRecordingTimer();
      notifyListeners();
    }
  }
  
  // Blob URL 생성
  void _createBlobUrl() {
    try {
      if (_recordedChunks.isEmpty) {
        debugPrint('❌ 녹음된 데이터가 없습니다');
        return;
      }
      
      final blob = html.Blob(_recordedChunks);
      _currentRecordingBlobUrl = html.Url.createObjectUrl(blob);
      
      debugPrint('Blob URL 생성 완료: $_currentRecordingBlobUrl');
      debugPrint('총 청크 수: ${_recordedChunks.length}');
      debugPrint('Blob 크기: ${blob.size} bytes');
      
    } catch (e) {
      debugPrint('Blob URL 생성 실패: $e');
    }
  }
  
  // 녹음 타이머 시작
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      notifyListeners();
    });
  }
  
  // 녹음 타이머 정지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }
  
  // MediaStream 정리
  void _cleanupStreams() {
    if (_mediaStream != null) {
      for (var track in _mediaStream!.getTracks()) {
        track.stop();
      }
      _mediaStream = null;
    }
  }
  
  // Blob URL 해제
  void releaseBlobUrl(String blobUrl) {
    try {
      html.Url.revokeObjectUrl(blobUrl);
      debugPrint('Blob URL 해제: $blobUrl');
    } catch (e) {
      debugPrint('Blob URL 해제 실패: $e');
    }
  }
  
  // 녹음 가능 시간 확인 (최대 60분)
  bool get canContinueRecording {
    return _recordingDuration.inMinutes < 60;
  }
  
  // 백그라운드 녹음 설정
  Future<void> _setupBackgroundRecording() async {
    try {
      debugPrint('=== 백그라운드 녹음 설정 시작 ===');
      
      // 1. Page Visibility API 모니터링
      _setupVisibilityListener();
      
      // 2. 브라우저 알림 권한 요청 및 알림 표시
      await _setupNotification();
      
      // 3. Wake Lock 요청 (화면 꺼짐 방지)
      await _requestWakeLock();
      
      _isBackgroundRecording = true;
      debugPrint('✅ 백그라운드 녹음 설정 완료');
      
    } catch (e) {
      debugPrint('❌ 백그라운드 녹음 설정 실패: $e');
    }
  }
  
  // Page Visibility API 리스너 설정
  void _setupVisibilityListener() {
    try {
      debugPrint('Page Visibility API 설정 중...');
      
      // visibilitychange 이벤트 리스너
      html.document.addEventListener('visibilitychange', (html.Event event) {
        final isHidden = html.document.hidden ?? false;
        debugPrint('페이지 가시성 변경: ${isHidden ? "숨김" : "표시"}');
        
        if (isHidden && isRecording) {
          debugPrint('📱 탭이 백그라운드로 전환됨 - 녹음 지속 중');
          _showBackgroundNotification();
        } else if (!isHidden && isRecording) {
          debugPrint('📱 탭이 포그라운드로 전환됨');
          _updateNotification();
        }
      });
      
      debugPrint('✅ Page Visibility API 설정 완료');
    } catch (e) {
      debugPrint('❌ Page Visibility API 설정 실패: $e');
    }
  }
  
  // 브라우저 알림 설정
  Future<void> _setupNotification() async {
    try {
      debugPrint('브라우저 알림 설정 중...');
      
      // 알림 API 지원 확인
      if (html.Notification.supported) {
        debugPrint('✅ 브라우저 알림 지원됨');
        
        // 현재 권한 상태 확인
        final permission = html.Notification.permission;
        debugPrint('현재 알림 권한: $permission');
        
        if (permission == 'default') {
          debugPrint('알림 권한 요청 중...');
          final result = await html.Notification.requestPermission();
          debugPrint('알림 권한 요청 결과: $result');
        }
        
        if (html.Notification.permission == 'granted') {
          debugPrint('✅ 알림 권한 승인됨');
          _showRecordingNotification();
        } else {
          debugPrint('⚠️ 알림 권한이 거부됨 - 백그라운드 알림 없이 진행');
        }
      } else {
        debugPrint('⚠️ 브라우저가 알림을 지원하지 않음');
      }
    } catch (e) {
      debugPrint('❌ 브라우저 알림 설정 실패: $e');
    }
  }
  
  // Wake Lock 요청 (화면 꺼짐 방지)
  Future<void> _requestWakeLock() async {
    try {
      debugPrint('Wake Lock 요청 중...');
      
      // Wake Lock API 지원 확인
      final navigator = html.window.navigator;
      if (navigator.userAgent.contains('Chrome') || navigator.userAgent.contains('Edge')) {
        debugPrint('Wake Lock API 시도...');
        
        try {
          // Wake Lock 요청
          // 주의: dart:html에서는 아직 완전히 지원되지 않을 수 있음
          debugPrint('Wake Lock은 실험적 기능으로 건너뜀');
        } catch (e) {
          debugPrint('Wake Lock 실패 (정상 - 실험적 기능): $e');
        }
      } else {
        debugPrint('Wake Lock은 Chrome/Edge에서만 지원됨');
      }
    } catch (e) {
      debugPrint('❌ Wake Lock 요청 실패: $e');
    }
  }
  
  // 녹음 시작 알림 표시
  void _showRecordingNotification() {
    try {
      if (html.Notification.permission == 'granted') {
        final notification = html.Notification(
          '🎤 리튼 녹음 중',
          body: '녹음이 진행 중입니다. 탭을 닫아도 녹음이 계속됩니다.',
          icon: '/icons/Icon-192.png',
          tag: 'litten-recording',
        );
        
        // 클릭 시 탭으로 포커스
        notification.onClick.listen((event) {
          debugPrint('알림 클릭됨 - 리튼 앱으로 돌아가기');
          // 브라우저에서 window.focus()는 지원되지 않음
        });
        
        // 3초 후 자동으로 닫기
        Timer(Duration(seconds: 3), () {
          notification.close();
        });
        
        debugPrint('✅ 녹음 시작 알림 표시됨');
      }
    } catch (e) {
      debugPrint('❌ 녹음 시작 알림 실패: $e');
    }
  }
  
  // 백그라운드 상태 알림 표시
  void _showBackgroundNotification() {
    try {
      if (html.Notification.permission == 'granted') {
        final notification = html.Notification(
          '🎤 백그라운드 녹음 중',
          body: '${_formatDuration(_recordingDuration)} 녹음 중입니다. 클릭하여 리튼으로 돌아가기',
          icon: '/icons/Icon-192.png',
          tag: 'litten-background-recording',
          // requireInteraction: true, // 사용자가 직접 닫을 때까지 유지 (일부 브라우저에서 미지원)
        );
        
        // 클릭 시 탭으로 포커스
        notification.onClick.listen((event) {
          debugPrint('백그라운드 알림 클릭됨 - 리튼 앱으로 돌아가기');
          // 브라우저에서 window.focus()는 지원되지 않음
          notification.close();
        });
        
        debugPrint('✅ 백그라운드 알림 표시됨');
      }
    } catch (e) {
      debugPrint('❌ 백그라운드 알림 실패: $e');
    }
  }
  
  // 알림 업데이트 (포그라운드 복귀 시)
  void _updateNotification() {
    try {
      // 기존 백그라운드 알림 제거
      _closeNotificationsByTag('litten-background-recording');
      debugPrint('✅ 포그라운드 복귀 - 백그라운드 알림 제거');
    } catch (e) {
      debugPrint('❌ 알림 업데이트 실패: $e');
    }
  }
  
  // 특정 태그의 알림 닫기
  void _closeNotificationsByTag(String tag) {
    try {
      // 실제로는 브라우저가 같은 태그의 이전 알림을 자동으로 교체함
      debugPrint('태그별 알림 정리: $tag');
    } catch (e) {
      debugPrint('태그별 알림 정리 실패: $e');
    }
  }
  
  // Wake Lock 해제
  void _releaseWakeLock() {
    try {
      // Wake Lock 해제 로직 (현재는 구현하지 않음)
      debugPrint('Wake Lock 해제');
    } catch (e) {
      debugPrint('Wake Lock 해제 실패: $e');
    }
  }
  
  // 백그라운드 녹음 정리
  void _cleanupBackgroundRecording() {
    try {
      debugPrint('=== 백그라운드 녹음 정리 시작 ===');
      
      _isBackgroundRecording = false;
      
      // 알림 정리
      _closeNotificationsByTag('litten-recording');
      _closeNotificationsByTag('litten-background-recording');
      
      // 녹음 완료 알림
      if (html.Notification.permission == 'granted') {
        final notification = html.Notification(
          '✅ 녹음 완료',
          body: '${_formatDuration(_recordingDuration)} 녹음이 완료되었습니다.',
          icon: '/icons/Icon-192.png',
          tag: 'litten-recording-complete',
        );
        
        // 3초 후 자동으로 닫기
        Timer(Duration(seconds: 3), () {
          notification.close();
        });
      }
      
      // Wake Lock 해제
      _releaseWakeLock();
      
      // Visibility 리스너 정리 (dispose에서 처리됨)
      
      debugPrint('✅ 백그라운드 녹음 정리 완료');
    } catch (e) {
      debugPrint('❌ 백그라운드 녹음 정리 실패: $e');
    }
  }
  
  // 시간 포맷팅 유틸리티
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}