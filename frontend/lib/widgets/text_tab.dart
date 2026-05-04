import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';
import '../models/text_file.dart';
import '../models/audio_file.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';
import '../services/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'dialogs/stt_memo_settings_dialog.dart';

class TextTab extends StatefulWidget {
  final bool autoCreate;
  final VoidCallback? onClose;
  final TextFile? initialFile;
  final bool autoStartSTT;
  final SttMemoSettings? sttSettings; // 음성 메모 설정

  const TextTab({
    super.key,
    this.autoCreate = false,
    this.onClose,
    this.initialFile,
    this.autoStartSTT = false,
    this.sttSettings,
  });

  @override
  State<TextTab> createState() => _TextTabState();
}

class _TextTabState extends State<TextTab> with WidgetsBindingObserver {
  late HtmlEditorController _htmlController;

  // 파일 목록 관련
  List<TextFile> _textFiles = [];
  bool _isLoading = false;

  // 편집 상태
  TextFile? _currentTextFile;
  bool _isEditing = false;

  // 음성 인식(STT) 관련
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _lastPartialText = '';
  int _confirmedLength = 0;
  Timer? _autoSaveTimer;
  Timer? _partialUpdateDebounce; // JS 큐 누적 방지용 디바운스 타이머
  bool _isSaving = false; // 동시 저장 방지 플래그

  // 오디오 녹음 관련 (STT와 동시 실행)
  final AudioService _audioService = AudioService();
  bool _isRecordingWithSTT = false;
  bool _isStoppingRecording = false; // _stopRecordingWithSTT 진행 중 플래그 (dispose 충돌 방지)
  bool _lastSTTActiveState = false;

  // 에디터 초기화 상태 추적
  bool _editorInitialized = false;
  String? _pendingContent; // onInit 이전에 setText 요청된 콘텐츠

  // STT 수동 중지 여부 (true=사용자가 중지, false=시스템 자동 중지)
  bool _isManualStop = false;

  // 음성 메모 모드 (autoStartSTT로 진입 시 true — 1/3 전사 + 2/3 요약 레이아웃)
  bool _isSttMode = false;
  String _sttSummary = ''; // 요약 영역에 표시할 텍스트
  bool _isSummarizing = false; // 요약 진행 중
  Timer? _summaryTimer; // 자동 요약 타이머
  SttMemoSettings _sttSettings = const SttMemoSettings(); // 음성 메모 설정 (기본값)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _htmlController = HtmlEditorController();
    _speechToText = stt.SpeechToText();

    _loadFiles();
    _initializeSpeechToText();

