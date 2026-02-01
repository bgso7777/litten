import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/audio_file.dart';
import '../models/litten.dart';

class AudioService extends ChangeNotifier with WidgetsBindingObserver {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initializeAudioPlayer();
    _initializeForegroundNotification();
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _currentRecordingPath;
  AudioFile? _currentPlayingFile;
  double _playbackSpeed = 1.0;
  Timer? _stateSaveTimer;
  String? _currentRecordingLittenId;

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

    // record 패키지가 자체적으로 권한을 처리하므로
    // permission_handler 체크를 생략하고 바로 true 반환
    // iOS 설정에서 권한이 있으면 record 패키지가 정상 작동함
    debugPrint('[AudioService] 권한 체크 건너뛰기 (record 패키지가 자체 처리)');
    return true;
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
      _currentRecordingLittenId = litten.id;
      _recordingDuration = Duration.zero;

      debugPrint('[AudioService] 녹음 시작됨');

      // 포그라운드 알림 표시 (백그라운드 녹음 유지)
      await _showRecordingNotification();

      notifyListeners();

      // 녹음 시간 추적 시작
      _startRecordingTimer();

      // 주기적 상태 저장 시작 (30초마다)
      _startPeriodicStateSave();

      // 초기 상태 저장
      await saveRecordingState(littenId: litten.id);

