import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';
import 'local_storage_service.dart';
import 'web_audio_service.dart';

// 웹에서 마이크 권한을 위한 추가 import
import 'dart:html' as html;

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

enum PlaybackState {
  idle,
  playing,
  paused,
  stopped,
}

class AudioService extends ChangeNotifier {
  AudioService();

  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  final LocalStorageService _storageService = LocalStorageService();
  final Uuid _uuid = const Uuid();
  
  // 웹 전용 오디오 서비스
  WebAudioService? _webAudioService;

  // 녹음 상태
  RecordingState _recordingState = RecordingState.idle;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _currentRecordingPath;
  
  // 웹 환경에서 WebAudioService 초기화
  WebAudioService get _webService {
    if (kIsWeb && _webAudioService == null) {
      _webAudioService = WebAudioService();
      _webAudioService!.addListener(_onWebServiceStateChanged);
    }
    return _webAudioService!;
  }
  
  // 웹 서비스 상태 변경 리스너
  void _onWebServiceStateChanged() {
    if (kIsWeb && _webAudioService != null) {
      // 웹 서비스의 상태를 메인 서비스와 동기화
      _recordingDuration = _webAudioService!.recordingDuration;
      _recordingState = _webRecordingStateToRecordingState(_webAudioService!.recordingState);
      notifyListeners();
    }
  }
  
  // WebRecordingState를 RecordingState로 변환
  RecordingState _webRecordingStateToRecordingState(WebRecordingState webState) {
    switch (webState) {
      case WebRecordingState.idle:
        return RecordingState.idle;
      case WebRecordingState.recording:
        return RecordingState.recording;
      case WebRecordingState.paused:
        return RecordingState.paused;
      case WebRecordingState.stopped:
        return RecordingState.stopped;
    }
  }

  // 재생 상태
  PlaybackState _playbackState = PlaybackState.idle;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  String? _currentPlayingFileId;

  // Getters
  RecordingState get recordingState => _recordingState;
  Duration get recordingDuration => _recordingDuration;
  PlaybackState get playbackState => _playbackState;
  Duration get playbackDuration => _playbackDuration;
  Duration get playbackPosition => _playbackPosition;
  String? get currentPlayingFileId => _currentPlayingFileId;

  bool get isRecording => _recordingState == RecordingState.recording;
  bool get isPaused => _recordingState == RecordingState.paused;
  bool get isPlaying => _playbackState == PlaybackState.playing;
  bool get isBackgroundRecording => kIsWeb && _webAudioService?.isBackgroundRecording == true;

  @override
  void dispose() {
    _stopRecording();
    _stopPlayback();
    _recorder.dispose();
    _player.dispose();
    _recordingTimer?.cancel();
    
    // 웹 서비스 정리
    if (_webAudioService != null) {
      _webAudioService!.removeListener(_onWebServiceStateChanged);
      _webAudioService!.dispose();
      _webAudioService = null;
    }
    
    super.dispose();
  }

  // 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    try {
      // 웹 환경에서는 다른 방식으로 권한 확인
      if (kIsWeb) {
        return await _requestWebMicrophonePermission();
      }
      