    // ⭐ AppStateProvider 리스닝 - STT 상태 변화 감지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFile != null && mounted) {
        // ⭐ initialFile이 있으면 해당 파일을 바로 편집 모드로 열기
        debugPrint('📂 initialFile 감지됨 - 파일 자동 열기: ${widget.initialFile!.displayTitle}');
        _editTextFile(widget.initialFile!);
      } else if (widget.autoStartSTT && mounted) {
        // ⭐ STT 자동 시작 모드: 새 파일 생성 후 STT 시작
        debugPrint('🎤 STT 자동 시작 모드 - 새 파일 생성 및 STT 시작');
        setState(() {
          _isSttMode = true;
          _sttSettings = widget.sttSettings ?? const SttMemoSettings();
        });
        debugPrint('🎤 STT 설정 - 전사언어: ${_sttSettings.textLanguage}, 요약언어: ${_sttSettings.summaryLanguage}, 비율: ${_sttSettings.summaryRatio}, 주기: ${_sttSettings.summaryIntervalMinutes}분');
        _createNewTextFile(isFromSTT: true);
        // STT 시작을 위해 1초 대기 (파일 생성 완료 대기)
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _currentTextFile != null) {
            _startListening();
          }
        });
      } else if (widget.autoCreate && mounted) {
        _createNewTextFile();
      }
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.addListener(_onAppStateChanged);
      _lastSTTActiveState = appState.isSTTActive;
    });
  }

  /// AppStateProvider 상태 변화 리스너
  void _onAppStateChanged() {
    if (!mounted) return;

    final appState = Provider.of<AppStateProvider>(context, listen: false);

    // ⭐ STT 상태가 외부에서 false로 변경되었고, 현재 STT가 실행 중이면 중단
    if (_lastSTTActiveState == true &&
        appState.isSTTActive == false &&
        _isListening) {
      debugPrint('⚠️ 외부에서 STT 중단 요청됨 (녹음 시작) - _stopListening 호출');
      _stopListening();
    }

    _lastSTTActiveState = appState.isSTTActive;
  }

  /// 음성 인식 초기화
  Future<void> _initializeSpeechToText() async {
    debugPrint('🎤 SpeechToText 초기화 시작');
    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          debugPrint('❌ STT 에러: ${error.errorMsg}, _isManualStop=$_isManualStop');
          if (!mounted) return;

          // 시스템 자동 중지 에러 (타임아웃 등) — 자동 재시작
          final autoRestartErrors = ['error_speech_timeout', 'error_no_match', 'error_client'];
          if (!_isManualStop && autoRestartErrors.contains(error.errorMsg)) {
            debugPrint('⚠️ STT 자동 중지 에러 (${error.errorMsg}) - 3초 후 자동 재시작');
            setState(() => _isListening = false);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && !_isManualStop) {
                debugPrint('🔄 STT 에러 후 자동 재시작');
                _startListening();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('음성 인식이 자동으로 재시작됩니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
            return;
          }

          // 수동 중지이거나 복구 불가 에러 — 완전 중지
          setState(() => _isListening = false);

          String userMessage = '음성 인식 오류가 발생했습니다.';
          if (error.errorMsg == 'error_language_unavailable') {
            userMessage = '선택한 언어의 음성 인식을 사용할 수 없습니다.\n실제 기기에서 사용해주세요.';
          } else if (error.errorMsg == 'error_server_disconnected') {
            userMessage = '음성 인식 서버와 연결할 수 없습니다.\nGoogle 앱을 설치/업데이트하거나 네트워크를 확인해주세요.';
          } else if (error.errorMsg == 'error_no_match' && _isManualStop) {
            return; // 수동 중지 시 error_no_match는 무시
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        },
        onStatus: (status) {
          debugPrint('ℹ️ STT 상태: $status, _isManualStop=$_isManualStop, _isListening=$_isListening');

          if (!mounted) return;

          if ((status == 'done' || status == 'notListening') && !_isManualStop) {
            // 시스템 자동 중지 → 자동 재시작
            debugPrint('⚠️ STT 시스템 자동 중단 ($status) - 2초 후 자동 재시작');
            setState(() => _isListening = false);

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_isManualStop) {
                debugPrint('🔄 STT 자동 재시작 ($status)');
                _startListening();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('음성 인식이 자동으로 재시작됩니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          } else if (status == 'done' || status == 'notListening') {
            // 수동 중지 — 그냥 종료
            debugPrint('ℹ️ STT 수동 중지 상태 ($status)');
            setState(() => _isListening = false);
          }
        },
      );

      if (available) {
        debugPrint('✅ SpeechToText 초기화 완료');

        // 사용 가능한 언어 확인
        final locales = await _speechToText.locales();
        debugPrint('   사용 가능한 언어: ${locales.length}개');

        // 한국어 지원 확인
        final hasKorean = locales.any(
          (locale) => locale.localeId.startsWith('ko'),
        );
        debugPrint('   한국어 지원: ${hasKorean ? "가능" : "불가능"}');

        // Android에서 사용 가능한 음성 인식 엔진 확인
        if (defaultTargetPlatform == TargetPlatform.android) {
          debugPrint('   Android 음성 인식 엔진 확인됨');
        }
      } else {
        debugPrint('⚠️ SpeechToText 사용 불가');
        debugPrint('   디바이스에 음성 인식 서비스가 설치되어 있지 않을 수 있습니다.');
        debugPrint('   Google 앱 또는 음성 인식 서비스를 설치해주세요.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SpeechToText 초기화 에러: $e');
      debugPrint('   StackTrace: $stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 TextTab 생명주기 변경: $state');
    debugPrint('   📊 현재 상태: _isEditing=$_isEditing, _currentTextFile=${_currentTextFile?.fileName}, _isListening=$_isListening');

    switch (state) {
      case AppLifecycleState.paused:
        // 백그라운드로 전환 시 - STT는 계속 작동하도록 유지
        debugPrint('⏸️ 앱 백그라운드 전환 - STT 작동 유지');
        debugPrint('   💾 편집 상태 저장: _isEditing=$_isEditing, _currentTextFile=${_currentTextFile?.fileName}');
        // STT를 중지하지 않음 - 계속 듣기 모드 유지
        break;

      case AppLifecycleState.resumed:
        // 포그라운드로 복귀 시 - 파일 목록 재로드하지만 편집 상태는 유지
        debugPrint('▶️ 앱 포그라운드 복귀 - STT 상태: $_isListening');
        debugPrint('   📖 복귀 시 상태: _isEditing=$_isEditing, _currentTextFile=${_currentTextFile?.fileName}');

        // ⭐ 편집 상태를 명시적으로 유지하기 위해 setState 호출
        if (_isEditing && _currentTextFile != null) {
          debugPrint('   ✅ 편집 상태 유지 - setState로 UI 갱신');
          if (mounted) {
            setState(() {
              // 상태 변경 없이 UI만 갱신
            });
          }
        } else if (!_isEditing) {
          debugPrint('   📂 파일 목록 재로드');
          _loadFiles();
        }
        break;

      case AppLifecycleState.inactive:
        // 비활성 상태 (화면 잠금, 전화 수신 등)
        debugPrint('💤 앱 비활성 상태 - STT 작동 유지');
        debugPrint('   📊 비활성 상태: _isEditing=$_isEditing, _currentTextFile=${_currentTextFile?.fileName}');
        break;

      case AppLifecycleState.detached:
        // 앱 종료
        debugPrint('🛑 앱 종료');
        break;

      case AppLifecycleState.hidden:
        debugPrint('🙈 앱 숨김 상태');
        debugPrint('   📊 숨김 상태: _isEditing=$_isEditing, _currentTextFile=${_currentTextFile?.fileName}');
        break;
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ TextTab dispose 진입');

    // 메모리 누수 방지를 위한 리소스 정리
    WidgetsBinding.instance.removeObserver(this);

    // ⭐ AppStateProvider 리스너 제거
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.removeListener(_onAppStateChanged);
    } catch (e) {
      debugPrint('⚠️ AppStateProvider 리스너 제거 실패 (무시됨): $e');
    }

    // ⚠️ 중요: STT 작동 중에는 dispose하지 않도록 주의
    // 앱이 백그라운드로 갈 때도 위젯이 dispose되지 않도록 IndexedStack 사용
    // 하지만 완전히 종료되는 경우에만 정리
    if (_isListening) {
      debugPrint('⚠️ dispose: STT 진행 중 - 강제 중지');
      _speechToText.stop();
      _isListening = false;
    }

    // 녹음 진행 중이면 중지
    if (_isRecordingWithSTT) {
      if (_isStoppingRecording) {
        // _stopRecordingWithSTT()가 이미 실행 중 — cancelRecording() 건너뜀 (파일 보존)
        debugPrint('ℹ️ dispose: _stopRecordingWithSTT 진행 중이므로 cancelRecording 생략');
      } else {
        debugPrint('⚠️ dispose: 녹음 진행 중 - 강제 중지');
        _audioService.cancelRecording();
      }
      _isRecordingWithSTT = false;
    }

    // 자동 저장 타이머 정리
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _partialUpdateDebounce?.cancel();
    _partialUpdateDebounce = null;
    _summaryTimer?.cancel();
    _summaryTimer = null;
    debugPrint('⏰ dispose: 자동 저장 타이머 정리');

    try {
      _htmlController.disable();
    } catch (e) {
      debugPrint('HtmlEditorController dispose 에러 (무시됨): $e');
    }

    debugPrint('✅ TextTab dispose 완료');
    super.dispose();
  }

  String? _lastLittenId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // 리튼이 변경되었을 때 파일 목록 재로드
        if (appState.selectedLitten?.id != _lastLittenId) {
          _lastLittenId = appState.selectedLitten?.id;
          if (appState.selectedLitten != null) {
            // 새로운 리튼으로 변경되었으므로 파일 목록 재로드
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadFiles();
            });
          }
        }

        if (appState.selectedLitten == null) {
          return EmptyState(
            icon: Icons.edit_note,
            title: l10n?.emptyLittenTitle ?? '리튼을 선택해주세요',
            description:
                l10n?.emptyLittenDescription ??
                '쓰기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
            actionText: l10n?.homeTitle ?? '홈으로 이동',
            onAction: () => appState.changeTabIndex(0),
          );
        }

        if (_isEditing && _currentTextFile != null) {
          return _buildTextEditor();
        }

        return _buildFileListView();
      },
    );
  }

  Future<void> _loadFiles() async {
    if (!mounted) return; // 위젯이 dispose된 경우 return

    // ⭐ 편집 중일 때는 파일 목록 재로드하지 않음 (편집 화면 유지)
    if (_isEditing) {
      debugPrint('✅ 편집 중이므로 파일 목록 재로드 건너뛰기 (_loadFiles)');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten != null) {
        final storage = FileStorageService.instance;

        // 텍스트 파일 로드
        final loadedTextFiles = await storage.loadTextFiles(selectedLitten.id);

        // 최근 파일이 위로 오도록 정렬 (updatedAt 기준 내림차순)
        loadedTextFiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // 한 번의 setState로 모든 상태 업데이트
        if (mounted) {
          setState(() {
            _textFiles
              ..clear()
              ..addAll(loadedTextFiles);
            _isLoading = false;
          });
        }

        print('디버그: 파일 목록 로드 완료 - 텍스트: ${_textFiles.length}개');
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('에러: 파일 로드 실패 - $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFileListView() {
    return Column(
      children: [
        // 파일 목록
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // 텍스트 파일 섹션
                    Expanded(
                      child: Column(
                        children: [
                          // 텍스트 파일 리스트
                          Expanded(
                            child: Stack(
                              children: [
                                _textFiles.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.keyboard,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            AppSpacing.verticalSpaceS,
                                            Text(
                                              AppLocalizations.of(context)?.noTextFiles ?? '텍스트 파일이 없습니다',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _textFiles.length,
                                        itemBuilder: (context, index) {
                                          return _buildTextFileItem(
                                            _textFiles[index],
                                          );
                                        },
                                      ),
                                // 텍스트 쓰기 버튼 (오른쪽 아래 고정)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: FloatingActionButton(
                                    onPressed: _createNewTextFile,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    foregroundColor: Colors.white,
                                    mini: true,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.keyboard, size: 16),
                                        SizedBox(width: 2),
                                        Icon(Icons.add, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _createNewTextFile({bool isFromSTT = false}) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten != null) {
      // 현재 시간 기반 제목 생성
      final now = DateTime.now();
      final littenName = selectedLitten.title == 'undefined' ? '텍스트' : selectedLitten.title;
      final defaultTitle =
          '$littenName ${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final newTextFile = TextFile(
        littenId: selectedLitten.id,
        title: defaultTitle,
        content: '',
        isFromSTT: isFromSTT,
      );

      print('디버그: 새로운 텍스트 파일 생성 - $defaultTitle');

      setState(() {
        _currentTextFile = newTextFile;
        _isEditing = true;
      });
    }
  }

  void _editTextFile(TextFile file) async {
    setState(() {
      _currentTextFile = file;
      _isEditing = true;
    });

    if (_editorInitialized) {
      // 에디터가 이미 초기화된 경우 바로 로드
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        debugPrint('📂 [TextTab] 에디터 초기화됨 - setText 직접 호출');
        _htmlController.setText(file.content);
      } catch (e) {
        debugPrint('❌ [TextTab] HTML 에디터 로딩 에러: $e');
      }
    } else {
      // 에디터 미초기화 - onInit에서 로드하도록 예약
      debugPrint('📂 [TextTab] 에디터 미초기화 - pendingContent 설정');
      _pendingContent = file.content;
    }
  }

  void _handleTextFileAction(String action, TextFile file) {
    switch (action) {
      case 'edit':
        _editTextFile(file);
        break;
      case 'duplicate':
        // TODO: 파일 복사 로직
        break;
      case 'delete':
        _showDeleteConfirmDialog(file.displayTitle, () {
          _deleteTextFile(file);
        });
        break;
    }
  }

  void _showRenameDialog(TextFile file) {
    final TextEditingController controller = TextEditingController(
      text: file.title.isNotEmpty
          ? file.title
          : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '파일 이름을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(context);
                await _renameTextFile(file, newTitle);
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameTextFile(TextFile file, String newTitle) async {
    try {
      print('디버그: 텍스트 파일 이름 변경 시작 - ${file.displayTitle} -> $newTitle');

      final updatedFile = file.copyWith(title: newTitle);

      // 파일 목록에서 업데이트
      final index = _textFiles.indexWhere((f) => f.id == file.id);
      if (index >= 0) {
        setState(() {
          _textFiles[index] = updatedFile;
        });
      }

      // 파일 시스템에 저장
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten != null) {
        final storage = FileStorageService.instance;
        await storage.saveTextFiles(selectedLitten.id, _textFiles);

        // 홈탭 파일 리스트 갱신을 위해 리튼 새로고침
        await appState.refreshLittens();
      }

      print('디버그: 텍스트 파일 이름 변경 완료 - $newTitle');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 이름이 "$newTitle"(으)로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('에러: 텍스트 파일 이름 변경 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 이름 변경에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(String fileName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"$fileName"을(를) 삭제하시겠습니까?\n\n이 작업은 취소할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTextFile(TextFile file) async {
    try {
      print('디버그: 텍스트 파일 삭제 시작 - ${file.displayTitle}');

      // 실제 파일 시스템에서 파일 삭제
      final storage = FileStorageService.instance;
      await storage.deleteTextFile(file);

      // 메모리에서 제거
      setState(() {
        _textFiles.removeWhere((f) => f.id == file.id);
      });

      // 파일 목록 업데이트하여 SharedPreferences에 저장
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten != null) {
        await storage.saveTextFiles(selectedLitten.id, _textFiles);

        // 리튼에서 파일 제거
        final littenService = LittenService();
        await littenService.removeTextFileFromLitten(
          selectedLitten.id,
          file.id,
        );
      }

      print('디버그: 텍스트 파일 삭제 완료 - ${file.displayTitle}');

      // 클라우드 동기화 (cloudId가 있을 때만)
      if (file.cloudId != null) {
        SyncService.instance.deleteFile(
          littenId: file.littenId,
          localId: file.id,
          cloudId: file.cloudId!,
          fileType: 'text',
        );
      }

      // 파일 카운트 업데이트
      await appState.updateFileCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.displayTitle} 파일이 삭제되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('에러: 텍스트 파일 삭제 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 삭제에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 음성 인식 토글 (시작/중지)
  Future<void> _toggleSpeechToText() async {
    debugPrint('🎤 _toggleSpeechToText() 진입: _isListening=$_isListening, 녹음중=${_audioService.isRecording}');

    // ⭐ STT 또는 녹음 중일 때 - 둘 다 중지
    if (_isListening || _audioService.isRecording) {
      // STT 중지
      if (_isListening) {
        await _stopListening();
      }

      // 녹음 중지
      if (_audioService.isRecording) {
        debugPrint('⚠️ 녹음이 진행 중 - 녹음 중단');
        try {
          if (!mounted) return;
          final appState = Provider.of<AppStateProvider>(context, listen: false);
          if (appState.selectedLitten != null) {
            final audioFile = await _audioService.stopRecording(appState.selectedLitten!);
            debugPrint('✅ 녹음 중단 완료');

            // 녹음 파일 저장
            if (audioFile != null && mounted) {
              final littenService = LittenService();
              await littenService.addAudioFileToLitten(
                appState.selectedLitten!.id,
                audioFile.id,
              );
              await appState.updateFileCount();
              debugPrint('✅ 녹음 파일 저장 완료');
              SyncService.instance.uploadFile(
                littenId: audioFile.littenId,
                localId: audioFile.id,
                fileType: 'audio',
                fileName: audioFile.fileName,
                filePath: audioFile.filePath,
                localUpdatedAt: audioFile.updatedAt,
              );
            }
          }
        } catch (e) {
          debugPrint('❌ 녹음 중단 실패: $e');
        }
      }
    } else {
      // 인식 시작
      await _startListening();
    }
  }

  /// 음성 인식 시작
  Future<void> _startListening() async {
    _isManualStop = false; // 자동 재시작 허용
    debugPrint('🎤 음성 인식 시작 시도');

    // ⭐ 녹음 중인지 확인 - 녹음 중이면 녹음을 중단하고 STT 시작
    if (_isRecordingWithSTT || _audioService.isRecording) {
      debugPrint('⚠️ 녹음이 진행 중 - 녹음을 중단하고 STT 시작');

      // 녹음 중단
      try {
        if (_audioService.isRecording) {
          final appState = Provider.of<AppStateProvider>(context, listen: false);
          if (appState.selectedLitten != null) {
            final audioFile = await _audioService.stopRecording(appState.selectedLitten!);
            debugPrint('✅ 녹음 중단 완료 (STT 시작을 위해)');

            // 녹음 파일 저장
            if (audioFile != null) {
              final littenService = LittenService();
              await littenService.addAudioFileToLitten(
                appState.selectedLitten!.id,
                audioFile.id,
              );
              await appState.updateFileCount();
              debugPrint('✅ 녹음 파일 저장 완료');
              SyncService.instance.uploadFile(
                littenId: audioFile.littenId,
                localId: audioFile.id,
                fileType: 'audio',
                fileName: audioFile.fileName,
                filePath: audioFile.filePath,
                localUpdatedAt: audioFile.updatedAt,
              );
            }
          }
        }
        _isRecordingWithSTT = false;
      } catch (e) {
        debugPrint('❌ 녹음 중단 실패: $e');
      }
    }

    // SpeechToText 사용 가능 여부 확인
    if (!_speechToText.isAvailable) {
      debugPrint('⚠️ SpeechToText 사용 불가 - 재초기화 시도');
      await _initializeSpeechToText();
      if (!_speechToText.isAvailable) {
        debugPrint('❌ SpeechToText 재초기화 실패');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '음성 인식 기능을 사용할 수 없습니다.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    defaultTargetPlatform == TargetPlatform.android
                        ? 'Google 앱 또는 음성 인식 서비스를 설치해주세요.'
                        : '음성 인식 권한을 확인해주세요. 설정 → Litten → 마이크 권한을 활성화하세요.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    // 사용 가능한 locale 확인
    final availableLocales = await _speechToText.locales();
    debugPrint('📋 사용 가능한 언어: ${availableLocales.length}개');

    // 한국어 locale 찾기
    final koreanLocale = availableLocales.firstWhere(
      (l) => l.localeId.startsWith('ko'),
      orElse: () => availableLocales.first,
    );

    final selectedLocaleId = koreanLocale.localeId;
    debugPrint('🌐 선택된 언어: $selectedLocaleId (${koreanLocale.name})');

    if (!mounted) return;

    // 음성 인식 시작 - 이전 인식 결과 초기화
    setState(() {
      _isListening = true;
      _confirmedLength = 0; // ⭐ 확정된 텍스트 길이 초기화
    });
    debugPrint('🔄 확정된 텍스트 길이 초기화됨 (0)');

    // ⭐ 전역 STT 상태 업데이트 (다른 탭에서도 확인 가능)
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    appState.setSTTActive(true);

    // ⭐ HTML 에디터 비활성화 - STT 중에는 키보드 입력 불필요
    try {
      _htmlController.disable();
      debugPrint('📝 HTML 에디터 비활성화 - 키보드 방지');
    } catch (e) {
      debugPrint('⚠️ HTML 에디터 비활성화 실패: $e');
    }

    // ⭐ 키보드 숨기기 - STT 중에는 키보드 입력 불필요
    if (mounted) {
      FocusScope.of(context).unfocus();
      debugPrint('⌨️ 키보드 숨김 - STT 시작');
    }

    // 약간의 딜레이 후 다시 한 번 키보드 숨김 (HTML 에디터의 자동 포커스 방지)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isListening && mounted) {
        FocusScope.of(context).unfocus();
        debugPrint('⌨️ 키보드 재숨김 (300ms 후)');
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (_isListening && mounted) {
        FocusScope.of(context).unfocus();
        debugPrint('⌨️ 키보드 재숨김 (600ms 후)');
      }
    });

    // ⭐ Wakelock 활성화 - 화면 잠금 방지 (STT 작동 유지)
    try {
      await WakelockPlus.enable();
      debugPrint('🔒 Wakelock 활성화 - 화면 잠금 방지');
    } catch (e) {
      debugPrint('⚠️ Wakelock 활성화 실패: $e');
    }

    debugPrint('✅ 음성 인식 시작');

    // STT 모드: 자동 요약 타이머 시작 (설정에 따라)
    if (_isSttMode) {
      _summaryTimer?.cancel();
      final interval = _sttSettings.summaryInterval;
      if (interval != null) {
        _summaryTimer = Timer.periodic(interval, (_) {
          debugPrint('⏰ [SttMode] 자동 요약 타이머 실행 (${interval.inMinutes}분)');
          _autoSummarizeStt();
        });
        debugPrint('⏰ [SttMode] 자동 요약 타이머 시작 (${interval.inMinutes}분 간격)');
      } else {
        debugPrint('ℹ️ [SttMode] 자동 요약 안함 설정');
      }
    }

    await _speechToText.listen(
      onResult: (result) {
        // ✅ 중복 입력 방지: STT 종료 후 들어오는 결과 무시
        if (!_isListening) {
          debugPrint('⚠️ STT 종료 후 onResult 호출됨 - 무시');
          return;
        }

        debugPrint(
          '📝 인식 결과 (isFinal: ${result.finalResult}): ${result.recognizedWords}',
        );

        if (result.recognizedWords.isEmpty) return;

        // 텍스트 파일이 선택되지 않았으면 자동 생성
        if (_currentTextFile == null) {
          debugPrint('⚠️ 텍스트 파일이 선택되지 않음 - 자동 생성');
          _createNewTextFile();
          // 파일 생성 직후에는 결과 무시 (다음 결과부터 반영)
          return;
        }

        // ⭐ 숫자 형식 개선 (10000000000 → 10,000,000,000)
        final currentText = _formatNumbers(result.recognizedWords);

        if (result.finalResult) {
          // 최종 결과: 임시 span을 검은색 텍스트로 즉시 확정
          debugPrint('🏁 최종 결과 - 즉시 확정: "$currentText"');

          // ⭐ 임시 span을 검은색 텍스트로 변환
          _convertPartialToFinal();

          // ⭐ 확정된 길이 업데이트
          if (_lastPartialText.isNotEmpty) {
            _confirmedLength += _lastPartialText.length;
            debugPrint('💾 최종 확정 길이: $_confirmedLength (추가: ${_lastPartialText.length})');
          }

          // 다음 인식을 위해 초기화
          setState(() {
            _lastPartialText = '';
          });

          debugPrint('✅ 다음 문장 인식 준비 완료');
        } else {
          // 중간 결과: 문자열 길이 기반 차분 계산으로 중복 방지
          debugPrint('💬 중간 결과 (실시간): "$currentText"');

          // ⭐ 문자열 길이 기반 차분 계산
          String newText = '';
          if (currentText.length > _confirmedLength) {
            // 확정된 부분 이후의 텍스트만 추출
            newText = currentText.substring(_confirmedLength);
          }

          debugPrint('   📊 길이 분석: 전체=${currentText.length}, 확정=$_confirmedLength, 신규=${newText.length}');
          debugPrint('   ✨ 차분 텍스트: "$newText"');

          // 차분만 임시 span에 표시
          if (newText.isNotEmpty) {
            _updatePartialSpan(newText);
            _lastPartialText = newText;
          }
        }
      },
      localeId: selectedLocaleId, // 사용 가능한 한국어 locale 사용
      pauseFor: const Duration(
        seconds: 300,
      ), // ⭐ 침묵 대기 시간 대폭 연장 (5분 동안 말이 없어도 계속 듣기)
      listenOptions: stt.SpeechListenOptions(
        partialResults: true, // 중간 결과도 표시 (실시간 입력용)
        cancelOnError: false, // 에러 발생 시에도 계속 듣기
        listenMode: stt.ListenMode.dictation, // 받아쓰기 모드 (iOS에서 긴 발화 인식에 필수)
        enableHapticFeedback: false,
        onDevice: true, // ⭐ 온디바이스 인식 (인터넷 연결 불필요)
      ),
    );

    // 🎙️ STT 시작 직후 녹음도 즉시 시작 (앞부분 누락 방지)
    if (mounted) {
      _startRecordingWithSTT();
    }

    // ⭐ STT 중 주기적 자동 저장 시작 (30초마다) - 파일 저장만 수행
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isListening && mounted) {
        debugPrint('⏰ STT 중 자동 저장 (30초 주기) - 파일만 저장');
        _saveCurrentTextFile();
      }
    });
    debugPrint('⏰ STT 자동 저장 타이머 시작 (30초 주기)');
  }

  /// 숫자 형식 개선 (10000000000 → 10,000,000,000)
  String _formatNumbers(String text) {
    // 4자리 이상 연속된 숫자를 찾아서 쉼표 추가
    return text.replaceAllMapped(
      RegExp(r'\b(\d{4,})\b'),
      (match) {
        final number = match.group(1)!;
        // 숫자를 역순으로 3자리마다 쉼표 추가
        final reversed = number.split('').reversed.join();
        final withCommas = reversed.replaceAllMapped(
          RegExp(r'(\d{3})(?=\d)'),
          (m) => '${m.group(1)},',
        );
        return withCommas.split('').reversed.join();
      },
    );
  }

  /// 중간 결과를 임시 span에 업데이트 (150ms 디바운스 — JS 큐 누적 방지)
  void _updatePartialSpan(String text) {
    _partialUpdateDebounce?.cancel();
    _partialUpdateDebounce = Timer(const Duration(milliseconds: 150), () {
      _executePartialSpanUpdate(text);
    });
  }

  void _executePartialSpanUpdate(String text) {
    final escapedText = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    final jsCode =
        '''
      (function() {
        try {
          var summernote = \$('#summernote-2');
          if (!summernote.length) return 'editor_not_found';

          summernote.summernote('focus');

          // 기존 임시 span이 있으면 제거
          var existingSpan = document.getElementById('stt-partial-text');
          if (existingSpan) {
            existingSpan.remove();
          }

          // 새 임시 span 삽입
          var span = document.createElement('span');
          span.id = 'stt-partial-text';
          span.style.color = '#999';
          span.style.fontStyle = 'italic';
          span.textContent = '$escapedText';

          // ⭐ 항상 에디터의 맨 끝에 삽입 (커서 위치 무시)
          var editable = summernote.next('.note-editor').find('.note-editable')[0];
          if (editable) {
            editable.appendChild(span);

            // ⭐ 커서를 span 뒤(= 문서 맨 끝)로 이동
            var selection = window.getSelection();
            if (selection) {
              var range = document.createRange();
              range.setStartAfter(span);
              range.collapse(true);
              selection.removeAllRanges();
              selection.addRange(range);
            }

            // ⭐ 자동 스크롤: 항상 맨 아래로
            setTimeout(function() {
              try {
                editable.scrollTop = editable.scrollHeight;
                window.scrollTo(0, document.body.scrollHeight);
                document.documentElement.scrollTop = document.documentElement.scrollHeight;
              } catch(e) {
                console.log('span 스크롤 에러:', e);
              }
            }, 50);
          }

          return 'success';
        } catch(e) {
          return 'error: ' + e.message;
        }
      })();
    ''';

    _htmlController.editorController
        ?.evaluateJavascript(source: jsCode)
        .then((result) {
          debugPrint('✅ 중간 결과 span 업데이트: $result');
        })
        .catchError((e) {
          debugPrint('❌ 중간 결과 span 업데이트 실패: $e');
        });
  }

  /// 임시 span을 최종 텍스트로 변환 (자동 저장 시점)
  void _convertPartialToFinal() {
    if (_lastPartialText.isEmpty) return;

    final jsCode = '''
      (function() {
        try {
          var span = document.getElementById('stt-partial-text');
          if (span) {
            // ⭐ 임시 span을 일반 텍스트 노드로 직접 교체 (커서 위치 유지)
            var text = span.textContent;
            var textNode = document.createTextNode(text + ' ');
            span.parentNode.replaceChild(textNode, span);

            // ⭐ 커서를 텍스트 노드 뒤로 이동 (다음 span이 올바른 위치에 삽입되도록)
            var selection = window.getSelection();
            if (selection) {
              var range = document.createRange();
              range.setStartAfter(textNode);
              range.collapse(true);
              selection.removeAllRanges();
              selection.addRange(range);
            }

            // ⭐ 자동 스크롤
            setTimeout(function() {
              try {
                var editable = document.querySelector('.note-editable');
                if (editable) editable.scrollTop = editable.scrollHeight;
                window.scrollTo(0, document.body.scrollHeight);
                document.documentElement.scrollTop = document.documentElement.scrollHeight;
              } catch(e) {}
            }, 50);

            return 'converted: ' + text;
          }
          return 'not_found';
        } catch(e) {
          return 'error: ' + e.message;
        }
      })();
    ''';

    _htmlController.editorController
        ?.evaluateJavascript(source: jsCode)
        .then((result) {
          debugPrint('💾 임시 텍스트를 저장됨 텍스트로 변환: $result');
          setState(() {
            _lastPartialText = '';
          });
        })
        .catchError((e) {
          debugPrint('❌ 임시 텍스트 변환 실패: $e');
        });
  }

  /// 임시 span 제거
  void _removePartialSpan() {
    final jsCode = '''
      (function() {
        try {
          var span = document.getElementById('stt-partial-text');
          if (span) {
            span.remove();
            return 'removed';
          }
          return 'not_found';
        } catch(e) {
          return 'error: ' + e.message;
        }
      })();
    ''';

    _htmlController.editorController
        ?.evaluateJavascript(source: jsCode)
        .then((result) {
          debugPrint('🗑️ 임시 span 제거: $result');
        })
        .catchError((e) {
          debugPrint('❌ 임시 span 제거 실패: $e');
        });
  }


  /// 음성 인식 재시작 (자동 재시작용)
  Future<void> _restartListening() async {
    debugPrint('🔄 STT 재시작 시작');

    // 재시작 전 partial 상태 정리 — 미확정 텍스트를 먼저 확정
    _partialUpdateDebounce?.cancel();
    if (_lastPartialText.isNotEmpty) {
      debugPrint('📝 재시작 전 미확정 텍스트 확정: $_lastPartialText');
      _convertPartialToFinal();
      _confirmedLength += _lastPartialText.length;
      _lastPartialText = '';
    }

    // 기존 STT 완전히 중지
    try {
      await _speechToText.stop();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('⚠️ STT 중지 실패 (재시작 시): $e');
    }

    // 수동 중지이거나 위젯이 해제된 경우 재시작 취소
    if (_isManualStop || !mounted) {
      debugPrint('⚠️ STT 재시작 취소 - _isManualStop=$_isManualStop');
      return;
    }

    // 새로운 STT 세션 시작
    await _startListening();
  }

  /// 음성 인식 중지
  Future<void> _stopListening() async {
    _isManualStop = true; // 사용자가 직접 중지 → 자동 재시작 금지
    debugPrint('🛑 음성 인식 중지 (수동)');

    // ⭐ 자동 저장 타이머 정리
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    // STT 자동 요약 타이머 정리
    _summaryTimer?.cancel();
    _summaryTimer = null;
    debugPrint('⏰ STT 자동 저장 타이머 중지');

    // ⭐ HTML 에디터 다시 활성화 - 키보드 입력 가능하도록
    try {
      _htmlController.enable();
      debugPrint('📝 HTML 에디터 활성화 - 키보드 입력 가능');
    } catch (e) {
      debugPrint('⚠️ HTML 에디터 활성화 실패: $e');
    }

    // ⭐ Wakelock 비활성화 - 화면 잠금 해제
    try {
      await WakelockPlus.disable();
      debugPrint('🔓 Wakelock 비활성화 - 화면 잠금 허용');
    } catch (e) {
      debugPrint('⚠️ Wakelock 비활성화 실패: $e');
    }

    // ✅ 중요: STT 중지 전에 상태 변경하여 추가 onResult 무시
    setState(() {
      _isListening = false;
    });

    // ⭐ 전역 STT 상태 업데이트 (다른 탭에서도 확인 가능)
    if (mounted) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.setSTTActive(false);
    }

    await _speechToText.stop();

    // ⚠️ STT 중지 후 약간 대기 - 마지막 onResult 처리 시간 확보
    await Future.delayed(const Duration(milliseconds: 200));

    // ✅ 텍스트 소실 방지: 임시 텍스트가 있다면 먼저 확정 입력
    if (_lastPartialText.isNotEmpty) {
      debugPrint('📝 임시 텍스트 확정 입력: $_lastPartialText');

      // 임시 span을 최종 텍스트로 교체
      await _replaceFinalText(_lastPartialText);

      debugPrint('✅ 텍스트 확정 입력 완료');
    } else {
      // 임시 텍스트가 없으면 span만 제거
      _removePartialSpan();
    }

    // 상태 초기화
    setState(() {
      _lastPartialText = '';
      _confirmedLength = 0; // ⭐ 확정 길이 초기화
    });
    debugPrint('🔄 STT 종료 - 확정 길이 초기화됨');

    // 🎙️ STT와 함께 녹음이 진행 중이었다면 녹음도 중지하고 파일 저장
    if (_isRecordingWithSTT) {
      await _stopRecordingWithSTT();
    }

    // 💾 STT 중지 시 텍스트 자동 저장 (편집 화면은 유지)
    debugPrint('💾 STT 종료 후 텍스트 자동 저장 시작...');
    await _saveCurrentTextFile();
    debugPrint('✅ STT 종료 후 텍스트 자동 저장 완료');

    // 📋 STT 모드: 타이머로 이미 생성된 요약만 파일에 추가 (수동 정지 시 신규 요약 생성 안함)
    if (_isSttMode && _sttSummary.isNotEmpty) {
      debugPrint('📋 [SttMode] STT 종료 - 기존 요약 파일에 추가');
      await _appendSummaryToFile();
    } else if (_isSttMode) {
      debugPrint('ℹ️ [SttMode] STT 종료 - 요약 없음, 건너뜀');
    }
  }

  /// 임시 span을 최종 텍스트로 교체 (STT 종료 시 사용)
  Future<void> _replaceFinalText(String text) async {
    final escapedText = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    final jsCode =
        '''
      (function() {
        try {
          var span = document.getElementById('stt-partial-text');
          if (span) {
            // 임시 span을 실제 텍스트 노드로 교체
            var textNode = document.createTextNode('$escapedText ');
            span.parentNode.replaceChild(textNode, span);
            return 'replaced';
          }

          // span이 없으면 그냥 텍스트 삽입
          var summernote = \$('#summernote-2');
          if (!summernote.length) return 'editor_not_found';
          summernote.summernote('focus');
          summernote.summernote('insertText', '$escapedText ');
          return 'inserted';
        } catch(e) {
          return 'error: ' + e.message;
        }
      })();
    ''';

    final result = await _htmlController.editorController?.evaluateJavascript(
      source: jsCode,
    );
    debugPrint('✅ 텍스트 교체/삽입: $result');
  }

  /// STT와 함께 녹음 시작 (예외 발생 시에도 STT는 계속 진행)
  Future<void> _startRecordingWithSTT() async {
    try {
      debugPrint('🎙️ STT 녹음 시작 시도...');

      // ⭐ STT가 이미 실행 중인지 확인 - 이 메서드는 STT 중에만 호출되므로 항상 true
      // 하지만 명시적으로 체크하지 않음 (이미 STT 컨텍스트에서 호출됨)

      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten == null) {
        debugPrint('⚠️ 리튼이 선택되지 않음 - 녹음 건너뜀');
        return;
      }

      // 녹음 시작 (실패해도 STT는 계속 진행되도록 try-catch로 감쌈)
      final started = await _audioService.startRecording(selectedLitten);

      if (started) {
        setState(() {
          _isRecordingWithSTT = true;
        });
        debugPrint('✅ STT 녹음 시작 성공');
      } else {
        debugPrint('⚠️ STT 녹음 시작 실패 - STT 텍스트 입력은 계속 진행');
      }
    } catch (e) {
      // 녹음 실패해도 STT는 계속 작동
      debugPrint('❌ STT 녹음 시작 오류: $e');
      debugPrint('💡 STT 텍스트 입력은 정상 작동 중');
    }
  }

  /// STT와 함께 시작한 녹음 중지 및 파일 저장
  Future<void> _stopRecordingWithSTT() async {
    _isStoppingRecording = true;
    try {
      debugPrint('🛑 STT 녹음 중지 시도...');

      // context 사용은 await 이전 (동기 구간)에서만 수행
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten == null) {
        debugPrint('⚠️ 리튼이 선택되지 않음');
        if (mounted) {
          setState(() { _isRecordingWithSTT = false; });
        } else {
          _isRecordingWithSTT = false;
        }
        return;
      }

      // 녹음 중지 및 파일 생성 (await 이후엔 위젯이 dispose됐을 수 있음)
      final audioFile = await _audioService.stopRecording(selectedLitten, isFromSTT: true);

      if (mounted) {
        setState(() { _isRecordingWithSTT = false; });
      } else {
        _isRecordingWithSTT = false;
      }

      if (audioFile != null) {
        debugPrint('✅ STT 녹음 파일 생성됨: ${audioFile.fileName}');

        // 리튼에 오디오 파일 추가 (context 불필요 — 파일 시스템 작업)
        await LittenService().addAudioFileToLitten(
          selectedLitten.id,
          audioFile.id,
        );

        debugPrint('✅ STT 녹음 파일이 리튼에 저장됨');

        // 클라우드 동기화 (context 불필요)
        SyncService.instance.uploadFile(
          littenId: audioFile.littenId,
          localId: audioFile.id,
          fileType: 'audio',
          fileName: audioFile.fileName,
          filePath: audioFile.filePath,
          localUpdatedAt: audioFile.updatedAt,
        );

        // ⚠️ refreshLittens() 호출하지 않음 - notifyListeners()가 화면 rebuild를 일으켜 편집 모드가 종료됨
        // 녹음 파일은 녹음 탭에서 확인 가능

        // 사용자에게 알림 (mounted 확인 후에만)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('녹음 파일이 저장되었습니다'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('⚠️ STT 녹음 파일 생성 실패');
      }
    } catch (e) {
      debugPrint('❌ STT 녹음 중지 오류: $e');
      if (mounted) {
        setState(() { _isRecordingWithSTT = false; });
      } else {
        _isRecordingWithSTT = false;
      }
    } finally {
      _isStoppingRecording = false;
    }
  }

  Future<void> _saveCurrentTextFile() async {
    if (_currentTextFile == null) return;

    // 동시 저장 방지 — 이전 저장이 끝나지 않았으면 스킵
    if (_isSaving) {
      debugPrint('⏩ 저장 스킵 - 이전 저장 진행 중');
      return;
    }
    _isSaving = true;

    try {
      debugPrint('💾 텍스트 파일 저장 시작 - ${_currentTextFile!.displayTitle}');

      // STT 중 자동 저장: getText() 생략하고 캐시된 콘텐츠 사용
      // (getText()는 WebView 왕복 비용이 크고 JS 큐를 블록함)
      String htmlContent;
      if (_isListening) {
        htmlContent = _currentTextFile!.content.isNotEmpty
            ? _currentTextFile!.content
            : '<p><br></p>';
        debugPrint('⏩ STT 중 저장 - 캐시된 콘텐츠 사용 (${htmlContent.length}자)');
      } else {
        try {
          htmlContent = await _htmlController.getText();
          debugPrint('📄 HTML 내용 로드됨 - ${htmlContent.length}자');
        } catch (e) {
          debugPrint('⚠️ HTML 콘텐츠 가져오기 실패, 기존 내용 사용: $e');
          htmlContent = _currentTextFile?.content ?? '';
        }
      }

        // 빈 내용이어도 저장 가능하도록 수정
        final updatedFile = _currentTextFile!.copyWith(
          content: htmlContent.isEmpty
              ? '<p><br></p>'
              : htmlContent, // 빈 내용일 때 기본 HTML 추가
        );

        // 파일 목록에 추가 또는 업데이트
        final existingIndex = _textFiles.indexWhere(
          (f) => f.id == updatedFile.id,
        );
        if (existingIndex >= 0) {
          _textFiles[existingIndex] = updatedFile;
          print('디버그: 기존 텍스트 파일 업데이트됨 - ${updatedFile.displayTitle}');
        } else {
          _textFiles.add(updatedFile);
          print('디버그: 새로운 텍스트 파일 추가됨 - ${updatedFile.displayTitle}');
        }

        // ⭐ 최근 파일이 위로 오도록 다시 정렬 (updatedAt 기준 내림차순)
        _textFiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // 실제 파일 시스템에 저장
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final selectedLitten = appState.selectedLitten;

        if (selectedLitten != null) {
          final storage = FileStorageService.instance;

          // HTML 콘텐츠를 파일로 저장
          await storage.saveTextFileContent(updatedFile);

          // 파일 목록을 SharedPreferences에 저장
          await storage.saveTextFiles(selectedLitten.id, _textFiles);

          // 리튼의 파일 목록 업데이트
          final littenService = LittenService();
          if (existingIndex >= 0) {
            // 기존 파일 업데이트는 추가 작업 불필요
          } else {
            // 새 파일 추가
            await littenService.addTextFileToLitten(
              selectedLitten.id,
              updatedFile.id,
            );
          }

          // 새 파일 추가 시에만 카운트 업데이트 (기존 파일 수정은 제외)
          if (existingIndex < 0) {
            await appState.updateFileCount();
          }
        }

        debugPrint('✅ 텍스트 파일 저장 완료 - 총 ${_textFiles.length}개 파일');

        // 클라우드 동기화 (STT 자동 저장 제외, 실패해도 앱 흐름에 영향 없음)
        if (selectedLitten != null && !_isListening) {
          final htmlFilePath = '${(await getApplicationDocumentsDirectory()).path}/littens/${selectedLitten.id}/text/${updatedFile.id}.html';
          if (existingIndex >= 0 && updatedFile.cloudId != null) {
            SyncService.instance.updateFile(
              littenId: updatedFile.littenId,
              localId: updatedFile.id,
              cloudId: updatedFile.cloudId!,
              fileType: 'text',
              filePath: htmlFilePath,
              localUpdatedAt: updatedFile.updatedAt,
            );
          } else {
            SyncService.instance.uploadFile(
              littenId: updatedFile.littenId,
              localId: updatedFile.id,
              fileType: 'text',
              fileName: '${updatedFile.id}.html',
              filePath: htmlFilePath,
              localUpdatedAt: updatedFile.updatedAt,
            );
          }
        }

        // STT 중 자동 저장 시에는 스낵바 표시 안 함 (방해 방지)
        if (mounted && !_isListening) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장되었습니다'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ 텍스트 파일 저장 실패 - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        _isSaving = false;
      }
  }

  Widget _buildCloudSyncIcon(SyncStatus status, bool isPremium) {
    if (!isPremium) return const SizedBox.shrink();
    switch (status) {
      case SyncStatus.synced:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.cloud_done, color: Colors.blue, size: 18),
        );
      case SyncStatus.pending:
      case SyncStatus.syncing:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.cloud_upload, color: Colors.orange, size: 18),
        );
      case SyncStatus.error:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.cloud_off, color: Colors.red, size: 18),
        );
      case SyncStatus.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextFileItem(TextFile file) {
    final isFromSTT = file.isFromSTT;
    final color = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(Icons.notes, color: color),
              ),
              if (isFromSTT)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.record_voice_over, size: 10, color: Colors.white),
                  ),
                ),
              // 요약 아이콘 (STT 요약이 있을 때)
              if (file.hasSummary)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          file.title.isNotEmpty
              ? file.title
              : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            // 글자 수 표시
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${file.characterCount}자',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 수정 날짜
            Expanded(
              child: Text(
                file.updatedAt.toString().substring(0, 16),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCloudSyncIcon(
              file.syncStatus,
              Provider.of<AppStateProvider>(context, listen: false).isPremiumPlusUser,
            ),
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () => _showRenameDialog(file),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () => _showDeleteConfirmDialog(file.displayTitle, () {
                _deleteTextFile(file);
              }),
            ),
          ],
        ),
        onTap: () => _editTextFile(file),
      ),
    );
  }

  /// 커스텀 툴바 빌드 (STT 버튼 + 서식 버튼들)
  Widget _buildCustomToolbar() {
    // STT 모드: 2줄 툴바
    if (_isSttMode) return _buildSttToolbar();

    // 일반 메모 모드: 서식 툴바
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 서식 버튼들 (일반 메모 모드에서만 표시)
            if (!_isSttMode) ...[
            // 2. 굵게 (Bold)
            _buildToolbarButton(
              icon: Icons.format_bold,
              onPressed: () => _execCommand('bold'),
              tooltip: '굵게',
            ),
            // 3. 기울임 (Italic)
            _buildToolbarButton(
              icon: Icons.format_italic,
              onPressed: () => _execCommand('italic'),
              tooltip: '기울임',
            ),
            // 4. 밑줄 (Underline)
            _buildToolbarButton(
              icon: Icons.format_underline,
              onPressed: () => _execCommand('underline'),
              tooltip: '밑줄',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 5. 글자 색상
            _buildToolbarButton(
              icon: Icons.format_color_text,
              onPressed: () => _showColorPicker(isBackground: false),
              tooltip: '글자 색상',
            ),
            // 6. 배경 색상
            _buildToolbarButton(
              icon: Icons.format_color_fill,
              onPressed: () => _showColorPicker(isBackground: true),
              tooltip: '배경 색상',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 7. 글머리 기호 목록
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              onPressed: () => _execCommand('insertUnorderedList'),
              tooltip: '글머리 기호',
            ),
            // 8. 번호 매기기 목록
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              onPressed: () => _execCommand('insertOrderedList'),
              tooltip: '번호 매기기',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 9. 취소선
            _buildToolbarButton(
              icon: Icons.format_strikethrough,
              onPressed: () => _execCommand('strikeThrough'),
              tooltip: '취소선',
            ),
            // 10. 위 첨자
            _buildToolbarButton(
              icon: Icons.superscript,
              onPressed: () => _execCommand('superscript'),
              tooltip: '위 첨자',
            ),
            // 11. 아래 첨자
            _buildToolbarButton(
              icon: Icons.subscript,
              onPressed: () => _execCommand('subscript'),
              tooltip: '아래 첨자',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 12. 왼쪽 정렬
            _buildToolbarButton(
              icon: Icons.format_align_left,
              onPressed: () => _execCommand('justifyLeft'),
              tooltip: '왼쪽 정렬',
            ),
            // 13. 가운데 정렬
            _buildToolbarButton(
              icon: Icons.format_align_center,
              onPressed: () => _execCommand('justifyCenter'),
              tooltip: '가운데 정렬',
            ),
            // 14. 오른쪽 정렬
            _buildToolbarButton(
              icon: Icons.format_align_right,
              onPressed: () => _execCommand('justifyRight'),
              tooltip: '오른쪽 정렬',
            ),
            // 15. 양쪽 정렬
            _buildToolbarButton(
              icon: Icons.format_align_justify,
              onPressed: () => _execCommand('justifyFull'),
              tooltip: '양쪽 정렬',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 16. 들여쓰기
            _buildToolbarButton(
              icon: Icons.format_indent_increase,
              onPressed: () => _execCommand('indent'),
              tooltip: '들여쓰기',
            ),
            // 17. 내어쓰기
            _buildToolbarButton(
              icon: Icons.format_indent_decrease,
              onPressed: () => _execCommand('outdent'),
              tooltip: '내어쓰기',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 18. 인용
            _buildToolbarButton(
              icon: Icons.format_quote,
              onPressed: () =>
                  _execCommand('formatBlock', argument: 'blockquote'),
              tooltip: '인용',
            ),
            // 19. 코드
            _buildToolbarButton(
              icon: Icons.code,
              onPressed: () => _execCommand('formatBlock', argument: 'pre'),
              tooltip: '코드',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 20. 전체 선택
            _buildToolbarButton(
              icon: Icons.select_all,
              onPressed: () => _execCommand('selectAll'),
              tooltip: '전체 선택',
            ),
            // 21. 실행 취소
            _buildToolbarButton(
              icon: Icons.undo,
              onPressed: () => _execCommand('undo'),
              tooltip: '실행 취소',
            ),
            // 22. 다시 실행
            _buildToolbarButton(
              icon: Icons.redo,
              onPressed: () => _execCommand('redo'),
              tooltip: '다시 실행',
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // 23. 서식 지우기
            _buildToolbarButton(
              icon: Icons.format_clear,
              onPressed: () => _execCommand('removeFormat'),
              tooltip: '서식 지우기',
            ),
            // 24. 링크 삽입
            _buildToolbarButton(
              icon: Icons.link,
              onPressed: () => _showLinkDialog(),
              tooltip: '링크 삽입',
            ),
            // 25. 가로선
            _buildToolbarButton(
              icon: Icons.horizontal_rule,
              onPressed: () => _execCommand('insertHorizontalRule'),
              tooltip: '가로선',
            ),
            ], // end if (!_isSttMode)
          ],
        ),
      ),
    );
  }

  /// STT 전용 2줄 툴바
  Widget _buildSttToolbar() {
    const kLangs = [
      ('ko', '한국어'), ('en', 'English'), ('zh', '中文'), ('ja', '日本語'),
      ('hi', 'हिन्दी'), ('es', 'Español'), ('fr', 'Français'), ('ar', 'العربية'),
      ('bn', 'বাংলা'), ('ru', 'Русский'), ('pt', 'Português'), ('ur', 'اردو'),
      ('id', 'Bahasa Indonesia'), ('de', 'Deutsch'), ('sw', 'Kiswahili'),
      ('mr', 'मराठी'), ('te', 'తెలుగు'), ('tr', 'Türkçe'), ('ta', 'தமிழ்'),
      ('fa', 'فارسی'), ('uk', 'Українська'), ('it', 'Italiano'), ('tl', 'Filipino'),
      ('pl', 'Polski'), ('ps', 'پښتو'), ('ms', 'Bahasa Melayu'), ('ro', 'Română'),
      ('nl', 'Nederlands'), ('ha', 'Hausa'), ('th', 'ไทย'),
    ];
    final color = Theme.of(context).primaryColor;
    final bgColor = color.withValues(alpha: 0.1);
    final dropStyle = TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500);

    Widget langDropdown(String value, ValueChanged<String?> onChanged) =>
        DropdownButton<String>(
          value: value,
          isDense: true,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, size: 14, color: color),
          style: dropStyle,
          dropdownColor: Theme.of(context).cardColor,
          items: kLangs.map((l) => DropdownMenuItem(
            value: l.$1,
            child: Text('${l.$2}(${l.$1})', overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color)),
          )).toList(),
          onChanged: onChanged,
        );

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // STT 시작/중지 버튼
          Consumer<AppStateProvider>(
            builder: (context, appState, child) {
              final isActive = _isListening || _audioService.isRecording;
              return InkWell(
                onTap: _toggleSpeechToText,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(
                    isActive ? Icons.stop : Icons.mic_none,
                    color: color,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          Container(width: 1, height: 20, color: color.withValues(alpha: 0.4),
            margin: const EdgeInsets.symmetric(horizontal: 8)),
          // 전사 언어 (변경 시 요약언어 동기화)
          langDropdown(_sttSettings.textLanguage, (v) {
            if (v != null) _onSttSettingChanged(textLanguage: v, summaryLanguage: v);
          }),
        ],
      ),
    );
  }

  /// STT 툴바 구분선 (| 스타일)
  Widget _sttSeparator() => Container(
    width: 1,
    height: 20,
    color: Colors.grey.shade400,
    margin: const EdgeInsets.symmetric(horizontal: 5),
  );

  /// 툴바 버튼 위젯 빌드
  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: Colors.grey.shade800),
        ),
      ),
    );
  }

  /// HTML 에디터 명령 실행
  void _execCommand(String command, {String? argument}) {
    debugPrint(
      '🔧 에디터 명령 실행: $command${argument != null ? " (인자: $argument)" : ""}',
    );
    if (argument != null) {
      _htmlController.execCommand(command, argument: argument);
    } else {
      _htmlController.execCommand(command);
    }
  }

  /// 링크 삽입 다이얼로그 표시
  void _showLinkDialog() {
    final urlController = TextEditingController();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('링크 삽입'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: '링크 텍스트',
                hintText: '표시될 텍스트 입력',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              final text = textController.text.trim();
              if (url.isNotEmpty) {
                final linkText = text.isNotEmpty ? text : url;
                _htmlController.insertLink(linkText, url, true);
              }
              Navigator.pop(context);
            },
            child: const Text('삽입'),
          ),
        ],
      ),
    );
  }

  /// 색상 선택 다이얼로그 표시
  void _showColorPicker({required bool isBackground}) {
    // 기본 색상 팔레트
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBackground ? '배경 색상 선택' : '글자 색상 선택'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            return InkWell(
              onTap: () {
                final colorHex =
                    '#${color.value.toRadixString(16).substring(2)}';
                if (isBackground) {
                  _htmlController.execCommand('backColor', argument: colorHex);
                } else {
                  _htmlController.execCommand('foreColor', argument: colorHex);
                }
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_isListening, // STT 진행 중일 때는 뒤로가기 방지
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // STT 진행 중일 때 뒤로가기 시도 시 경고
        if (_isListening) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('음성 인식을 먼저 중지해주세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Column(
        children: [
        // 상단 헤더
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _isListening ? null : () async {
                  if (widget.onClose != null) {
                    widget.onClose!();
                    return;
                  }
                  await _loadFiles();
                  setState(() {
                    _isEditing = false;
                    _currentTextFile = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _currentTextFile?.displayTitle ?? '새 텍스트',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: _saveCurrentTextFile,
                child: Text(l10n?.save ?? '저장'),
              ),
            ],
          ),
        ),

        // 에디터 + 요약 영역 (STT 모드: 1/3 + 2/3, 일반: 전체)
        Expanded(
          child: _isSttMode
              ? Column(
                  children: [
                    // 전사 영역 (1/3)
                    Expanded(
                      flex: 1,
                      child: _buildEditorContainer(),
                    ),
                    // 요약 영역 (2/3)
                    Expanded(
                      flex: 2,
                      child: _buildSttSummaryArea(),
                    ),
                  ],
                )
              : _buildEditorContainer(),
        ),
      ], // Column children 닫기 (outer)
    ), // Column 닫기 (outer)
    ); // PopScope 닫기
  } // _buildTextEditor 닫기

  // 에디터 컨테이너 (툴바 + HTML 에디터)
  Widget _buildEditorContainer() {
    return Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  // 커스텀 툴바 (STT 버튼 포함)
                  _buildCustomToolbar(),
                  // HTML 에디터
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: HtmlEditor(
                              controller: _htmlController,
                              htmlEditorOptions: const HtmlEditorOptions(
                                hint: '',  // placeholder 제거
                                shouldEnsureVisible: true,
                                adjustHeightForKeyboard: true,
                                darkMode: false,
                                autoAdjustHeight: false,
                                spellCheck: false,
                              ),
                              htmlToolbarOptions: const HtmlToolbarOptions(
                                toolbarPosition: ToolbarPosition.aboveEditor,
                                toolbarType: ToolbarType.nativeScrollable,
                                renderBorder: false,
                                toolbarItemHeight: 0, // 높이를 0으로 설정하여 숨김
                                defaultToolbarButtons: [], // 기본 버튼 없음
                              ),
                              otherOptions: const OtherOptions(height: 350),
                              callbacks: Callbacks(
                                onInit: () {
                                  debugPrint('📝 [TextTab] HTML 에디터 초기화 완료');
                                  _editorInitialized = true;

                                  // pendingContent가 있으면 로드
                                  if (_pendingContent != null) {
                                    final content = _pendingContent!;
                                    _pendingContent = null;
                                    Future.delayed(const Duration(milliseconds: 200), () {
                                      if (mounted) {
                                        debugPrint('📂 [TextTab] onInit - pendingContent 로드 (길이: ${content.length})');
                                        try {
                                          _htmlController.setText(content);
                                        } catch (e) {
                                          debugPrint('❌ [TextTab] onInit setText 에러: $e');
                                        }
                                      }
                                    });
                                  }

                                  // CSS 주입 및 커서 설정
                                  _htmlController.editorController
                                      ?.evaluateJavascript(
                                        source: '''
                              setTimeout(function() {
                                // CSS 주입
                                var style = document.createElement('style');
                                style.innerHTML = 'body { margin: 0 !important; padding: 8px !important; } p { margin: 0 !important; padding: 0 !important; line-height: 1.5 !important; } div { margin: 0 !important; padding: 0 !important; } br { margin: 0 !important; padding: 0 !important; } * { margin-top: 0 !important; margin-bottom: 0 !important; }';
                                document.head.appendChild(style);

                                // 커서 위치로 스크롤하는 함수
                                function scrollToCursor() {
                                  try {
                                    var selection = window.getSelection();
                                    if (selection && selection.rangeCount > 0) {
                                      var range = selection.getRangeAt(0);
                                      var rect = range.getBoundingClientRect();

                                      // 커서가 화면 밖에 있으면 스크롤
                                      var viewportHeight = window.innerHeight;
                                      var scrollThreshold = 100; // 상하 100px 여유 공간

                                      if (rect.top < scrollThreshold || rect.bottom > viewportHeight - scrollThreshold) {
                                        var scrollTop = window.pageYOffset + rect.top - (viewportHeight / 2);
                                        window.scrollTo({top: scrollTop, behavior: 'smooth'});
                                      }
                                    }
                                  } catch (e) {
                                    console.log('스크롤 오류:', e);
                                  }
                                }

                                // 선택 해제 및 커서를 맨 끝으로 이동
                                try {
                                  var summernote = \$('#summernote-2');
                                  if (summernote.length) {
                                    summernote.summernote('focus');

                                    // 선택 해제
                                    var selection = window.getSelection();
                                    if (selection) {
                                      selection.removeAllRanges();
                                    }

                                    // 커서를 맨 끝으로 이동
                                    var editable = summernote.next('.note-editor').find('.note-editable')[0];
                                    if (editable) {
                                      var range = document.createRange();
                                      var sel = window.getSelection();

                                      // 에디터의 마지막 자식 노드로 이동
                                      if (editable.childNodes.length > 0) {
                                        var lastNode = editable.childNodes[editable.childNodes.length - 1];
                                        range.setStart(lastNode, lastNode.textContent ? lastNode.textContent.length : 0);
                                      } else {
                                        range.setStart(editable, 0);
                                      }

                                      range.collapse(true);
                                      sel.removeAllRanges();
                                      sel.addRange(range);
                                    }

                                    // ⭐ 키보드 입력 및 클릭 시 커서로 스크롤
                                    summernote.on('summernote.keyup summernote.mouseup summernote.change', function() {
                                      setTimeout(scrollToCursor, 50);
                                    });
                                  }
                                } catch (e) {
                                  console.log('커서 설정 오류:', e);
                                }
                              }, 500);
                            ''',
                                      );
                                },
                                onFocus: () {
                                  print('HTML 에디터 포커스됨');
                                  // 포커스 시 자동 선택 방지 및 커서 위치로 스크롤
                                  _htmlController.editorController
                                      ?.evaluateJavascript(
                                        source: '''
                                setTimeout(function() {
                                  try {
                                    var selection = window.getSelection();
                                    if (selection && selection.toString().length > 0) {
                                      // 선택된 텍스트가 있으면 커서를 선택 끝으로 이동
                                      var range = selection.getRangeAt(0);
                                      range.collapse(false); // 선택 끝으로 커서 이동
                                      selection.removeAllRanges();
                                      selection.addRange(range);
                                    }

                                    // 커서 위치로 스크롤
                                    if (selection && selection.rangeCount > 0) {
                                      var range = selection.getRangeAt(0);
                                      var rect = range.getBoundingClientRect();

                                      // 커서가 화면 밖에 있으면 스크롤
                                      if (rect.top < 0 || rect.bottom > window.innerHeight) {
                                        var scrollTop = window.pageYOffset + rect.top - (window.innerHeight / 2);
                                        window.scrollTo({top: scrollTop, behavior: 'smooth'});
                                      }
                                    }
                                  } catch (e) {
                                    console.log('포커스 처리 오류:', e);
                                  }
                                }, 100);
                              ''',
                                      );
                                },
                                onBlur: () {
                                  print('HTML 에디터 포커스 해제됨');
                                },
                              ),
                            ), // HtmlEditor 닫기
                          ), // SizedBox 닫기
                        ); // SingleChildScrollView 닫기
                      }, // LayoutBuilder builder 닫기
                    ), // LayoutBuilder 닫기
                  ), // Expanded 닫기 (에디터)
                ], // Column children 닫기 (inner)
              ), // Column 닫기 (inner)
            ), // ClipRRect 닫기
          ); // Container 닫기 (_buildEditorContainer)
  }

  // STT 모드 자동 요약 (10분마다 호출)
  Future<void> _autoSummarizeStt() async {
    if (_isSummarizing || !mounted) return;

    String content;
    try {
      content = await _htmlController.getText();
    } catch (e) {
      content = _currentTextFile?.content ?? '';
    }

    final plain = content.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (plain.isEmpty) {
      debugPrint('ℹ️ [SttMode] 요약할 전사 내용 없음 - 스킵');
      return;
    }

    debugPrint('✨ [SttMode] 자동 요약 시작 - 전사 길이: ${plain.length}');
    setState(() => _isSummarizing = true);

    try {
      final apiService = ApiService();
      final summary = await apiService.summarizeText(
        text: content,
        textLanguage: _sttSettings.textLanguage,
        summaryLanguage: _sttSettings.summaryLanguage,
        summaryRatio: _sttSettings.summaryRatio,
        fileId: _currentTextFile?.id,
      );
      debugPrint('✨ [SttMode] 자동 요약 완료 - 길이: ${summary.length}');
      if (mounted) {
        setState(() => _sttSummary = summary);
        // TextFile.summary 업데이트 → 파일 목록 요약 아이콘 활성화
        if (_currentTextFile != null) {
          _currentTextFile = _currentTextFile!.copyWith(summary: summary);
          await _saveCurrentTextFile();
          debugPrint('💾 [SttMode] 요약 TextFile에 저장 완료');
        }
      }
    } catch (e) {
      debugPrint('❌ [SttMode] 자동 요약 실패: $e');
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  // 요약 텍스트(마크다운 유사)를 HTML로 변환
  String _summaryToHtml(String summary) {
    final lines = summary.split('\n');
    final buf = StringBuffer();
    buf.write('<hr/><p><strong>📋 AI 요약</strong></p>');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('# ')) {
        buf.write('<p><strong>${trimmed.substring(2)}</strong></p>');
      } else {
        buf.write('<p>$trimmed</p>');
      }
    }
    return buf.toString();
  }

  // STT 종료 시 요약 내용을 파일 끝에 추가하고 저장
  Future<void> _appendSummaryToFile() async {
    if (_sttSummary.isEmpty || _currentTextFile == null) return;
    debugPrint('📋 [SttMode] 요약 파일 추가 시작 - 길이: ${_sttSummary.length}');

    try {
      String currentHtml;
      try {
        currentHtml = await _htmlController.getText();
      } catch (e) {
        currentHtml = _currentTextFile?.content ?? '';
      }

      final summaryHtml = _summaryToHtml(_sttSummary);
      final newHtml = currentHtml + summaryHtml;

      _htmlController.setText(newHtml);
      debugPrint('📋 [SttMode] 에디터에 요약 삽입 완료');

      await Future.delayed(const Duration(milliseconds: 300));
      await _saveCurrentTextFile();
      debugPrint('✅ [SttMode] 요약 포함 저장 완료');
    } catch (e) {
      debugPrint('❌ [SttMode] 요약 파일 추가 실패: $e');
    }
  }

  // STT 요약 영역 위젯
  // AI 요약 헤더 탭 → 설정 바텀시트
  // STT 설정 변경 (언어/비율/주기 통합)
  void _onSttSettingChanged({
    String? textLanguage,
    String? summaryLanguage,
    int? summaryRatio,
    int? summaryIntervalMinutes,
  }) {
    final newSettings = SttMemoSettings(
      textLanguage: textLanguage ?? _sttSettings.textLanguage,
      summaryLanguage: summaryLanguage ?? _sttSettings.summaryLanguage,
      summaryRatio: summaryRatio ?? _sttSettings.summaryRatio,
      summaryIntervalMinutes: summaryIntervalMinutes ?? _sttSettings.summaryIntervalMinutes,
    );
    setState(() => _sttSettings = newSettings);
    // 주기가 변경된 경우 타이머 재시작
    if (summaryIntervalMinutes != null) {
      _summaryTimer?.cancel();
      _summaryTimer = null;
      final interval = newSettings.summaryInterval;
      if (_isListening && interval != null) {
        _summaryTimer = Timer.periodic(interval, (_) => _autoSummarizeStt());
        debugPrint('⏰ [SttMode] 주기 변경 - 타이머 재시작 (${interval.inMinutes}분)');
      }
    }
  }

  Widget _buildSttSummaryArea() {
    final color = Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 타이틀 + 드롭다운 (우측 끝까지 배경 확장)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // 좌측: AI 요약 레이블
                Icon(Icons.auto_awesome, size: 13, color: color),
                const SizedBox(width: 4),
                Text('AI 요약',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                const Spacer(),
                // 우측: 드롭다운들
                // 요약언어
                DropdownButton<String>(
                  value: _sttSettings.summaryLanguage,
                  isDense: true,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, size: 14, color: color),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                  dropdownColor: Theme.of(context).cardColor,
                  items: const [
                    ('ko', '한국어'), ('en', 'English'), ('zh', '中文'), ('ja', '日本語'),
                    ('hi', 'हिन्दी'), ('es', 'Español'), ('fr', 'Français'), ('ar', 'العربية'),
                    ('bn', 'বাংলা'), ('ru', 'Русский'), ('pt', 'Português'), ('ur', 'اردو'),
                    ('id', 'Bahasa Indonesia'), ('de', 'Deutsch'), ('sw', 'Kiswahili'),
                    ('mr', 'मराठी'), ('te', 'తెలుగు'), ('tr', 'Türkçe'), ('ta', 'தமிழ்'),
                    ('fa', 'فارسی'), ('uk', 'Українська'), ('it', 'Italiano'), ('tl', 'Filipino'),
                    ('pl', 'Polski'), ('ps', 'پښتو'), ('ms', 'Bahasa Melayu'), ('ro', 'Română'),
                    ('nl', 'Nederlands'), ('ha', 'Hausa'), ('th', 'ไทย'),
                  ].map((l) => DropdownMenuItem(
                    value: l.$1,
                    child: Text('${l.$2}(${l.$1})', overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: color)),
                  )).toList(),
                  onChanged: (v) => _onSttSettingChanged(summaryLanguage: v),
                ),
                const SizedBox(width: 4),
                // 요약시간
                DropdownButton<int>(
                  value: _sttSettings.summaryIntervalMinutes,
                  isDense: true,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, size: 14, color: color),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                  dropdownColor: Theme.of(context).cardColor,
                  items: const [(1, '1분'), (3, '3분'), (5, '5분'), (10, '10분'), (0, '안함')]
                      .map((opt) => DropdownMenuItem(
                        value: opt.$1,
                        child: Text(opt.$2, style: TextStyle(fontSize: 11, color: color)),
                      )).toList(),
                  onChanged: (v) => _onSttSettingChanged(summaryIntervalMinutes: v),
                ),
                const SizedBox(width: 4),
                // 요약률
                DropdownButton<int>(
                  value: _sttSettings.summaryRatio,
                  isDense: true,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, size: 14, color: color),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                  dropdownColor: Theme.of(context).cardColor,
                  items: const [10, 20, 30, 40, 50, 60, 70, 80, 90]
                      .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text('$r%', style: TextStyle(fontSize: 11, color: color)),
                      )).toList(),
                  onChanged: (v) => _onSttSettingChanged(summaryRatio: v),
                ),
              ],
            ),
          ),
          // 요약 내용
          Expanded(
            child: _isSummarizing
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: color, strokeWidth: 2),
                        const SizedBox(height: 8),
                        Text('요약 중...', style: TextStyle(fontSize: 12, color: color)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _sttSummary.isEmpty
                        ? Text(
                            _sttSettings.summaryIntervalMinutes > 0
                                ? '녹음 시작 후 ${_sttSettings.summaryIntervalMinutes}분마다 자동으로 요약됩니다.'
                                : '자동 요약이 비활성화되어 있습니다.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.6),
                          )
                        : Text(
                            _sttSummary,
                            style: const TextStyle(fontSize: 13, height: 1.6),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