      return true;
    } catch (e) {
      debugPrint('[AudioService] 녹음 시작 오류: $e');
      await _hideRecordingNotification();
      return false;
    }
  }

  /// 듣기(녹음) 취소 (파일 저장 없이 중단)
  Future<void> cancelRecording() async {
    debugPrint('[AudioService] cancelRecording 진입');

    if (!_isRecording) {
      debugPrint('[AudioService] 녹음 중이 아닙니다.');
      return;
    }

    try {
      // 녹음 중지
      final path = await _recorder.stop();

      // 파일이 생성되었다면 삭제
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[AudioService] 🗑️ 녹음 파일 삭제됨: $path');
        }
      }

      _isRecording = false;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;
      _currentRecordingLittenId = null;

      // 주기적 상태 저장 중지
      _stopPeriodicStateSave();

      await clearRecordingState();

      // 포그라운드 알림 제거
      await _hideRecordingNotification();

      debugPrint('[AudioService] 녹음 취소 완료');
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] 녹음 취소 오류: $e');
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;
      _currentRecordingLittenId = null;
      _stopPeriodicStateSave();
      await clearRecordingState();
      await _hideRecordingNotification();
      notifyListeners();
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
        // 파일 무결성 검증
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('[AudioService] ⚠️ 녹음 파일이 생성되지 않음');
          _isRecording = false;
          _recordingDuration = Duration.zero;
          _currentRecordingPath = null;
          await clearRecordingState();
          notifyListeners();
          return null;
        }

        final fileSize = await file.length();
        debugPrint('[AudioService] 파일 크기: ${fileSize / 1024}KB');

        // 최소 파일 크기 검증 (1KB)
        if (fileSize < 1024) {
          debugPrint('[AudioService] ⚠️ 파일이 너무 작음 - 깨진 파일 의심');
          try {
            await file.delete();
            debugPrint('[AudioService] 🗑️ 깨진 파일 삭제됨');
          } catch (e) {
            debugPrint('[AudioService] ❌ 파일 삭제 실패: $e');
          }
          _isRecording = false;
          _recordingDuration = Duration.zero;
          _currentRecordingPath = null;
          await clearRecordingState();
          notifyListeners();
          return null;
        }

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
        debugPrint('[AudioService] 파일 크기: ${fileSize / 1024}KB');

        _isRecording = false;
        _recordingDuration = Duration.zero;
        _currentRecordingPath = null;
        _currentRecordingLittenId = null;

        // 주기적 상태 저장 중지
        _stopPeriodicStateSave();

        await clearRecordingState();

        // 포그라운드 알림 제거
        await _hideRecordingNotification();

        notifyListeners();
        return audioFile;
      }

      // 포그라운드 알림 제거
      await _hideRecordingNotification();

      return null;
    } catch (e) {
      debugPrint('[AudioService] 녹음 중지 오류: $e');
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;
      _currentRecordingLittenId = null;
      _stopPeriodicStateSave();
      await _hideRecordingNotification();
      notifyListeners();
      return null;
    }
  }

  /// 앱 라이프사이클 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 앱 라이프사이클 변경: $state');

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // 앱이 백그라운드로 전환될 때 녹음 상태 저장
      if (_isRecording) {
        debugPrint('💾 백그라운드 전환 - 녹음 상태 저장');
        saveRecordingState(littenId: _currentRecordingLittenId);
      }
    } else if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 복귀할 때
      debugPrint('🔄 포그라운드 복귀');
      if (_isRecording) {
        debugPrint('✅ 녹음이 계속 진행 중');
      }
    }
  }

  /// 녹음 시간 추적 및 주기적 상태 저장
  void _startRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
        _startRecordingTimer();
      }
    });
  }

  /// 주기적 상태 저장 시작 (30초마다)
  void _startPeriodicStateSave() {
    _stateSaveTimer?.cancel();
    _stateSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isRecording) {
        debugPrint('💾 주기적 녹음 상태 저장 (${_recordingDuration.inSeconds}초)');
        saveRecordingState(littenId: _currentRecordingLittenId);
      } else {
        timer.cancel();
      }
    });
  }

  /// 주기적 상태 저장 중지
  void _stopPeriodicStateSave() {
    _stateSaveTimer?.cancel();
    _stateSaveTimer = null;
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

  /// 포그라운드 알림 초기화
  Future<void> _initializeForegroundNotification() async {
    try {
      debugPrint('🔔 포그라운드 알림 초기화 시작');

      // Android 설정
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 설정
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);

      debugPrint('✅ 포그라운드 알림 초기화 완료');
    } catch (e) {
      debugPrint('❌ 포그라운드 알림 초기화 에러: $e');
    }
  }

  /// 녹음 중 포그라운드 알림 표시
  Future<void> _showRecordingNotification() async {
    try {
      debugPrint('🔔 녹음 포그라운드 알림 표시');

      // Android 알림 설정
      const androidDetails = AndroidNotificationDetails(
        'recording_channel',
        '녹음 중',
        channelDescription: '녹음이 진행 중임을 알립니다',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true, // 사용자가 닫을 수 없음
        autoCancel: false,
        showWhen: false,
        playSound: false,
        enableVibration: false,
      );

      // iOS 알림 설정
      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        999, // 고정 ID (녹음 알림용)
        '🎙️ 녹음 중',
        '듣기가 진행 중입니다. 백그라운드에서도 계속 녹음됩니다.',
        details,
      );

      debugPrint('✅ 녹음 포그라운드 알림 표시 완료');
    } catch (e) {
      debugPrint('❌ 녹음 포그라운드 알림 표시 에러: $e');
    }
  }

  /// 녹음 포그라운드 알림 제거
  Future<void> _hideRecordingNotification() async {
    try {
      debugPrint('🔔 녹음 포그라운드 알림 제거');
      await _notificationsPlugin.cancel(999);
      debugPrint('✅ 녹음 포그라운드 알림 제거 완료');
    } catch (e) {
      debugPrint('❌ 녹음 포그라운드 알림 제거 에러: $e');
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
          category: AVAudioSessionCategory.playAndRecord, // 백그라운드 녹음 및 재생 허용
          options: <AVAudioSessionOptions>{
            AVAudioSessionOptions.mixWithOthers, // 다른 앱과 함께 재생
            AVAudioSessionOptions.defaultToSpeaker, // 기본 스피커 출력
            AVAudioSessionOptions.allowBluetooth, // 블루투스 허용
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

  /// 녹음 상태 저장 (백그라운드 대비)
  Future<void> saveRecordingState({String? littenId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_isRecording && _currentRecordingPath != null) {
        await prefs.setBool('is_recording', true);
        await prefs.setString('recording_path', _currentRecordingPath!);
        await prefs.setInt('recording_duration_seconds', _recordingDuration.inSeconds);
        await prefs.setInt('recording_start_time', DateTime.now().millisecondsSinceEpoch - _recordingDuration.inMilliseconds);
        if (littenId != null) {
          await prefs.setString('recording_litten_id', littenId);
        }
        debugPrint('💾 녹음 상태 저장: $_currentRecordingPath (${_recordingDuration.inSeconds}초)');
        if (littenId != null) {
          debugPrint('   리튼 ID: $littenId');
        }
      } else {
        await clearRecordingState();
        debugPrint('💾 녹음 상태 제거 (녹음 중 아님)');
      }
    } catch (e) {
      debugPrint('❌ 녹음 상태 저장 실패: $e');
    }
  }

  /// 녹음 상태 복원 (앱 재개 시)
  Future<bool> restoreRecordingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasRecording = prefs.getBool('is_recording') ?? false;

      if (!wasRecording) {
        debugPrint('🔄 복원할 녹음 상태 없음');
        return false;
      }

      final recordingPath = prefs.getString('recording_path');
      final startTimeMs = prefs.getInt('recording_start_time');
      final littenId = prefs.getString('recording_litten_id');

      if (recordingPath == null || startTimeMs == null) {
        debugPrint('⚠️ 녹음 상태 정보 불완전, 초기화');
        await clearRecordingState();
        return false;
      }

      // 파일이 실제로 존재하는지 확인
      final file = File(recordingPath);
      if (!await file.exists()) {
        debugPrint('⚠️ 녹음 파일이 존재하지 않음: $recordingPath');
        await clearRecordingState();
        return false;
      }

      // 파일 크기 확인 (최소 1KB)
      final fileSize = await file.length();
      if (fileSize < 1024) {
        debugPrint('⚠️ 녹음 파일이 너무 작음 (깨진 파일 의심): ${fileSize}바이트');
        await clearRecordingState();
        // 깨진 파일 삭제
        try {
          await file.delete();
          debugPrint('🗑️ 깨진 녹음 파일 삭제됨');
        } catch (e) {
          debugPrint('❌ 파일 삭제 실패: $e');
        }
        return false;
      }

      // 경과 시간 확인 (24시간 이상이면 무시)
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startTimeMs;
      if (elapsedMs > 24 * 60 * 60 * 1000) {
        debugPrint('⚠️ 녹음 시작 시간이 24시간 이상 경과, 녹음 중단');
        await clearRecordingState();
        return false;
      }

      // 녹음 상태 복원
      _isRecording = true;
      _currentRecordingPath = recordingPath;
      _recordingDuration = Duration(milliseconds: elapsedMs);

      debugPrint('🔄 녹음 상태 복원 성공: $recordingPath');
      debugPrint('   경과 시간: ${_recordingDuration.inSeconds}초');
      debugPrint('   파일 크기: ${fileSize / 1024}KB');
      if (littenId != null) {
        debugPrint('   리튼 ID: $littenId');
      }

      // 타이머 재시작
      _startRecordingTimer();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ 녹음 상태 복원 실패: $e');
      await clearRecordingState();
      return false;
    }
  }

  /// 녹음 상태 정리
  Future<void> clearRecordingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_recording');
      await prefs.remove('recording_path');
      await prefs.remove('recording_duration_seconds');
      await prefs.remove('recording_start_time');
      await prefs.remove('recording_litten_id');
      debugPrint('🗑️ 녹음 상태 정리 완료');
    } catch (e) {
      debugPrint('❌ 녹음 상태 정리 실패: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('[AudioService] dispose 진입');
    _stopPeriodicStateSave();
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}