      // 모바일 환경에서는 기존 방식 사용
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('마이크 권한 요청 실패: $e');
      return false;
    }
  }

  // 웹에서 마이크 권한 요청
  Future<bool> _requestWebMicrophonePermission() async {
    try {
      debugPrint('웹에서 마이크 권한 요청 시도');
      
      // 먼저 mediaDevices API가 사용 가능한지 확인
      if (html.window.navigator.mediaDevices == null) {
        debugPrint('MediaDevices API를 사용할 수 없습니다');
        return false;
      }

      // getUserMedia를 통해 마이크 권한 요청
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
        'video': false,
      });
      
      // 스트림을 즉시 중단 (권한 확인 목적)
      final tracks = stream.getAudioTracks();
      for (final track in tracks) {
        track.stop();
      }
      
      debugPrint('웹 마이크 권한 승인됨');
      return true;
    } catch (e) {
      debugPrint('웹 마이크 권한 요청 실패: $e');
      
      // 권한이 거부되었거나 다른 오류 발생
      if (e.toString().contains('NotAllowedError')) {
        debugPrint('사용자가 마이크 권한을 거부했습니다');
      } else if (e.toString().contains('NotFoundError')) {
        debugPrint('마이크 장치를 찾을 수 없습니다');
      } else if (e.toString().contains('NotSupportedError')) {
        debugPrint('이 브라우저에서는 마이크를 지원하지 않습니다');
      }
      
      return false;
    }
  }

  // 녹음 시작
  Future<bool> startRecording() async {
    try {
      debugPrint('=== 녹음 시작 프로세스 시작 ===');
      debugPrint('현재 플랫폼: ${kIsWeb ? "웹" : "네이티브"}');
      
      // 진행 중인 재생 중단
      if (_playbackState != PlaybackState.idle) {
        debugPrint('기존 재생 중단 중...');
        await _stopPlayback();
      }

      // 웹 환경에서는 WebAudioService 사용
      if (kIsWeb) {
        debugPrint('웹 오디오 서비스로 녹음 시작...');
        return await _webService.startRecording();
      }

      // 네이티브 환경에서는 기존 로직 사용
      debugPrint('1. 마이크 권한 확인 중...');
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('❌ 마이크 권한이 거부되었습니다');
        return false;
      }
      debugPrint('✅ 마이크 권한 승인됨');

      // 녹음기가 사용 가능한지 확인
      debugPrint('2. 녹음기 상태 확인 중...');
      final isAvailable = await _recorder.hasPermission();
      debugPrint('녹음기 권한 상태: $isAvailable');

      debugPrint('3. 네이티브 환경에서 녹음 시작...');
      // 녹음 파일 경로 생성 (네이티브 환경)
      final audioDir = await _storageService.getAudioDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${audioDir.path}/$fileName';
      debugPrint('녹음 파일 경로: $filePath');

      // 녹음 시작
      await _recorder.start(path: filePath);
      _currentRecordingPath = filePath;

      _recordingState = RecordingState.recording;
      _recordingDuration = Duration.zero;

      // 타이머 시작
      _startRecordingTimer();

      notifyListeners();
      debugPrint('✅ 네이티브 녹음 시작 성공: $_currentRecordingPath');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ 녹음 시작 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return false;
    }
  }

  // 녹음 일시정지
  Future<bool> pauseRecording() async {
    try {
      if (_recordingState != RecordingState.recording) return false;

      if (kIsWeb) {
        return await _webService.pauseRecording();
      }

      await _recorder.pause();
      _recordingState = RecordingState.paused;
      _recordingTimer?.cancel();

      notifyListeners();
      debugPrint('녹음 일시정지');
      return true;
    } catch (e) {
      debugPrint('녹음 일시정지 실패: $e');
      return false;
    }
  }

  // 녹음 재개
  Future<bool> resumeRecording() async {
    try {
      if (_recordingState != RecordingState.paused) return false;

      if (kIsWeb) {
        return await _webService.resumeRecording();
      }

      await _recorder.resume();
      _recordingState = RecordingState.recording;
      _startRecordingTimer();

      notifyListeners();
      debugPrint('녹음 재개');
      return true;
    } catch (e) {
      debugPrint('녹음 재개 실패: $e');
      return false;
    }
  }

  // 녹음 정지 및 저장
  Future<FileModel?> stopRecording(String noteId, {String? customName}) async {
    try {
      debugPrint('=== 녹음 정지 프로세스 시작 ===');
      if (_recordingState == RecordingState.idle) {
        debugPrint('❌ 녹음이 진행 중이 아닙니다');
        return null;
      }

      if (kIsWeb) {
        debugPrint('웹 환경에서 녹음 정지...');
        final recordingBlobUrl = await _webService.stopRecording();
        
        if (recordingBlobUrl == null) {
          debugPrint('❌ 웹 녹음 데이터를 가져올 수 없습니다');
          return null;
        }

        // 웹에서는 Blob URL을 파일 경로로 사용
        final now = DateTime.now();
        final fileName = customName ?? '웹 녹음 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        
        final audioFile = FileModel(
          id: _uuid.v4(),
          noteId: noteId,
          type: FileType.audio,
          name: fileName,
          content: '',
          filePath: recordingBlobUrl, // 웹에서는 blob URL
          createdAt: now,
          updatedAt: now,
          metadata: {
            'duration': _recordingDuration.inSeconds.toDouble(),
            'fileSize': 0, // 웹에서는 크기 계산이 어려움
            'sampleRate': 44100,
            'bitRate': 128000,
            'platform': 'web',
          },
        );

        // 상태 초기화는 웹 서비스에서 처리됨
        debugPrint('✅ 웹 녹음 완료: ${audioFile.name}, 길이: ${_recordingDuration.inSeconds}초');
        return audioFile;
      }

      // 네이티브 환경에서의 처리
      debugPrint('1. 네이티브 녹음 정지 중...');
      final recordingPath = await _recorder.stop();
      _stopRecordingTimer();

      debugPrint('녹음 정지 결과 - 경로: $recordingPath');
      debugPrint('현재 녹음 경로: $_currentRecordingPath');

      if (recordingPath == null || _currentRecordingPath == null) {
        debugPrint('❌ 녹음 파일을 찾을 수 없습니다');
        return null;
      }

      // 파일 크기 확인
      final file = File(recordingPath);
      if (!await file.exists()) {
        debugPrint('❌ 녹음 파일이 존재하지 않습니다: $recordingPath');
        return null;
      }

      final fileSize = await file.length();
      debugPrint('파일 크기: $fileSize bytes');
      
      if (fileSize == 0) {
        debugPrint('❌ 녹음 파일이 비어있습니다');
        await file.delete();
        return null;
      }

      // FileModel 생성
      final now = DateTime.now();
      final fileName = customName ?? '녹음 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final audioFile = FileModel(
        id: _uuid.v4(),
        noteId: noteId,
        type: FileType.audio,
        name: fileName,
        content: '',
        filePath: recordingPath,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'duration': _recordingDuration.inSeconds.toDouble(),
          'fileSize': fileSize,
          'sampleRate': 44100,
          'bitRate': 128000,
          'platform': 'native',
        },
      );

      _recordingState = RecordingState.idle;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;

      notifyListeners();
      debugPrint('✅ 네이티브 녹음 완료: ${audioFile.name}, 길이: ${_recordingDuration.inSeconds}초');
      return audioFile;
    } catch (e, stackTrace) {
      debugPrint('❌ 녹음 정지 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      await _stopRecording();
      return null;
    }
  }

  // 강제 녹음 중단
  Future<void> _stopRecording() async {
    try {
      if (_recordingState != RecordingState.idle) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('녹음 중단 실패: $e');
    } finally {
      _recordingState = RecordingState.idle;
      _recordingDuration = Duration.zero;
      _stopRecordingTimer();
      _currentRecordingPath = null;
      notifyListeners();
    }
  }

  // 오디오 재생 시작
  Future<bool> playAudio(FileModel audioFile) async {
    try {
      // 현재 재생 중인 파일이 있다면 중단
      if (_playbackState != PlaybackState.idle) {
        await _stopPlayback();
      }

      // 파일 존재 확인
      if (audioFile.filePath == null) {
        debugPrint('오디오 파일 경로가 없습니다');
        return false;
      }

      // 웹 환경에서의 Blob URL 재생
      if (kIsWeb && audioFile.filePath!.startsWith('blob:')) {
        debugPrint('웹 환경에서 Blob URL 재생: ${audioFile.filePath}');
        await _player.play(UrlSource(audioFile.filePath!));
      } else {
        // 네이티브 환경에서의 파일 재생
        final file = File(audioFile.filePath!);
        if (!await file.exists()) {
          debugPrint('오디오 파일을 찾을 수 없습니다: ${audioFile.filePath}');
          return false;
        }
        await _player.play(DeviceFileSource(audioFile.filePath!));
      }

      _currentPlayingFileId = audioFile.id;
      _playbackState = PlaybackState.playing;
      _playbackDuration = Duration(seconds: audioFile.audioDuration.round());

      // 재생 상태 리스너 등록
      _setupPlaybackListeners();

      notifyListeners();
      debugPrint('오디오 재생 시작: ${audioFile.name}');
      return true;
    } catch (e) {
      debugPrint('오디오 재생 실패: $e');
      return false;
    }
  }

  // 재생 일시정지
  Future<bool> pausePlayback() async {
    try {
      if (_playbackState != PlaybackState.playing) return false;

      await _player.pause();
      _playbackState = PlaybackState.paused;

      notifyListeners();
      debugPrint('재생 일시정지');
      return true;
    } catch (e) {
      debugPrint('재생 일시정지 실패: $e');
      return false;
    }
  }

  // 재생 재개
  Future<bool> resumePlayback() async {
    try {
      if (_playbackState != PlaybackState.paused) return false;

      await _player.resume();
      _playbackState = PlaybackState.playing;

      notifyListeners();
      debugPrint('재생 재개');
      return true;
    } catch (e) {
      debugPrint('재생 재개 실패: $e');
      return false;
    }
  }

  // 재생 정지
  Future<void> stopPlayback() async {
    await _stopPlayback();
  }

  // 재생 위치 변경
  Future<bool> seekTo(Duration position) async {
    try {
      if (_playbackState == PlaybackState.idle) return false;

      await _player.seek(position);
      _playbackPosition = position;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('재생 위치 변경 실패: $e');
      return false;
    }
  }

  // 재생 중단 (내부용)
  Future<void> _stopPlayback() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('재생 중단 실패: $e');
    } finally {
      _playbackState = PlaybackState.idle;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
      _currentPlayingFileId = null;
      notifyListeners();
    }
  }

  // 녹음 타이머 시작
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      notifyListeners();
    });
  }

  // 녹음 타이머 정지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // 재생 리스너 설정
  void _setupPlaybackListeners() {
    // 재생 완료 리스너
    _player.onPlayerComplete.listen((_) {
      _playbackState = PlaybackState.stopped;
      _playbackPosition = Duration.zero;
      _currentPlayingFileId = null;
      notifyListeners();
    });

    // 재생 위치 리스너
    _player.onPositionChanged.listen((position) {
      _playbackPosition = position;
      notifyListeners();
    });

    // 재생 길이 리스너
    _player.onDurationChanged.listen((duration) {
      _playbackDuration = duration;
      notifyListeners();
    });
  }

  // 오디오 파일 삭제
  Future<bool> deleteAudioFile(String fileId, String filePath) async {
    try {
      // 현재 재생 중인 파일이면 중단
      if (_currentPlayingFileId == fileId) {
        await _stopPlayback();
      }

      // 파일 삭제
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      debugPrint('오디오 파일 삭제 완료: $filePath');
      return true;
    } catch (e) {
      debugPrint('오디오 파일 삭제 실패: $e');
      return false;
    }
  }

  // 재생 진행률 (0.0 - 1.0)
  double get playbackProgress {
    if (_playbackDuration.inMilliseconds == 0) return 0.0;
    return _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds;
  }

  // 녹음 가능 시간 확인 (최대 60분)
  bool get canContinueRecording {
    return _recordingDuration.inMinutes < 60;
  }
}