import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/audio_file.dart';
import '../models/litten.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initializeAudioPlayer();
  }

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentRecordingPath;
  AudioFile? _currentPlayingFile;
  double _playbackSpeed = 1.0;

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  Duration get recordingDuration => _recordingDuration;
  Duration get playbackDuration => _playbackDuration;
  Duration get totalDuration => _totalDuration;
  AudioFile? get currentPlayingFile => _currentPlayingFile;
  double get playbackSpeed => _playbackSpeed;

  /// 녹음 권한 요청
  Future<bool> requestPermission() async {
    debugPrint('[AudioService] 녹음 권한 요청 시작');
    
    // 현재 권한 상태 확인
    var status = await Permission.microphone.status;
    debugPrint('[AudioService] 현재 권한 상태: $status');
    
    if (status.isDenied) {
      // 권한 요청
      status = await Permission.microphone.request();
      debugPrint('[AudioService] 권한 요청 후 상태: $status');
    }
    
    if (status.isPermanentlyDenied) {
      debugPrint('[AudioService] 권한이 영구적으로 거부됨 - 설정으로 이동 필요');
      // 설정으로 이동하도록 안내
      await openAppSettings();
      return false;
    }
    
    final hasPermission = status == PermissionStatus.granted;
    debugPrint('[AudioService] 최종 권한 상태: $hasPermission');
    return hasPermission;
  }

  /// 듣기(녹음) 시작
  Future<bool> startRecording(Litten litten) async {
    debugPrint('[AudioService] startRecording 진입 - littenId: ${litten.id}');
    
    if (_isRecording) {
      debugPrint('[AudioService] 이미 녹음 중입니다.');
      return false;
    }

    try {
      // 권한 확인
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('[AudioService] 녹음 권한이 거부되었습니다.');
        return false;
      }

      // 저장 경로 생성
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/littens/${litten.id}/audio');
      if (!await littenDir.exists()) {
        await littenDir.create(recursive: true);
        debugPrint('[AudioService] 오디오 디렉토리 생성: ${littenDir.path}');
      }

      // 파일명 생성 (녹음 년월일시분초)
      final now = DateTime.now();
      final fileName = '녹음 ${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.m4a';
      final filePath = '${littenDir.path}/$fileName';
      
      debugPrint('[AudioService] 녹음 파일 경로: $filePath');

      // 녹음 설정
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // 녹음 시작
      await _recorder.start(config, path: filePath);
      
      _isRecording = true;
      _currentRecordingPath = filePath;
      _recordingDuration = Duration.zero;
      
      debugPrint('[AudioService] 녹음 시작됨');
      notifyListeners();
      
      // 녹음 시간 추적 시작
      _startRecordingTimer();
      
      return true;
    } catch (e) {
      debugPrint('[AudioService] 녹음 시작 오류: $e');
      return false;
    }
  }

  /// 듣기(녹음) 중지 및 파일 저장
  Future<AudioFile?> stopRecording(Litten litten) async {
    debugPrint('[AudioService] stopRecording 진입 - littenId: ${litten.id}');
    
    if (!_isRecording) {
      debugPrint('[AudioService] 녹음 중이 아닙니다.');
      return null;
    }

    try {
      final path = await _recorder.stop();
      
      if (path != null && _currentRecordingPath != null) {
        // AudioFile 모델 생성
        final audioFile = AudioFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          littenId: litten.id,
          fileName: path.split('/').last.replaceAll('.m4a', ''),
          filePath: path,
          duration: _recordingDuration,
          createdAt: DateTime.now(),
        );

        debugPrint('[AudioService] 오디오 파일 저장됨: ${audioFile.fileName}');
        debugPrint('[AudioService] 파일 경로: ${audioFile.filePath}');
        debugPrint('[AudioService] 녹음 시간: ${audioFile.duration}');

        _isRecording = false;
        _recordingDuration = Duration.zero;
        _currentRecordingPath = null;
        
        notifyListeners();
        return audioFile;
      }
      
      return null;
    } catch (e) {
      debugPrint('[AudioService] 녹음 중지 오류: $e');
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;
      notifyListeners();
      return null;
    }
  }

  /// 녹음 시간 추적
  void _startRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
        _startRecordingTimer();
      }
    });
  }

  /// 리튼의 모든 오디오 파일 가져오기
  Future<List<AudioFile>> getAudioFiles(Litten litten) async {
    debugPrint('[AudioService] getAudioFiles 진입 - littenId: ${litten.id}');
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/littens/${litten.id}/audio');
      
      if (!await audioDir.exists()) {
        debugPrint('[AudioService] 오디오 디렉토리가 존재하지 않습니다.');
        return [];
      }

      final files = await audioDir.list().toList();
      final audioFiles = <AudioFile>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.m4a')) {
          final stat = await file.stat();
          final fileName = file.path.split('/').last.replaceAll('.m4a', '');
          
          final audioFile = AudioFile(
            id: stat.modified.millisecondsSinceEpoch.toString(),
            littenId: litten.id,
            fileName: fileName,
            filePath: file.path,
            duration: Duration.zero, // 실제 재생 시 계산
            createdAt: stat.modified,
          );
          
          audioFiles.add(audioFile);
        }
      }

      // 생성일 순으로 정렬
      audioFiles.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      debugPrint('[AudioService] 발견된 오디오 파일 수: ${audioFiles.length}');
      return audioFiles;
    } catch (e) {
      debugPrint('[AudioService] 오디오 파일 목록 조회 오류: $e');
      return [];
    }
  }

  /// 오디오 파일 재생
  Future<bool> playAudio(AudioFile audioFile) async {
    debugPrint('[AudioService] playAudio 진입 - fileName: ${audioFile.fileName}');
    
    try {
      // 백그라운드 재생 설정은 초기화 시 한 번만 설정됨

      if (_isPlaying) {
        await _player.stop();
      }

      await _player.play(DeviceFileSource(audioFile.filePath));
      
      _isPlaying = true;
      _currentPlayingFile = audioFile;
      
      debugPrint('[AudioService] 재생 시작됨');
      notifyListeners();

      // 재생 상태 리스너
      _player.onPlayerStateChanged.listen((PlayerState state) {
        if (state == PlayerState.completed) {
          _isPlaying = false;
          _currentPlayingFile = null;
          _playbackDuration = Duration.zero;
          notifyListeners();
        }
      });

      // 재생 위치 리스너
      _player.onPositionChanged.listen((Duration position) {
        _playbackDuration = position;
        notifyListeners();
      });

      // 전체 길이 리스너
      _player.onDurationChanged.listen((Duration duration) {
        _totalDuration = duration;
        notifyListeners();
      });

      return true;
    } catch (e) {
      debugPrint('[AudioService] 재생 오류: $e');
      return false;
    }
  }

  /// 재생 일시정지
  Future<void> pauseAudio() async {
    debugPrint('[AudioService] pauseAudio 진입');

    try {
      await _player.pause();
      _isPlaying = false;

      debugPrint('[AudioService] 재생 일시정지됨');
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] 재생 일시정지 오류: $e');
    }
  }

  /// 재생 재개
  Future<void> resumeAudio() async {
    debugPrint('[AudioService] resumeAudio 진입');

    try {
      await _player.resume();
      _isPlaying = true;

      debugPrint('[AudioService] 재생 재개됨');
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] 재생 재개 오류: $e');
    }
  }

  /// 재생 중지
  Future<void> stopAudio() async {
    debugPrint('[AudioService] stopAudio 진입');

    try {
      await _player.stop();
      _isPlaying = false;
      _currentPlayingFile = null;
      _playbackDuration = Duration.zero;
      _totalDuration = Duration.zero;

      debugPrint('[AudioService] 재생 중지됨');
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] 재생 중지 오류: $e');
    }
  }

  /// 재생 위치 변경
  Future<void> seekAudio(Duration position) async {
    debugPrint('[AudioService] seekAudio 진입 - position: $position');

    try {
      await _player.seek(position);
      _playbackDuration = position;

      debugPrint('[AudioService] 재생 위치 변경됨: $position');
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] 재생 위치 변경 오류: $e');
    }
  }

  /// 재생 속도 변경
  Future<void> setPlaybackSpeed(double speed) async {
    debugPrint('[AudioService] setPlaybackSpeed 진입 - speed: $speed');
    
    try {
      await _player.setPlaybackRate(speed);
      _playbackSpeed = speed;
      
      debugPrint('[AudioService] 재생 속도 변경됨: ${speed}x');
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] 재생 속도 변경 오류: $e');
    }
  }

  /// 오디오 파일 삭제
  Future<bool> deleteAudioFile(AudioFile audioFile) async {
    debugPrint('[AudioService] deleteAudioFile 진입 - fileName: ${audioFile.fileName}');
    
    try {
      final file = File(audioFile.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioService] 오디오 파일 삭제됨: ${audioFile.fileName}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AudioService] 오디오 파일 삭제 오류: $e');
      return false;
    }
  }

  /// 오디오 플레이어 백그라운드 재생 초기화
  Future<void> _initializeAudioPlayer() async {
    try {
      debugPrint('🎵 오디오 플레이어 백그라운드 재생 설정 중...');

      // 백그라운드 재생을 위한 오디오 컨텍스트 설정
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true, // 화면이 꺼져도 재생 유지
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain, // 미디어 포커스 획득
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback, // 백그라운드 재생 허용
          options: <AVAudioSessionOptions>{
            AVAudioSessionOptions.mixWithOthers, // 다른 앱과 함께 재생
          },
        ),
      ));

      debugPrint('✅ 오디오 플레이어 백그라운드 재생 설정 완료');
    } catch (e) {
      debugPrint('❌ 오디오 플레이어 백그라운드 재생 설정 에러: $e');
    }
  }

  // 오디오 파일 이름 변경
  Future<void> renameAudioFile(AudioFile audioFile, String newName) async {
    try {
      debugPrint('[AudioService] 파일 이름 변경: ${audioFile.fileName} -> $newName');

      // 메타데이터 파일 업데이트
      final metadataPath = audioFile.filePath.replaceAll('.m4a', '_metadata.json');
      final metadataFile = File(metadataPath);

      if (await metadataFile.exists()) {
        final metadata = json.decode(await metadataFile.readAsString());
        metadata['customName'] = newName;
        await metadataFile.writeAsString(json.encode(metadata));
        debugPrint('[AudioService] 메타데이터 업데이트 완료');
      }
    } catch (e) {
      debugPrint('[AudioService] 파일 이름 변경 에러: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    debugPrint('[AudioService] dispose 진입');
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}