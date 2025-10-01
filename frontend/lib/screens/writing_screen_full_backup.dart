import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../services/bookmark_service.dart';
import '../services/session_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/webview/bookmark_widget.dart';
import '../widgets/draggable_tab_layout.dart';
import '../config/themes.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../models/audio_file.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late HtmlEditorController _htmlController;
  late PainterController _painterController;
  late TabController _tabController;
  final AudioService _audioService = AudioService();

  // 파일 목록 관련
  List<TextFile> _textFiles = [];
  List<HandwritingFile> _handwritingFiles = [];
  List<AudioFile> _audioFiles = [];
  bool _isLoading = false;

  // WebView 관련 상태
  WebViewController? _webViewController;
  String _currentUrl = '';
  final TextEditingController _urlController = TextEditingController();
  final BookmarkService _bookmarkService = BookmarkService();
  final SessionService _sessionService = SessionService();
  bool _isCurrentUrlBookmarked = false;
  bool _showBookmarks = false;

  // 필기 모드 관련 상태
  Color _selectedColor = Colors.black;
  double _strokeWidth = 2.0;
  List<Uint8List>? _pdfPages;
  int _currentPdfPage = 0;

  // 툴바 상태 관리
  bool _isBoldActive = false;
  bool _isItalicActive = false;
  bool _isUnderlineActive = false;
  String? _backgroundImagePath;
  String _selectedTool = '펜';
  bool _isGestureMode = false; // 제스처 모드 (확대/축소/이동)
  bool _showAdvancedTools = false;
  bool _showColorPicker = false;
  double? _backgroundImageAspectRatio;
  Size? _backgroundImageOriginalSize;

  // 제스처 및 애니메이션 관련
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  // 페이지 네비게이션을 위한 수평 스크롤 감지 변수들
  Offset? _panStartPosition;
  Offset? _lastFocalPoint;
  bool _isPanningHorizontally = false;
  static const double _panThreshold = 100.0; // 페이지 전환을 위한 최소 거리
  static const double _panVelocityThreshold = 500.0; // 페이지 전환을 위한 최소 속도
  static const double _edgeThreshold = 50.0; // 스크롤 경계 감지 임계값
  bool _hasReachedLeftEdge = false;
  bool _hasReachedRightEdge = false;

  // 더블 탭 페이지 네비게이션 관련
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 500);
  static const double _doubleTapDistanceThreshold = 50.0;

  // 캔버스 내 텍스트 입력 관련
  bool _isTextInputMode = false;
  TextEditingController? _canvasTextController;
  FocusNode? _canvasTextFocusNode;
  Offset? _textInputPosition;
  Offset? _screenTextInputPosition; // 화면 좌표계 위치

  bool _showDrawingToolbar = true; // 필기 툴바 표시 상태
  Size? _canvasSize; // 실제 캔버스 크기 저장

  // 줌 기능 관련
  late TransformationController _transformationController;
  static const double _minScale = 0.3;
  static const double _maxScale = 8.0;

  // PDF 변환 진행 상태
  bool _isConverting = false;
  int _convertedPages = 0;
  int _totalPagesToConvert = 0;
  String _conversionStatus = '';
  bool _conversionCancelled = false;

  // 편집 상태
  TextFile? _currentTextFile;
  HandwritingFile? _currentHandwritingFile;
  bool _isEditing = false;

  // 드래그 가능한 탭 레이아웃
  List<TabItem> _tabItems = [];
  bool _useFlexibleLayout = false; // 유연한 레이아웃 사용 여부

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _htmlController = HtmlEditorController();
    _painterController = PainterController();
    _transformationController = TransformationController();
    _tabController = TabController(length: 4, vsync: this);

    // 애니메이션 컨트롤러 초기화
    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 텍스트 입력 컨트롤러 초기화
    _canvasTextController = TextEditingController();
    _canvasTextFocusNode = FocusNode();

    // 초기 펜 모드 설정
    _painterController.freeStyleMode = FreeStyleMode.draw;
    _painterController.freeStyleStrokeWidth = _strokeWidth;
    _painterController.freeStyleColor = _selectedColor;

    _loadFiles();
  }

  // 캔버스를 좌상단으로 초기화하는 함수 (중복 호출 방지)
  bool _isResettingCanvas = false;

  void _resetCanvasToTopLeft() {
    if (_isResettingCanvas) return; // 이미 진행 중이면 무시

    _isResettingCanvas = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (mounted && _transformationController.value != Matrix4.identity()) {
          _transformationController.value = Matrix4.identity();
        }
      } finally {
        _isResettingCanvas = false;
      }
    });
  }

  // 부드러운 애니메이션으로 변환 매트릭스 적용
  void _animateToTransform(Matrix4 targetMatrix) {
    final Matrix4 startMatrix = _transformationController.value.clone();

    _zoomAnimation = Matrix4Tween(begin: startMatrix, end: targetMatrix)
        .animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _zoomAnimation!.addListener(() {
      if (mounted) {
        _transformationController.value = _zoomAnimation!.value;
      }
    });

    _zoomAnimationController.reset();
    _zoomAnimationController.forward();
  }

  Timer? _focusTimer;
  bool _isKeyboardVisible = false;
  bool _hasAutoFocused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('🔄 앱 생명주기 변경: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 포어그라운드로 돌아왔을 때
        print('📱 앱 포어그라운드 복귀 - 파일 목록 재로드');
        _loadFiles();

        // WebView 백그라운드 재생 설정 재적용
        if (_webViewController != null) {
          _enableBackgroundPlayback();
        }
        break;

      case AppLifecycleState.paused:
        // 앱이 백그라운드로 이동할 때
        print('📱 앱 백그라운드 이동 - 미디어 재생 유지');
        // 오디오/비디오 재생은 백그라운드에서도 계속됨
        break;

      case AppLifecycleState.detached:
        // 앱이 완전히 종료될 때
        print('📱 앱 종료');
        break;

      case AppLifecycleState.inactive:
        // 앱이 비활성 상태일 때 (전화 등)
        print('📱 앱 비활성 상태');
        break;

      case AppLifecycleState.hidden:
        // 앱이 숨겨진 상태일 때
        print('📱 앱 숨김 상태');
        break;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    // 키보드 표시/숨김 감지
    final bottomInset = View.of(context).viewInsets.bottom;
    final newKeyboardVisible = bottomInset > 0;

    if (newKeyboardVisible != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newKeyboardVisible;
      });

      print('키보드 상태 변경: ${_isKeyboardVisible ? "표시됨" : "숨겨짐"}');

      // 키보드가 숨겨졌을 때만 처리 (키보드가 표시될 때는 불필요한 포커스 해제 안 함)
      if (!_isKeyboardVisible && _isEditing && _currentTextFile != null) {
        // 키보드가 사용자에 의해 숨겨진 경우 포커스 해제는 하지 않음
        // HTML 에디터 자체의 포커스 관리에 맡김
        print('키보드 숨김 감지 - 자연스러운 포커스 관리');
      }
    }
  }

  /// 자동 포커스 및 키보드 표시 함수
  Future<void> _autoFocusAndShowKeyboard() async {
    if (!_hasAutoFocused) {
      _hasAutoFocused = true;
      print('자동 포커스 및 키보드 표시 시작');

      try {
        // HTML 에디터가 완전히 로딩될 때까지 더 긴 지연 시간 설정
        await Future.delayed(const Duration(milliseconds: 800));

        // HTML 에디터 로딩 상태 확인
        bool isReady = false;
        int attempts = 0;
        while (!isReady && attempts < 10) {
          try {
            await _htmlController.getText();
            isReady = true;
            print('HTML 에디터 로딩 확인 완료');
          } catch (e) {
            print('HTML 에디터 로딩 대기 중... ${attempts + 1}/10');
            await Future.delayed(const Duration(milliseconds: 200));
            attempts++;
          }
        }

        if (isReady) {
          // 포커스 설정
          _htmlController.setFocus();

          // 키보드 표시 요청 (더 안정적인 방법)
          await Future.delayed(const Duration(milliseconds: 100));
          await SystemChannels.textInput.invokeMethod('TextInput.show');

          setState(() {
            _isKeyboardVisible = true;
          });

          print('자동 포커스 및 키보드 표시 완료');
        } else {
          print('HTML 에디터 로딩 실패 - 자동 포커스 취소');
        }
      } catch (e) {
        print('자동 포커스 실패: $e');
      }
    }
  }

  /// 수동 포커스 및 키보드 표시 함수
  Future<void> _focusAndShowKeyboard() async {
    print('수동 포커스 및 키보드 표시 시작');

    try {
      _htmlController.setFocus();
      await SystemChannels.textInput.invokeMethod('TextInput.show');

      setState(() {
        _isKeyboardVisible = true;
      });

      print('수동 포커스 및 키보드 표시 완료');
    } catch (e) {
      print('수동 포커스 실패: $e');
    }
  }

  /// 키보드 숨김 및 포커스 해제 함수
  Future<void> _hideKeyboardAndClearFocus() async {
    print('키보드 숨김 및 포커스 해제 시작');

    try {
      _htmlController.clearFocus();
      await SystemChannels.textInput.invokeMethod('TextInput.hide');

      setState(() {
        _isKeyboardVisible = false;
      });

      print('키보드 숨김 및 포커스 해제 완료');
    } catch (e) {
      print('키보드 숨김 실패: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  @override
  void dispose() {
    // 메모리 누수 방지를 위한 리소스 정리
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    _tabController.dispose();
    _canvasTextController?.dispose();
    _canvasTextFocusNode?.dispose();
    try {
      if (_htmlController != null) {
        _htmlController.disable();
      }
    } catch (e) {
      debugPrint('❌ HTML 에디터 비활성화 에러: $e');
    }
    super.dispose();
  }

  String? _lastLittenId;

  // 탭 아이템 초기화
  void _initializeTabItems() {
    _tabItems = [
      TabItem(
        id: 'handwriting',
        title: '필기',
        icon: Icons.draw,
        content: _buildHandwritingTab(),
        position: TabPosition.fullScreen,
      ),
      TabItem(
        id: 'text',
        title: '텍스트',
        icon: Icons.keyboard,
        content: _buildTextTab(),
        position: TabPosition.fullScreen,
      ),
      TabItem(
        id: 'audio',
        title: '녹음',
        icon: Icons.mic,
        content: _buildAudioTab(),
        position: TabPosition.fullScreen,
      ),
      TabItem(
        id: 'browser',
        title: '브라우저',
        icon: Icons.public,
        content: _buildBrowserTab(),
        position: TabPosition.fullScreen,
      ),
    ];
  }

  Widget _buildHandwritingTab() {
    // 기존 필기 탭 내용
    return Container(); // 임시
  }

  Widget _buildTextTab() {
    // 기존 텍스트 탭 내용
    return Container(); // 임시
  }

  Widget _buildAudioTab() {
    // 기존 오디오 탭 내용
    return Container(); // 임시
  }

  Widget _buildBrowserTab() {
    // 기존 브라우저 탭 내용
    return Container(); // 임시
  }

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

        if (_isEditing && _currentHandwritingFile != null) {
          return _buildHandwritingEditor();
        }

        return _buildFileListView();
      },
    );
  }

  Future<void> _loadFiles() async {
    if (!mounted) return; // 위젯이 dispose된 경우 return

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten != null) {
        final storage = FileStorageService.instance;

        // 텍스트 파일, 필기 파일, 오디오 파일을 병렬로 로드하여 성능 향상
        final textFilesFuture = storage.loadTextFiles(selectedLitten.id);
        final handwritingFilesFuture = storage.loadHandwritingFiles(
          selectedLitten.id,
        );
        final audioFilesFuture = _audioService.getAudioFiles(selectedLitten);

        final results = await Future.wait([
          textFilesFuture,
          handwritingFilesFuture,
          audioFilesFuture,
        ]);

        final loadedTextFiles = results[0] as List<TextFile>;
        final loadedHandwritingFiles = results[1] as List<HandwritingFile>;
        final loadedAudioFiles = results[2] as List<AudioFile>;

        // 한 번의 setState로 모든 상태 업데이트
        if (mounted) {
          setState(() {
            _textFiles
              ..clear()
              ..addAll(loadedTextFiles);
            _handwritingFiles
              ..clear()
              ..addAll(loadedHandwritingFiles);
            _audioFiles
              ..clear()
              ..addAll(loadedAudioFiles);
            _isLoading = false;
          });
        }

        print(
          '디버그: 파일 목록 로드 완료 - 텍스트: ${_textFiles.length}개, 필기: ${_handwritingFiles.length}개',
        );
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
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // 파일 목록
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // 탭 바
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.draw, size: 20),
                                SizedBox(width: 8),
                                Text('필기 (${_handwritingFiles.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard, size: 20),
                                SizedBox(width: 8),
                                Text('텍스트 (${_textFiles.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hearing, size: 20),
                                SizedBox(width: 8),
                                Text('듣기 (${_audioFiles.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_outline, size: 20),
                                SizedBox(width: 8),
                                Text('보기'),
                              ],
                            ),
                          ),
                        ],
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Theme.of(context).primaryColor,
                      ),
                    ),
                    // 탭 뷰
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 첫 번째 탭 - 필기 파일
                          Stack(
                            children: [
                              _handwritingFiles.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.draw,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          AppSpacing.verticalSpaceS,
                                          Text(
                                            '필기 파일이 없습니다',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _handwritingFiles.length,
                                      itemBuilder: (context, index) {
                                        return _buildHandwritingFileItem(
                                          _handwritingFiles[index],
                                        );
                                      },
                                    ),
                              // 필기 쓰기 버튼 (오른쪽 아래 고정)
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: FloatingActionButton(
                                  onPressed: _createNewHandwritingFile,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                  mini: true,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.draw, size: 16),
                                      SizedBox(width: 2),
                                      Icon(Icons.add, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 두 번째 탭 - 텍스트 파일
                          Stack(
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
                                            '텍스트 파일이 없습니다',
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
                          // 세 번째 탭 - 오디오 파일 (듣기)
                          Stack(
                            children: [
                              _audioFiles.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.hearing,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          AppSpacing.verticalSpaceS,
                                          Text(
                                            '오디오 파일이 없습니다',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _audioFiles.length,
                                      itemBuilder: (context, index) {
                                        return _buildAudioFileItem(
                                          _audioFiles[index],
                                        );
                                      },
                                    ),
                              // 듣기 녹음 버튼 (오른쪽 아래 고정)
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: FloatingActionButton(
                                  onPressed: _toggleRecording,
                                  backgroundColor: _audioService.isRecording
                                      ? Colors.red
                                      : Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  mini: true,
                                  child: AnimatedBuilder(
                                    animation: _audioService,
                                    builder: (context, child) {
                                      return Icon(
                                        _audioService.isRecording
                                            ? Icons.stop
                                            : Icons.mic,
                                        size: 20,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 네 번째 탭 - 브라우저 (보기)
                          Column(
                            children: [
                              // URL 입력 영역
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _urlController,
                                        decoration: InputDecoration(
                                          hintText: 'URL 또는 검색어를 입력하세요...',
                                          prefixIcon: const Icon(Icons.language),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onSubmitted: (url) {
                                          if (url.isNotEmpty) {
                                            _loadUrl(url);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 즐겨찾기 버튼
                                    IconButton(
                                      onPressed: _toggleBookmark,
                                      icon: Icon(
                                        _isCurrentUrlBookmarked
                                          ? Icons.star
                                          : Icons.star_border,
                                        color: _isCurrentUrlBookmarked
                                          ? Colors.orange
                                          : Colors.grey,
                                      ),
                                      tooltip: _isCurrentUrlBookmarked
                                        ? '즐겨찾기에서 제거'
                                        : '즐겨찾기에 추가',
                                    ),
                                    // 즐겨찾기 목록 버튼
                                    IconButton(
                                      onPressed: _toggleBookmarksList,
                                      icon: Icon(
                                        Icons.bookmark,
                                        color: _showBookmarks ? Colors.blue : Colors.grey,
                                      ),
                                      tooltip: '즐겨찾기 목록',
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (_urlController.text.isNotEmpty) {
                                          _loadUrl(_urlController.text);
                                        }
                                      },
                                      child: const Text('이동'),
                                    ),
                                  ],
                                ),
                              ),
                              // WebView 영역 또는 즐겨찾기 목록
                              Expanded(
                                child: _showBookmarks
                                    ? BookmarkWidget(
                                        onBookmarkTap: _onBookmarkSelected,
                                        currentUrl: _currentUrl,
                                      )
                                    : _webViewController != null
                                        ? WebViewWidget(controller: _webViewController!)
                                        : FutureBuilder(
                                            future: _initializeWebView(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      CircularProgressIndicator(),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        '구글 홈페이지를 로드하는 중...',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else if (_webViewController != null) {
                                                return WebViewWidget(controller: _webViewController!);
                                              } else {
                                                return Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.error_outline,
                                                        size: 48,
                                                        color: Colors.grey.shade400,
                                                      ),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        '웹 페이지를 로드할 수 없습니다',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      ElevatedButton(
                                                        onPressed: () => _loadUrl('https://www.google.com'),
                                                        child: Text('다시 시도'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                              ),
                            ],
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

  void _createNewTextFile() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten != null) {
      // 현재 시간 기반 제목 생성
      final now = DateTime.now();
      final defaultTitle =
          '텍스트 ${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final newTextFile = TextFile(
        littenId: selectedLitten.id,
        title: defaultTitle,
        content: '',
      );

      print('디버그: 새로운 텍스트 파일 생성 - $defaultTitle');

      setState(() {
        _currentTextFile = newTextFile;
        _isEditing = true;
        _hasAutoFocused = false; // 자동 포커스 플래그 리셋
      });

      // 새 파일 생성 시 자동 포커스와 키보드 표시
      await Future.delayed(const Duration(milliseconds: 800));
      await _autoFocusAndShowKeyboard();
    }
  }

  void _createNewHandwritingFile() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten != null) {
      // 먼저 PDF 파일 또는 이미지 선택 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('필기 방식 선택'),
          content: const Text('PDF를 변환하여 필기하거나, 빈 캔버스에 직접 그릴 수 있습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadPdfForNewFile();
              },
              child: const Text('PDF 변환'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _createEmptyHandwritingFile();
              },
              child: const Text('빈 캔버스'),
            ),
          ],
        ),
      );
    }
  }

  void _createEmptyHandwritingFile() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten != null) {
      // 현재 시간 기반 제목 생성
      final now = DateTime.now();
      final defaultTitle =
          '필기 ${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      // 임시 경로 - 실제로는 제대로 된 경로를 사용해야 함
      final newHandwritingFile = HandwritingFile(
        littenId: selectedLitten.id,
        title: defaultTitle,
        imagePath: '/temp/new_handwriting.png',
        type: HandwritingType.drawing,
        aspectRatio:
            _backgroundImageAspectRatio ?? (3.0 / 4.0), // 현재 비율 또는 기본 3:4 비율
      );

      print('디버그: 새로운 필기 파일 생성 - $defaultTitle');

      setState(() {
        _currentHandwritingFile = newHandwritingFile;
        _isEditing = true;
        _selectedTool = '제스처'; // 제스처(손바닥) 도구를 기본으로 선택
        _isGestureMode = true; // 제스처 모드 활성화
        // 캔버스 및 배경 이미지 정보 초기화
        _painterController.clearDrawables();
        _painterController.background = null; // 배경 이미지도 완전히 초기화
        _backgroundImageOriginalSize = null;
        _backgroundImageAspectRatio = null; // 배경 이미지 비율도 초기화
      });

      // 캔버스를 좌상단으로 초기화
      _resetCanvasToTopLeft();
    }
  }

  Widget _buildPainterWidget() {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspectRatio = _getCanvasAspectRatio();
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          // 실제 캔버스 크기 계산 - 비율 유지하면서 최대한 큰 크기로
          double canvasWidth, canvasHeight;
          if (maxWidth / maxHeight > aspectRatio) {
            // 높이 기준으로 크기 결정 (위아래 여백 없음)
            canvasHeight = maxHeight;
            canvasWidth = canvasHeight * aspectRatio;
          } else {
            // 너비 기준으로 크기 결정 (좌우 여백 없음)
            canvasWidth = maxWidth;
            canvasHeight = canvasWidth / aspectRatio;
          }

          // 실제 캔버스 크기 저장
          _canvasSize = Size(canvasWidth, canvasHeight);

          return GestureDetector(
            onTap: () {
              // RenderBox를 통해 정확한 탭 위치 계산
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localPosition = box.globalToLocal(Offset.zero);
              // 현재 위치를 화면 중앙 기준으로 계산
              final screenCenter = MediaQuery.of(
                context,
              ).size.center(Offset.zero);
              _handleTap(screenCenter);
            },
            onTapDown: (TapDownDetails details) {
              // 더 정확한 탭 위치 사용
              _handleTap(details.localPosition);
            },
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: _minScale,
              maxScale: _maxScale,
              constrained: true,
              boundaryMargin: const EdgeInsets.all(20),
              // 제스처 기능 활성화
              panEnabled: true, // 팬(이동) 제스처 항상 활성화
              scaleEnabled: true, // 스케일(확대/축소) 제스처 항상 활성화
              // 클립 비활성화로 경계 밖에서도 제스처 가능
              clipBehavior: Clip.none,
              // 더블 탭으로 줌인/줌아웃
              onInteractionStart: (details) {
                print('DEBUG: 제스처 시작 - 포인터 수: ${details.pointerCount}');

                // 페이지 네비게이션용 시작 위치 저장 (제스처 모드이고 단일 포인터인 경우만)
                if (_isGestureMode &&
                    details.pointerCount == 1 &&
                    _currentHandwritingFile?.isMultiPage == true) {
                  _panStartPosition = details.focalPoint;
                  print('DEBUG: 페이지 네비게이션 시작 위치 저장: $_panStartPosition');
                }
              },
              onInteractionUpdate: (details) {
                // 페이지 네비게이션을 위해 마지막 위치 추적
                if (_isGestureMode && _panStartPosition != null) {
                  _lastFocalPoint = details.focalPoint;
                  final double deltaX =
                      details.focalPoint.dx - _panStartPosition!.dx;
                  if (deltaX.abs() > 50) {
                    print(
                      'DEBUG: 제스처 업데이트 - deltaX: ${deltaX.toStringAsFixed(1)}',
                    );
                  }
                }
              },
              onInteractionEnd: (details) {
                print('DEBUG: 제스처 종료');

                // 수평 스크롤로 페이지 네비게이션 처리 (간단한 거리 기반)
                if (_isGestureMode &&
                    _panStartPosition != null &&
                    _lastFocalPoint != null &&
                    _currentHandwritingFile?.isMultiPage == true) {
                  // 마지막 기록된 위치와 시작 위치 비교
                  final double deltaX =
                      _lastFocalPoint!.dx - _panStartPosition!.dx;
                  final double deltaY =
                      _lastFocalPoint!.dy - _panStartPosition!.dy;

                  print(
                    'DEBUG: 제스처 종료 - deltaX: ${deltaX.toStringAsFixed(1)}, deltaY: ${deltaY.toStringAsFixed(1)}',
                  );

                  // 수평 이동이 수직 이동보다 크고, 최소 거리 이상 이동한 경우
                  if (deltaX.abs() > deltaY.abs() && deltaX.abs() > 100) {
                    if (deltaX > 0) {
                      // 오른쪽으로 스와이프 -> 이전 페이지
                      print('DEBUG: 오른쪽 스와이프 -> 이전 페이지로 이동');
                      if (_currentHandwritingFile!.canGoPreviousPage) {
                        _goToPreviousPage();
                      }
                    } else {
                      // 왼쪽으로 스와이프 -> 다음 페이지
                      print('DEBUG: 왼쪽 스와이프 -> 다음 페이지로 이동');
                      if (_currentHandwritingFile!.canGoNextPage) {
                        _goToNextPage();
                      }
                    }
                  }
                }

                // 변수 초기화
                _panStartPosition = null;

                // 스케일 범위 체크 및 조정
                final Matrix4 matrix = _transformationController.value;
                final double scale = matrix.getMaxScaleOnAxis();
                if (scale < _minScale || scale > _maxScale) {
                  final double clampedScale = scale.clamp(_minScale, _maxScale);
                  final double scaleFactor = clampedScale / scale;
                  _transformationController.value = matrix.scaled(scaleFactor);
                }
              },
              child: Center(
                child: Stack(
                  children: [
                    // 메인 캔버스 - 비율 유지하며 중앙 배치
                    SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: IgnorePointer(
                        ignoring:
                            _isTextInputMode ||
                            _isGestureMode, // 텍스트 입력 모드나 제스처 모드에서 포인터 무시
                        child: FlutterPainter(controller: _painterController),
                      ),
                    ),
                    // 텍스트 입력 전용 제스처 감지 레이어
                    if (_isTextInputMode)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            // 터치 좌표를 캔버스 좌표로 변환
                            final canvasPosition =
                                _transformLocalToCanvasCoordinates(
                                  details.localPosition,
                                );
                            print(
                              'DEBUG: 터치 좌표 변환 - 로컬: ${details.localPosition}, 캔버스: $canvasPosition',
                            );

                            // 전체 Stack에서의 위치 계산 (헤더, 툴바 높이 고려)
                            final globalPosition =
                                _calculateGlobalTextInputPosition(
                                  details.localPosition,
                                );

                            setState(() {
                              _textInputPosition = canvasPosition;
                              _screenTextInputPosition = globalPosition;
                            });
                            _showCanvasTextInput();
                          },
                          child: Container(),
                        ),
                      ),
                    // 텍스트 입력 오버레이는 InteractiveViewer 외부로 이동
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _getCanvasAspectRatio() {
    // 현재 필기 파일의 저장된 비율이 있다면 사용
    if (_currentHandwritingFile?.aspectRatio != null) {
      final ratio = _currentHandwritingFile!.aspectRatio!;
      print('DEBUG: 필기 파일 저장된 비율 사용 - $ratio');
      return ratio;
    }

    // 현재 세션의 배경 이미지 비율이 있다면 사용
    if (_backgroundImageAspectRatio != null) {
      print('DEBUG: 세션 배경 이미지 비율 사용 - $_backgroundImageAspectRatio');
      return _backgroundImageAspectRatio!;
    }

    // 기본 A4 비율 (210mm x 297mm ≈ 0.707)
    print('DEBUG: 기본 A4 비율 사용 - 0.707');
    return 210.0 / 297.0;
  }

  Future<void> _loadPdfFile() async {
    try {
      print('DEBUG: PDF 파일 선택 시작');

      if (kIsWeb) {
        // 웹 전용 처리
        await _loadPdfFileForWeb();
      } else {
        // 모바일 기존 처리
        await _loadPdfFileForMobile();
      }
    } catch (e) {
      print('ERROR: PDF 로드 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF 파일 로드에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPdfFileForWeb() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // 웹에서는 파일 데이터를 직접 사용
    );

    if (result != null && result.files.single.bytes != null) {
      print('DEBUG: PDF 파일 선택됨 (웹) - ${result.files.single.name}');

      final pdfBytes = result.files.single.bytes!;
      final fileName = result.files.single.name ?? 'PDF';

      // 웹에서는 바로 PDF 변환 다이얼로그 표시
      await _showWebPdfConversionDialog(pdfBytes, fileName);
    }
  }

  Future<void> _loadPdfFileForMobile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false, // flutter_pdfview는 파일 경로를 사용
    );

    if (result != null && result.files.single.path != null) {
      print('DEBUG: PDF 파일 선택됨 - ${result.files.single.name}');

      final pdfPath = result.files.single.path!;

      // 임시 디렉토리에 PDF 파일 복사
      final tempDir = await getTemporaryDirectory();
      final tempPdfFile = File('${tempDir.path}/temp_pdf.pdf');

      // 선택한 파일을 임시 디렉토리로 복사
      final originalFile = File(pdfPath);
      await originalFile.copy(tempPdfFile.path);

      print('DEBUG: PDF 파일 임시 디렉토리로 복사됨 - ${tempPdfFile.path}');

      // flutter_pdfview를 사용한 PDF 뷰어 표시
      await _showPdfViewer(tempPdfFile.path, result.files.single.name ?? 'PDF');
    }
  }

  Future<void> _showWebPdfConversionDialog(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF 변환 - $fileName'),
        content: const Text(
          '웹에서는 PDF를 직접 필기용으로 변환할 수 있습니다.\n'
          '변환 후 각 페이지를 배경으로 하여 필기할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _convertWebPdfToPngAndAddToHandwriting(pdfBytes, fileName);
            },
            icon: const Icon(Icons.draw),
            label: const Text('필기용으로 변환'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPdfViewer(String pdfPath, String fileName) async {
    int totalPages = 1;
    int currentPage = 0;

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(fileName),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
          body: PDFView(
            filePath: pdfPath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageSnap: true,
            onRender: (pages) {
              print('DEBUG: PDF 렌더링 완료 - 총 $pages 페이지');
              totalPages = pages ?? 1;
            },
            onError: (error) {
              print('ERROR: PDF 렌더링 에러 - $error');
            },
            onPageError: (page, error) {
              print('ERROR: PDF 페이지 $page 에러 - $error');
            },
            onPageChanged: (int? page, int? total) {
              print('DEBUG: PDF 페이지 변경 - $page/$total');
              currentPage = page ?? 0;
            },
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _convertPdfToPngAndAddToHandwriting(
                            pdfPath,
                            fileName,
                          );
                        },
                        icon: const Icon(Icons.draw),
                        label: const Text('필기용으로 변환'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.visibility),
                        label: const Text('보기만'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConversionProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StreamBuilder<void>(
          stream: Stream.periodic(const Duration(milliseconds: 100)),
          builder: (context, snapshot) {
            return AlertDialog(
              title: const Text('PDF 변환 중'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _totalPagesToConvert > 0
                        ? _convertedPages / _totalPagesToConvert
                        : 0,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_convertedPages / $_totalPagesToConvert 페이지 변환됨',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (_conversionStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _conversionStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _conversionCancelled = true;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('취소'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _convertPdfToPngAndAddToHandwriting(
    String pdfPath,
    String fileName,
  ) async {
    try {
      print('DEBUG: PDF를 PNG로 변환 시작 - $fileName');

      // 변환 상태 초기화
      setState(() {
        _isConverting = true;
        _convertedPages = 0;
        _totalPagesToConvert = 0;
        _conversionStatus = '페이지 수 확인 중...';
        _conversionCancelled = false;
      });

      // 진행률 다이얼로그 표시
      _showConversionProgressDialog();

      // PDF 파일을 Uint8List로 읽기
      final pdfFile = File(pdfPath);
      final pdfBytes = await pdfFile.readAsBytes();

      // 먼저 총 페이지 수만 확인 (메모리 절약)
      int totalPages = 0;
      await for (final _ in Printing.raster(pdfBytes, dpi: 150)) {
        totalPages++;
        if (totalPages % 10 == 0) {
          setState(() {
            _conversionStatus = '페이지 수 확인 중... ($totalPages페이지 감지)';
          });
        }
        if (_conversionCancelled) {
          throw Exception('변환이 취소되었습니다.');
        }
      }

      setState(() {
        _totalPagesToConvert = totalPages;
        _conversionStatus = '변환 시작...';
      });

      print('DEBUG: 총 $totalPages개 페이지 감지됨');

      // 메모리 최적화를 위한 배치 단위 변환 (2페이지씩 - 에뮬레이터 최적화)
      const int batchSize = 2;
      final List<Uint8List> allImages = [];
      final storage = FileStorageService.instance;
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten == null) {
        throw Exception('리튼이 선택되지 않았습니다.');
      }

      // 파일 저장을 위한 디렉토리 설정
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory(
        '${directory.path}/litten_${selectedLitten.id}',
      );
      if (!await littenDir.exists()) {
        await littenDir.create(recursive: true);
      }

      final titleWithoutExtension = fileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final List<String> pageImagePaths = [];

      // 메인 다중 페이지 필기 파일을 먼저 생성 (페이지 경로는 나중에 설정)
      final mainHandwritingFile = HandwritingFile(
        littenId: selectedLitten.id,
        title: titleWithoutExtension,
        imagePath: '/temp/placeholder.png', // 임시 값
        type: HandwritingType.pdfConvert,
      );

      print('DEBUG: 메인 필기 파일 생성 - ID: ${mainHandwritingFile.id}');

      // 배치 단위로 변환
      for (int startPage = 0; startPage < totalPages; startPage += batchSize) {
        if (_conversionCancelled) {
          throw Exception('변환이 취소되었습니다.');
        }

        final int endPage = (startPage + batchSize).clamp(0, totalPages);
        final List<int> pageIndices = List.generate(
          endPage - startPage,
          (index) => startPage + index,
        );

        setState(() {
          _conversionStatus = '페이지 ${startPage + 1} - $endPage 변환 중...';
        });

        print('DEBUG: 배치 변환 시작 - 페이지 ${startPage + 1} - $endPage');

        // 현재 배치의 페이지들 변환 (원본 크기 유지)
        final List<Uint8List> batchImages = [];
        await for (final page in Printing.raster(
          pdfBytes,
          pages: pageIndices,
          dpi: 300, // 표준 인쇄 품질 DPI (메모리 최적화)
        )) {
          if (_conversionCancelled) {
            throw Exception('변환이 취소되었습니다.');
          }

          // 원본 크기로 PNG 변환
          batchImages.add(await page.toPng());

          setState(() {
            _convertedPages++;
            _conversionStatus = '페이지 $_convertedPages/$totalPages 변환 완료';
          });

          print('DEBUG: 페이지 $_convertedPages 변환 완료');

          // UI 업데이트를 위한 짧은 대기
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // 배치의 이미지들을 즉시 파일로 저장하고 메모리에서 해제
        for (int i = 0; i < batchImages.length; i++) {
          final pageIndex = startPage + i;

          // 메인 파일 ID를 기반으로 페이지별 파일명 생성
          final pageFileName =
              '${mainHandwritingFile.id}_page_${pageIndex + 1}.png';
          final pageFilePath = '${littenDir.path}/$pageFileName';

          // 직접 파일로 저장 (FileStorageService를 거치지 않음)
          final pageFile = File(pageFilePath);
          await pageFile.writeAsBytes(batchImages[i]);

          // 페이지 경로를 가상 경로로 저장 (나중에 실제 파일명으로 변환할 수 있도록)
          pageImagePaths.add(pageFileName);

          print('DEBUG: 페이지 ${pageIndex + 1} 이미지 저장 완료: $pageFileName');
        }

        // 배치 이미지 메모리 해제
        batchImages.clear();

        // 가비지 컬렉션 유도
        if (startPage % (batchSize * 2) == 0) {
          // 메모리 정리를 위한 짧은 대기
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print('DEBUG: 모든 페이지 변환 및 저장 완료');

      if (pageImagePaths.isNotEmpty) {
        setState(() {
          _conversionStatus = '필기 파일 생성 중...';
        });

        // 메인 파일을 실제 페이지 정보로 업데이트 (비율 정보 포함)
        final newHandwritingFile = mainHandwritingFile.copyWith(
          imagePath: '${mainHandwritingFile.id}_page_1.png', // 첫 번째 페이지 파일명
          pageImagePaths: pageImagePaths, // 모든 페이지 파일명들
          totalPages: totalPages, // 총 페이지 수
          currentPageIndex: 0, // 첫 번째 페이지부터 시작
          aspectRatio: _backgroundImageAspectRatio, // 변환된 PDF의 비율 정보 저장
        );

        print(
          'DEBUG: 다중 페이지 필기 파일 생성 - 제목: $titleWithoutExtension, 페이지 수: $totalPages',
        );

        // 필기 파일 목록에 추가
        setState(() {
          _handwritingFiles.add(newHandwritingFile);
          _currentHandwritingFile = newHandwritingFile;
          _isEditing = true;
          _isConverting = false;
          _selectedTool = '제스처'; // 제스처(손바닥) 도구를 기본으로 선택
          _isGestureMode = true; // 제스처 모드 활성화
        });

        // 필기 파일 목록을 SharedPreferences에 저장
        await storage.saveHandwritingFiles(
          selectedLitten.id,
          _handwritingFiles,
        );

        // 리튼에 필기 파일 추가
        final littenService = LittenService();
        await littenService.addHandwritingFileToLitten(
          selectedLitten.id,
          newHandwritingFile.id,
        );

        // 첫 번째 페이지 이미지를 로드하여 캔버스 배경으로 설정
        final firstPageFileName = pageImagePaths.first;
        final firstPageFile = File('${littenDir.path}/$firstPageFileName');

        if (await firstPageFile.exists()) {
          final firstPageBytes = await firstPageFile.readAsBytes();
          await _setBackgroundFromBytes(firstPageBytes);
        }

        print('DEBUG: PDF to PNG 변환 및 다중 페이지 필기 파일 추가 완료');

        // 진행률 다이얼로그 닫기
        Navigator.of(context).pop();

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$titleWithoutExtension ($totalPages페이지)이(가) 필기 파일로 추가되었습니다.',
              ),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: '편집',
                onPressed: () {
                  // 이미 편집 모드로 설정됨
                },
              ),
            ),
          );
        }
      } else {
        setState(() {
          _isConverting = false;
        });

        // 진행률 다이얼로그 닫기
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        print('ERROR: PDF 변환 결과 이미지가 없음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF 변환에 실패했습니다. 페이지가 없거나 파일이 손상되었을 수 있습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isConverting = false;
      });

      // 진행률 다이얼로그 닫기
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('ERROR: PDF to PNG 변환 실패 - $e');

      String errorMessage;
      if (e.toString().contains('변환이 취소되었습니다')) {
        errorMessage = '변환이 취소되었습니다.';
      } else if (e.toString().contains('메모리')) {
        errorMessage = '메모리 부족으로 변환에 실패했습니다. 페이지 수가 너무 많을 수 있습니다.';
      } else if (e.toString().contains('리튼이 선택되지 않았습니다')) {
        errorMessage = '리튼을 먼저 선택해주세요.';
      } else {
        errorMessage = 'PDF 변환 실패: 파일이 손상되었거나 지원되지 않는 형식일 수 있습니다.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _convertWebPdfToPngAndAddToHandwriting(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      print('DEBUG: 웹에서 PDF를 PNG로 변환 시작 - $fileName');

      // 변환 상태 초기화
      setState(() {
        _isConverting = true;
        _convertedPages = 0;
        _totalPagesToConvert = 0;
        _conversionStatus = '페이지 수 확인 중...';
        _conversionCancelled = false;
      });

      // 진행률 다이얼로그 표시
      _showConversionProgressDialog();

      // 먼저 총 페이지 수만 확인
      int totalPages = 0;
      await for (final _ in Printing.raster(pdfBytes, dpi: 150)) {
        totalPages++;
        if (totalPages % 10 == 0) {
          setState(() {
            _conversionStatus = '페이지 수 확인 중... ($totalPages페이지 감지)';
          });
        }
        if (_conversionCancelled) {
          throw Exception('변환이 취소되었습니다.');
        }
      }

      setState(() {
        _totalPagesToConvert = totalPages;
        _conversionStatus = '변환 시작...';
      });

      print('DEBUG: 총 $totalPages개 페이지 감지됨');

      // 리튼 선택 확인
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten == null) {
        throw Exception('리튼이 선택되지 않았습니다.');
      }

      final storage = FileStorageService.instance;

      // 웹에서는 브라우저의 로컬 스토리지를 사용하므로 디렉토리 경로 대신 키를 사용
      final titleWithoutExtension = fileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final List<String> pageImagePaths = [];

      // 메인 다중 페이지 필기 파일을 먼저 생성
      final mainHandwritingFile = HandwritingFile(
        littenId: selectedLitten.id,
        title: titleWithoutExtension,
        imagePath: '/temp/placeholder.png', // 임시 값
        type: HandwritingType.pdfConvert,
      );

      print('DEBUG: 메인 필기 파일 생성 - ID: ${mainHandwritingFile.id}');

      // 메모리 최적화를 위한 배치 단위 변환 (웹에서는 1페이지씩)
      const int batchSize = 1;
      double? aspectRatio;

      for (int startPage = 0; startPage < totalPages; startPage += batchSize) {
        if (_conversionCancelled) {
          throw Exception('변환이 취소되었습니다.');
        }

        final int endPage = (startPage + batchSize).clamp(0, totalPages);
        final List<int> pageIndices = List.generate(
          endPage - startPage,
          (index) => startPage + index,
        );

        setState(() {
          _conversionStatus = '페이지 ${startPage + 1} - $endPage 변환 중...';
        });

        print('DEBUG: 배치 변환 시작 - 페이지 ${startPage + 1} - $endPage');

        // 현재 배치의 페이지들 변환
        await for (final page in Printing.raster(
          pdfBytes,
          pages: pageIndices,
          dpi: 200, // 웹 최적화 DPI
        )) {
          if (_conversionCancelled) {
            throw Exception('변환이 취소되었습니다.');
          }

          // PNG 변환
          final imageBytes = await page.toPng();

          // 첫 번째 페이지에서 종횡비 계산
          if (aspectRatio == null) {
            final codec = await ui.instantiateImageCodec(imageBytes);
            final frame = await codec.getNextFrame();
            aspectRatio = frame.image.width / frame.image.height;
            setState(() {
              _backgroundImageAspectRatio = aspectRatio;
            });
            print('DEBUG: PDF 종횡비 계산됨 - $aspectRatio');
          }

          // 웹에서는 브라우저 메모리에 저장
          final pageKey =
              '${mainHandwritingFile.id}_page_${_convertedPages + 1}.png';
          await storage.saveImageBytesToWeb(pageKey, imageBytes);
          pageImagePaths.add(pageKey);

          setState(() {
            _convertedPages++;
            _conversionStatus = '페이지 $_convertedPages/$totalPages 변환 완료';
          });

          print('DEBUG: 페이지 $_convertedPages 변환 완료');

          // UI 업데이트를 위한 짧은 대기
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // 변환 결과 확인
      if (pageImagePaths.isNotEmpty) {
        // 다중 페이지 필기 파일로 생성
        final newHandwritingFile = mainHandwritingFile.copyWith(
          imagePath: pageImagePaths[0], // 첫 번째 페이지 키
          pageImagePaths: pageImagePaths, // 모든 페이지 키들
          totalPages: totalPages, // 총 페이지 수
          currentPageIndex: 0, // 첫 번째 페이지부터 시작
          aspectRatio: aspectRatio, // 변환된 PDF의 비율 정보 저장
        );

        print(
          'DEBUG: 다중 페이지 필기 파일 생성 - 제목: $titleWithoutExtension, 페이지 수: $totalPages',
        );

        // 필기 파일 목록에 추가
        setState(() {
          _handwritingFiles.add(newHandwritingFile);
          _currentHandwritingFile = newHandwritingFile;
          _isEditing = true;
          _isConverting = false;
          _selectedTool = '제스처'; // 제스처(손바닥) 도구를 기본으로 선택
          _isGestureMode = true; // 제스처 모드 활성화
        });

        // 필기 파일 목록을 저장
        await storage.saveHandwritingFiles(
          selectedLitten.id,
          _handwritingFiles,
        );

        // 리튼에 필기 파일 추가
        final littenService = LittenService();
        await littenService.addHandwritingFileToLitten(
          selectedLitten.id,
          newHandwritingFile.id,
        );

        // 첫 번째 페이지를 배경으로 설정
        final firstPageBytes = await storage.getImageBytesFromWeb(
          pageImagePaths[0],
        );
        if (firstPageBytes != null) {
          await _setBackgroundFromBytes(firstPageBytes);
        }

        print('DEBUG: 웹 PDF to PNG 변환 및 다중 페이지 필기 파일 추가 완료');

        // 진행률 다이얼로그 닫기
        Navigator.of(context).pop();

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$titleWithoutExtension ($totalPages페이지)이(가) 필기 파일로 추가되었습니다.',
              ),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: '편집',
                onPressed: () {
                  // 이미 편집 모드로 설정됨
                },
              ),
            ),
          );
        }
      } else {
        // 진행률 다이얼로그 닫기
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        print('ERROR: 웹 PDF 변환 결과 이미지가 없음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF 변환에 실패했습니다. 페이지가 없거나 파일이 손상되었을 수 있습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isConverting = false;
      });

      // 진행률 다이얼로그 닫기
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('ERROR: 웹 PDF to PNG 변환 실패 - $e');

      String errorMessage;
      if (e.toString().contains('변환이 취소되었습니다')) {
        errorMessage = '변환이 취소되었습니다.';
      } else if (e.toString().contains('메모리')) {
        errorMessage = '메모리 부족으로 변환에 실패했습니다. 페이지 수가 너무 많을 수 있습니다.';
      } else if (e.toString().contains('리튼이 선택되지 않았습니다')) {
        errorMessage = '리튼을 먼저 선택해주세요.';
      } else {
        errorMessage = 'PDF 변환 실패: 파일이 손상되었거나 지원되지 않는 형식일 수 있습니다.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _setBackgroundFromBytes(Uint8List imageBytes) async {
    try {
      // Uint8List를 ui.Image로 변환 후 배경으로 설정
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final uiImage = frameInfo.image;

      // 원본 이미지 크기 정보 로그 및 비율 계산
      print(
        'DEBUG: 배경 이미지 원본 크기 - 너비: ${uiImage.width}, 높이: ${uiImage.height}',
      );

      // 이미지 비율과 원본 크기 저장
      if (uiImage.width > 0 && uiImage.height > 0) {
        _backgroundImageAspectRatio = uiImage.width / uiImage.height;
        _backgroundImageOriginalSize = Size(
          uiImage.width.toDouble(),
          uiImage.height.toDouble(),
        );
        print(
          'DEBUG: 배경 이미지 정보 저장 - 비율: $_backgroundImageAspectRatio, 크기: ${uiImage.width}x${uiImage.height}',
        );
      }

      // 배경으로 직접 설정 (리사이즈 없이)
      _painterController.background = uiImage.backgroundDrawable;

      // UI 업데이트 (캔버스 비율 재계산)
      setState(() {});

      // 캔버스를 좌상단으로 초기화
      _resetCanvasToTopLeft();

      print('DEBUG: 배경 이미지 설정 완료');
    } catch (e) {
      print('ERROR: 배경 이미지 설정 실패 - $e');
    }
  }

  Future<void> _loadImageFile() async {
    try {
      print('DEBUG: 이미지 파일 선택 시작');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final imageBytes = result.files.single.bytes!;
        print('DEBUG: 이미지 파일 선택됨 - ${result.files.single.name}');

        // 배경으로 설정
        await _setBackgroundFromBytes(imageBytes);

        setState(() {
          _backgroundImagePath = null;
          _pdfPages = null;
          _currentPdfPage = 0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 파일 로드 완료'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: 이미지 로드 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미지 파일 로드에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDrawingTool(IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectDrawingTool(label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _selectDrawingTool(String tool) {
    print('DEBUG: 그리기 도구 선택 - $tool');

    setState(() {
      _selectedTool = tool;

      // 제스처 모드 설정
      if (tool == '제스처') {
        _isGestureMode = true;
        print('DEBUG: 제스처 모드 활성화 - 확대/축소/이동 가능');
      } else {
        _isGestureMode = false;
      }

      switch (tool) {
        case '펜':
          _painterController.freeStyleMode = FreeStyleMode.draw;
          _painterController.freeStyleStrokeWidth = _strokeWidth;
          _painterController.freeStyleColor = _selectedColor;
          print('DEBUG: 펜 모드 설정 - 색상: $_selectedColor, 두께: $_strokeWidth');
          break;
        case '하이라이터':
          _painterController.freeStyleMode = FreeStyleMode.draw;
          _painterController.freeStyleStrokeWidth = _strokeWidth * 3;
          _painterController.freeStyleColor = _selectedColor.withValues(
            alpha: 0.5,
          );
          print('DEBUG: 하이라이터 모드 설정');
          break;
        case '지우개':
          _painterController.freeStyleMode = FreeStyleMode.erase;
          _painterController.freeStyleStrokeWidth = _strokeWidth * 4;
          print('DEBUG: 지우개 모드 설정');
          break;
        case '도형':
          _painterController.shapeFactory = RectangleFactory();
          print('DEBUG: 도형 모드 설정');
          break;
        case '원형':
          _painterController.shapeFactory = OvalFactory();
          print('DEBUG: 원형 모드 설정');
          break;
        case '직선':
          _painterController.shapeFactory = LineFactory();
          print('DEBUG: 직선 모드 설정');
          break;
        case '화살표':
          _painterController.shapeFactory = ArrowFactory();
          print('DEBUG: 화살표 모드 설정');
          break;
        case '텍스트':
          _showTextInput();
          print('DEBUG: 텍스트 모드 설정');
          break;
        case '실행취소':
          _painterController.undo();
          print('DEBUG: 실행취소');
          break;
        case '다시실행':
          _painterController.redo();
          print('DEBUG: 다시실행');
          break;
        case '초기화':
          _painterController.clearDrawables();
          print('DEBUG: 캔버스 초기화');
          break;
        case '줌인':
          _zoomIn();
          print('DEBUG: 줌인 실행');
          break;
        case '줌아웃':
          _zoomOut();
          print('DEBUG: 줌아웃 실행');
          break;
        case '선굵기':
          _showStrokeWidthPicker();
          break;
        case '색상':
          setState(() {
            _showColorPicker = !_showColorPicker;
          });
          break;
        case '고급도구':
          setState(() {
            _showAdvancedTools = !_showAdvancedTools;
          });
          break;
      }
    });

    print('DEBUG: 그리기 도구 변경됨 - $tool');
  }

  // 줌인 기능 (애니메이션 포함)
  void _zoomIn() {
    final Matrix4 currentTransform = _transformationController.value.clone();
    final double currentScale = currentTransform.getMaxScaleOnAxis();

    if (currentScale < _maxScale) {
      final double newScale = (currentScale * 1.5).clamp(_minScale, _maxScale);
      final double scaleDelta = newScale / currentScale;

      // 현재 뷰포트 중심점 계산
      final Size viewportSize = _canvasSize ?? const Size(300, 400);
      final Offset center = Offset(
        viewportSize.width / 2,
        viewportSize.height / 2,
      );

      // 중심점을 기준으로 확대
      final Matrix4 matrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(scaleDelta)
        ..translate(-center.dx, -center.dy);

      // 부드러운 애니메이션으로 변환
      final Matrix4 targetMatrix = matrix * currentTransform;
      _animateToTransform(targetMatrix);

      print(
        'DEBUG: 줌인 - 현재 스케일: ${currentScale.toStringAsFixed(2)} -> ${newScale.toStringAsFixed(2)}',
      );
    }
  }

  // 줌아웃 기능 (애니메이션 포함)
  void _zoomOut() {
    final Matrix4 currentTransform = _transformationController.value.clone();
    final double currentScale = currentTransform.getMaxScaleOnAxis();

    if (currentScale > _minScale) {
      final double newScale = (currentScale / 1.5).clamp(_minScale, _maxScale);
      final double scaleDelta = newScale / currentScale;

      // 현재 뷰포트 중심점 계산
      final Size viewportSize = _canvasSize ?? const Size(300, 400);
      final Offset center = Offset(
        viewportSize.width / 2,
        viewportSize.height / 2,
      );

      // 중심점을 기준으로 축소
      final Matrix4 matrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(scaleDelta)
        ..translate(-center.dx, -center.dy);

      // 부드러운 애니메이션으로 변환
      final Matrix4 targetMatrix = matrix * currentTransform;
      _animateToTransform(targetMatrix);

      print(
        'DEBUG: 줌아웃 - 현재 스케일: ${currentScale.toStringAsFixed(2)} -> ${newScale.toStringAsFixed(2)}',
      );
    }
  }

  void _showTextInput() {
    setState(() {
      _isTextInputMode = true;
      _selectedTool = '텍스트';
      // 텍스트 입력 위치는 캔버스를 터치했을 때 설정
      _textInputPosition = null;
      _screenTextInputPosition = null; // 화면 위치도 초기화
    });
    print('DEBUG: 텍스트 입력 모드 활성화 - 캔버스를 터치하여 입력 위치를 선택하세요');
  }

  void _showCanvasTextInput() {
    _canvasTextController!.clear();
    _canvasTextFocusNode!.requestFocus();
    print('DEBUG: 텍스트 입력 필드 활성화 - 위치: $_textInputPosition');
  }

  Widget _buildCanvasTextInput() {
    return Positioned(
      left: _textInputPosition!.dx,
      top: _textInputPosition!.dy,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 200,
          maxWidth: 300,
          minHeight: 40,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Theme.of(context).primaryColor, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 텍스트 입력 필드
            TextField(
              controller: _canvasTextController,
              focusNode: _canvasTextFocusNode,
              style: TextStyle(color: _selectedColor, fontSize: 16),
              decoration: const InputDecoration(
                hintText: '텍스트를 입력하세요',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: null,
              autofocus: true,
              onSubmitted: (text) {
                print('DEBUG: TextField onSubmitted 호출됨 - 텍스트: "$text"');
                _confirmTextInput();
              },
              onTapOutside: (event) {
                print('DEBUG: TextField onTapOutside 호출됨');
                _handleTextInputFocusOut();
              },
            ),
            // 버튼들
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      print('DEBUG: 취소 버튼 클릭됨 - onPressed 호출');
                      _cancelTextInput();
                    },
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      print('DEBUG: 확인 버튼 클릭됨 - onPressed 호출');
                      _confirmTextInput();
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmTextInput() {
    print('DEBUG: _confirmTextInput 호출됨');

    try {
      if (_canvasTextController == null) {
        print('DEBUG: _canvasTextController가 null임');
        return;
      }

      final text = _canvasTextController!.text.trim();
      print('DEBUG: 입력된 텍스트: "$text"');

      if (text.isNotEmpty) {
        print('DEBUG: 텍스트가 비어있지 않음 - 캔버스에 추가 시도');
        _addTextToCanvas(text);
      } else {
        print('DEBUG: 입력된 텍스트가 비어있음');
      }

      print('DEBUG: 텍스트 입력 모드 종료 시작');
      _cancelTextInput();
      print('DEBUG: _confirmTextInput 완료');
    } catch (e) {
      print('DEBUG: _confirmTextInput에서 오류 발생 - $e');
    }
  }

  void _cancelTextInput() {
    print('DEBUG: _cancelTextInput 시작');
    setState(() {
      _isTextInputMode = false;
      _textInputPosition = null;
      _screenTextInputPosition = null; // 화면 위치도 초기화
      _selectedTool = '펜'; // 기본 도구로 돌아가기
    });
    _canvasTextFocusNode!.unfocus();
    print('DEBUG: 텍스트 입력 모드 종료 완료');
  }

  void _handleTextInputFocusOut() {
    print('DEBUG: _handleTextInputFocusOut 호출됨');

    if (_canvasTextController != null) {
      final text = _canvasTextController!.text.trim();
      print('DEBUG: 포커스 아웃 시 텍스트 내용: "$text"');

      if (text.isNotEmpty) {
        print('DEBUG: 텍스트가 있음 - 자동 확인 액션 실행');
        _confirmTextInput();
      } else {
        print('DEBUG: 텍스트가 없음 - 자동 취소 액션 실행');
        _cancelTextInput();
      }
    } else {
      print('DEBUG: _canvasTextController가 null - 취소 액션 실행');
      _cancelTextInput();
    }
  }

  /// 로컬 터치 좌표를 캔버스 좌표계로 변환
  Offset _transformLocalToCanvasCoordinates(Offset localPosition) {
    try {
      // InteractiveViewer의 현재 변환 매트릭스 가져오기
      final Matrix4 matrix = _transformationController.value;

      // 스케일 및 변환 값 추출
      final double scaleX = matrix.entry(0, 0);
      final double scaleY = matrix.entry(1, 1);
      final double translateX = matrix.entry(0, 3);
      final double translateY = matrix.entry(1, 3);

      // 역변환 적용: (localPosition - translation) / scale
      final double canvasX = (localPosition.dx - translateX) / scaleX;
      final double canvasY = (localPosition.dy - translateY) / scaleY;

      final Offset canvasPosition = Offset(canvasX, canvasY);

      print('DEBUG: 좌표 변환 상세 - 로컬: $localPosition');
      print(
        'DEBUG: 스케일 X/Y: ${scaleX.toStringAsFixed(3)}/${scaleY.toStringAsFixed(3)}',
      );
      print(
        'DEBUG: 변환 X/Y: ${translateX.toStringAsFixed(1)}/${translateY.toStringAsFixed(1)}',
      );
      print('DEBUG: 변환된 캔버스 좌표: $canvasPosition');

      return canvasPosition;
    } catch (e) {
      print('DEBUG: 좌표 변환 실패 - $e, 원본 좌표 반환');
      return localPosition;
    }
  }

  /// 터치 위치를 전체 Stack에서의 위치로 계산 (헤더, 툴바 높이 고려)
  Offset _calculateGlobalTextInputPosition(Offset localPosition) {
    try {
      // 헤더 높이 (AppBar와 상단 헤더)
      const double headerHeight = kToolbarHeight + 56; // AppBar + 상단 헤더
      // 필기 도구 패널 높이
      const double toolbarHeight = 40;
      // 동기화 상태 바 높이 (있는 경우)
      const double syncBarHeight = 0; // 현재는 별도 높이 없음

      // 전체 오프셋 계산
      final double totalTopOffset =
          headerHeight + toolbarHeight + syncBarHeight;

      // InteractiveViewer 내의 로컬 좌표를 전체 Stack 좌표로 변환
      final double globalX = localPosition.dx;
      final double globalY = localPosition.dy + totalTopOffset;

      final Offset globalPosition = Offset(globalX, globalY);

      print('DEBUG: 전체 위치 계산 - 로컬: $localPosition → 전체: $globalPosition');
      print(
        'DEBUG: 상단 오프셋: ${totalTopOffset}px (헤더: ${headerHeight}px + 툴바: ${toolbarHeight}px)',
      );

      return globalPosition;
    } catch (e) {
      print('DEBUG: 전체 위치 계산 실패 - $e, 원본 좌표 반환');
      return localPosition;
    }
  }

  void _addTextToCanvas(String text) {
    try {
      if (_textInputPosition != null) {
        print('DEBUG: 텍스트 추가 시작 - "$text" at ${_textInputPosition!}');

        // flutter_painter_v2의 올바른 텍스트 추가 방법
        _painterController.textSettings = TextSettings(
          textStyle: TextStyle(
            color: _selectedColor,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        );

        // 텍스트를 직접 추가하는 방법 시도
        final textDrawable = TextDrawable(
          text: text,
          position: _textInputPosition!,
          style: TextStyle(
            color: _selectedColor,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        );

        // addDrawables 메서드로 텍스트 추가
        _painterController.addDrawables([textDrawable]);
        print('DEBUG: addDrawables 메서드로 텍스트 추가 완료');

        // 캔버스 강제 새로고침
        setState(() {});

        print('DEBUG: 텍스트 추가 완료 - "$text" at ${_textInputPosition!}');
      } else {
        print('DEBUG: 텍스트 입력 위치가 null임');
      }
    } catch (e) {
      print('DEBUG: 텍스트 추가 실패 - $e');
      print('DEBUG: 텍스트 "$text"를 위치 ${_textInputPosition!}에 추가하려 했음');
    }
  }

  void _showStrokeWidthPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선 굵기 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: _strokeWidth,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              label: '${_strokeWidth.round()}px',
              onChanged: (value) {
                setState(() {
                  _strokeWidth = value;
                  _painterController.freeStyleStrokeWidth = value;
                });
              },
            ),
            Text('현재 굵기: ${_strokeWidth.round()}px'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectColor(color),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : Border.all(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  void _selectColor(Color color) {
    print('DEBUG: 색상 선택 - $color');

    setState(() {
      _selectedColor = color;

      // 현재 선택된 도구에 새 색상 적용
      switch (_selectedTool) {
        case '펜':
          _painterController.freeStyleColor = _selectedColor;
          break;
        case '하이라이터':
          _painterController.freeStyleColor = _selectedColor.withValues(
            alpha: 0.5,
          );
          break;
        case '도형':
          _painterController.shapeFactory = RectangleFactory();
          break;
      }
    });

    print('DEBUG: 색상 변경됨 - $color, 도구: $_selectedTool');
  }

  // 컴팩트한 드로잉 도구 위젯 (한 줄 레이아웃용)
  Widget _buildCompactDrawingTool(
    IconData icon,
    String label,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => _selectDrawingTool(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 1)
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade600,
          size: 20,
        ),
      ),
    );
  }

  // 컴팩트한 색상 옵션 위젯 (한 줄 레이아웃용)
  Widget _buildCompactColorOption(Color color, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectColor(color),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : Border.all(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  // 도구 구분선 위젯
  Widget _buildToolSeparator() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.shade300,
    );
  }

  Widget _buildTextFileItem(TextFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.keyboard, color: Theme.of(context).primaryColor),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (file.shortPreview.isNotEmpty)
              Text(
                file.shortPreview,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            AppSpacing.verticalSpaceXS,
            Text(
              '${file.characterCount}자 • ${file.updatedAt.toString().substring(0, 16)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleTextFileAction(value, file),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('편집')),
            const PopupMenuItem(value: 'duplicate', child: Text('복사')),
            const PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
        onTap: () => _editTextFile(file),
      ),
    );
  }

  Widget _buildHandwritingFileItem(HandwritingFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.draw, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          file.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  file.isFromPdf ? 'PDF 작성' : '직접 작성',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (file.isMultiPage) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${file.totalPages}페이지',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            AppSpacing.verticalSpaceXS,
            Text(
              file.updatedAt.toString().substring(0, 16),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleHandwritingFileAction(value, file),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('편집')),
            const PopupMenuItem(value: 'duplicate', child: Text('복사')),
            const PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
        onTap: () => _editHandwritingFile(file),
      ),
    );
  }

  Widget _buildTextEditor() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // 상단 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  await _hideKeyboardAndClearFocus();
                  setState(() {
                    _isEditing = false;
                    _currentTextFile = null;
                    _hasAutoFocused = false;
                  });
                  _focusTimer?.cancel();
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
                ),
              ),
              TextButton(
                onPressed: _saveCurrentTextFile,
                child: Text(l10n?.save ?? '저장'),
              ),
            ],
          ),
        ),

        // HTML 에디터 - 툴바 바로 아래부터 키보드까지 또는 하단 메인 메뉴까지
        Expanded(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blue, width: 3),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTap: () async {
                      // 터치 시 포커스 설정 및 키보드 표시
                      await _focusAndShowKeyboard();
                    },
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: HtmlEditor(
                          controller: _htmlController,
                          htmlEditorOptions: HtmlEditorOptions(
                            hint: '여기에 텍스트를 입력하세요...',
                            shouldEnsureVisible: true,
                            initialText: _currentTextFile?.content ?? '',
                            adjustHeightForKeyboard: true,
                            darkMode: false,
                            autoAdjustHeight: false,
                            spellCheck: false,
                            characterLimit: null,
                          ),
                          htmlToolbarOptions: HtmlToolbarOptions(
                            toolbarPosition: ToolbarPosition.aboveEditor,
                            toolbarType: ToolbarType.nativeScrollable,
                            renderBorder: true,
                            toolbarItemHeight: 32,
                            renderSeparatorWidget: true,
                            separatorWidget: Container(
                              width: 1,
                              height: 24,
                              color: Colors.grey.shade400,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            buttonColor: Colors.grey.shade400,
                            buttonSelectedColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.8),
                            buttonBorderColor: Colors.grey.shade700,
                            buttonBorderWidth: 2.0,
                            defaultToolbarButtons: const [
                              FontButtons(
                                bold: true,
                                italic: true,
                                underline: true,
                              ),
                              ColorButtons(),
                              ListButtons(listStyles: true),
                              ParagraphButtons(
                                textDirection: false,
                                lineHeight: false,
                                caseConverter: false,
                              ),
                            ],
                          ),
                          otherOptions: const OtherOptions(height: 350),
                          callbacks: Callbacks(
                            onInit: () async {
                              print('HTML 에디터 초기화 완료');

                              // 새 파일이고 아직 자동 포커스가 안 되었다면 자동 포커스
                              if (!_hasAutoFocused &&
                                  _currentTextFile?.content.isEmpty == true) {
                                // HTML 에디터 초기화 완료 후 즉시 자동 포커스 시도
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                await _autoFocusAndShowKeyboard();
                              }
                            },
                            onFocus: () {
                              print('HTML 에디터 포커스됨');
                              setState(() {
                                _isKeyboardVisible = true;
                              });
                            },
                            onBlur: () {
                              print('HTML 에디터 포커스 해제됨');
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHandwritingEditor() {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Column(
          children: [
            // 상단 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _currentHandwritingFile = null;
                        // 배경 이미지 정보 초기화
                        _backgroundImageOriginalSize = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      _currentHandwritingFile?.displayTitle ?? '새 필기',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // 페이지 네비게이션 (다중 페이지인 경우)
                  if (_currentHandwritingFile?.isMultiPage == true) ...[
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed:
                                  _currentHandwritingFile!.canGoPreviousPage
                                  ? _goToPreviousPage
                                  : null,
                              icon: const Icon(Icons.keyboard_arrow_left),
                              tooltip: '이전 페이지',
                            ),
                            IconButton(
                              onPressed: _currentHandwritingFile!.canGoNextPage
                                  ? _goToNextPage
                                  : null,
                              icon: const Icon(Icons.keyboard_arrow_right),
                              tooltip: '다음 페이지',
                            ),
                          ],
                        ),
                        Text(
                          _currentHandwritingFile!.pageInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  TextButton(
                    onPressed: _saveCurrentHandwritingFile,
                    child: Text(l10n?.save ?? '저장'),
                  ),
                ],
              ),
            ),
            // 필기 도구 패널 (한 줄 스크롤 가능 레이아웃)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // 사용 빈도 순서로 배열
                    _buildCompactDrawingTool(
                      Icons.pan_tool,
                      '제스처',
                      _selectedTool == '제스처',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.edit,
                      '펜',
                      _selectedTool == '펜',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.cleaning_services,
                      '지우개',
                      _selectedTool == '지우개',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.highlight,
                      '하이라이터',
                      _selectedTool == '하이라이터',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.text_fields,
                      '텍스트',
                      _selectedTool == '텍스트',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.remove,
                      '직선',
                      _selectedTool == '직선',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.arrow_forward,
                      '화살표',
                      _selectedTool == '화살표',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.crop_square,
                      '도형',
                      _selectedTool == '도형',
                    ),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.circle_outlined,
                      '원형',
                      _selectedTool == '원형',
                    ),
                    _buildToolSeparator(),

                    // 액션 도구들
                    _buildCompactDrawingTool(Icons.undo, '실행취소', false),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(Icons.redo, '다시실행', false),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(Icons.clear, '초기화', false),
                    _buildToolSeparator(),

                    // 설정 도구들
                    _buildCompactDrawingTool(Icons.line_weight, '선굵기', false),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(
                      Icons.palette,
                      '색상',
                      _showColorPicker,
                    ),
                    _buildToolSeparator(),

                    // 기본 색상 옵션들
                    _buildCompactColorOption(
                      Colors.black,
                      _selectedColor == Colors.black,
                    ),
                    _buildCompactColorOption(
                      Colors.red,
                      _selectedColor == Colors.red,
                    ),
                    _buildCompactColorOption(
                      Colors.blue,
                      _selectedColor == Colors.blue,
                    ),
                    _buildCompactColorOption(
                      Colors.green,
                      _selectedColor == Colors.green,
                    ),
                    _buildCompactColorOption(
                      Colors.yellow,
                      _selectedColor == Colors.yellow,
                    ),
                    _buildCompactColorOption(
                      Colors.orange,
                      _selectedColor == Colors.orange,
                    ),
                    _buildCompactColorOption(
                      Colors.purple,
                      _selectedColor == Colors.purple,
                    ),
                    _buildCompactColorOption(
                      Colors.brown,
                      _selectedColor == Colors.brown,
                    ),
                    _buildToolSeparator(),

                    // 확장 도구들
                    _buildCompactDrawingTool(Icons.zoom_in, '줌인', false),
                    _buildToolSeparator(),
                    _buildCompactDrawingTool(Icons.zoom_out, '줌아웃', false),
                  ],
                ),
              ),
            ),
            // 확장 색상 팔레트 (조건부 표시)
            if (_showColorPicker)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _buildCompactColorOption(
                        Colors.pink,
                        _selectedColor == Colors.pink,
                      ),
                      _buildCompactColorOption(
                        Colors.indigo,
                        _selectedColor == Colors.indigo,
                      ),
                      _buildCompactColorOption(
                        Colors.teal,
                        _selectedColor == Colors.teal,
                      ),
                      _buildCompactColorOption(
                        Colors.lime,
                        _selectedColor == Colors.lime,
                      ),
                      _buildCompactColorOption(
                        Colors.amber,
                        _selectedColor == Colors.amber,
                      ),
                      _buildCompactColorOption(
                        Colors.deepOrange,
                        _selectedColor == Colors.deepOrange,
                      ),
                      _buildCompactColorOption(
                        Colors.grey,
                        _selectedColor == Colors.grey,
                      ),
                      _buildCompactColorOption(
                        Colors.blueGrey,
                        _selectedColor == Colors.blueGrey,
                      ),
                      _buildCompactColorOption(
                        Colors.lightBlue,
                        _selectedColor == Colors.lightBlue,
                      ),
                      _buildCompactColorOption(
                        Colors.lightGreen,
                        _selectedColor == Colors.lightGreen,
                      ),
                      _buildCompactColorOption(
                        Colors.deepPurple,
                        _selectedColor == Colors.deepPurple,
                      ),
                      _buildCompactColorOption(
                        Colors.cyan,
                        _selectedColor == Colors.cyan,
                      ),
                      _buildCompactColorOption(
                        Colors.white,
                        _selectedColor == Colors.white,
                      ),
                      _buildCompactColorOption(
                        Colors.black87,
                        _selectedColor == Colors.black87,
                      ),
                      _buildCompactColorOption(
                        Colors.black54,
                        _selectedColor == Colors.black54,
                      ),
                      _buildCompactColorOption(
                        Colors.black38,
                        _selectedColor == Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),
            // 캔버스 영역
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildPainterWidget(),
                ),
              ),
            ),
            // PDF 페이지 네비게이션 (필요시에만 표시)
            if (_pdfPages != null && _pdfPages!.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_currentPdfPage + 1}/${_pdfPages!.length}'),
                    AppSpacing.horizontalSpaceS,
                    IconButton(
                      onPressed: _currentPdfPage > 0
                          ? () async {
                              setState(() {
                                _currentPdfPage--;
                              });
                              await _setBackgroundFromBytes(
                                _pdfPages![_currentPdfPage],
                              );
                            }
                          : null,
                      icon: const Icon(Icons.navigate_before),
                    ),
                    IconButton(
                      onPressed: _currentPdfPage < _pdfPages!.length - 1
                          ? () async {
                              setState(() {
                                _currentPdfPage++;
                              });
                              await _setBackgroundFromBytes(
                                _pdfPages![_currentPdfPage],
                              );
                            }
                          : null,
                      icon: const Icon(Icons.navigate_next),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // 텍스트 입력 오버레이 - 즉시 타이핑 가능한 인라인 입력
        if (_isTextInputMode && _screenTextInputPosition != null)
          Positioned(
            left: _screenTextInputPosition!.dx,
            top: _screenTextInputPosition!.dy,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 50,
                maxWidth: 300,
                minHeight: 25,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                border: Border.all(color: _selectedColor, width: 2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _canvasTextController,
                focusNode: _canvasTextFocusNode,
                autofocus: true,
                style: TextStyle(
                  color: _selectedColor,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  hintText: '입력...',
                  hintStyle: TextStyle(fontSize: 14),
                  isDense: true,
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
                onSubmitted: (text) {
                  print('DEBUG: 인라인 텍스트 onSubmitted: "$text"');
                  _confirmTextInput();
                },
                onTapOutside: (event) {
                  print('DEBUG: 인라인 텍스트 onTapOutside');
                  _handleTextInputFocusOut();
                },
              ),
            ),
          ),
      ],
    );
  }

  void _loadPdfForNewFile() async {
    await _loadPdfFile();
    // flutter_pdfview를 사용하므로 PDF 뷰어로만 표시됩니다.
    // PDF를 필기 배경으로 사용하려면 별도의 PDF to Image 변환이 필요합니다.
  }

  /// 텍스트 내용에 따라 커서 위치를 설정하는 메서드
  void _positionCursorForContent(String content) async {
    try {
      if (content.isEmpty) {
        // 내용이 없으면 1행1열로
        _htmlController.execCommand('selectAll');
        _htmlController.execCommand('collapseToStart');
      } else {
        // 내용이 있으면 마지막 라인의 다음 라인 1열로
        _htmlController.execCommand('selectAll');
        _htmlController.execCommand('collapseToEnd');
        // 추가 줄바꿈을 위해 Enter 키 입력
        _htmlController.insertText('\n');
      }
    } catch (e) {
      print('커서 위치 설정 실패: $e');
    }
  }

  void _editTextFile(TextFile file) async {
    setState(() {
      _currentTextFile = file;
      _isEditing = true;
      _hasAutoFocused = false; // 자동 포커스 플래그 리셋
    });

    // HTML 에디터가 로딩될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // HTML 컨텐츠 로드
      _htmlController.setText(file.content);

      // 자동 포커스와 키보드 표시 (한 번만)
      await _autoFocusAndShowKeyboard();
    } catch (e) {
      print('HTML 에디터 로딩 에러: $e');
    }
  }

  void _editHandwritingFile(HandwritingFile file) async {
    // UI를 즉시 편집 모드로 전환하고 제스처 도구를 기본으로 선택
    setState(() {
      _currentHandwritingFile = file;
      _isEditing = true;
      _selectedTool = '제스처'; // 제스처(손바닥) 도구를 기본으로 선택
      _isGestureMode = true; // 제스처 모드 활성화
    });

    // 이미지 로딩을 비동기로 처리하여 UI 블로킹 방지
    _loadHandwritingImageAsync(file);

    print('DEBUG: 필기 편집 시작 - 제스처 모드로 기본 설정');
  }

  // 비동기 이미지 로딩 함수
  void _loadHandwritingImageAsync(HandwritingFile file) async {
    try {
      // 저장된 필기 이미지 로드
      await _loadHandwritingImage(file);

      // 로딩 완료 후 캔버스를 좌상단으로 초기화
      _resetCanvasToTopLeft();
    } catch (e) {
      print('ERROR: 필기 이미지 비동기 로딩 실패 - $e');
    }
  }

  // 페이지 네비게이션 메서드들
  void _goToNextPage() async {
    if (_currentHandwritingFile?.canGoNextPage == true) {
      // 현재 페이지의 필기 내용을 저장
      await _saveCurrentPageDrawing();

      // 다음 페이지로 이동
      final nextPageFile = _currentHandwritingFile!.goToNextPage();
      setState(() {
        _currentHandwritingFile = nextPageFile;
      });

      // 다음 페이지 이미지 로드
      await _loadHandwritingImage(nextPageFile);

      print('DEBUG: 다음 페이지로 이동 - ${nextPageFile.pageInfo}');
    }
  }

  void _goToPreviousPage() async {
    if (_currentHandwritingFile?.canGoPreviousPage == true) {
      // 현재 페이지의 필기 내용을 저장
      await _saveCurrentPageDrawing();

      // 이전 페이지로 이동
      final previousPageFile = _currentHandwritingFile!.goToPreviousPage();
      setState(() {
        _currentHandwritingFile = previousPageFile;
      });

      // 이전 페이지 이미지 로드
      await _loadHandwritingImage(previousPageFile);

      print('DEBUG: 이전 페이지로 이동 - ${previousPageFile.pageInfo}');
    }
  }

  /// 더블 탭 처리 (좌측/우측 화면 절반에 따른 페이지 이동)
  void _handleDoubleTap(Offset position) {
    print('DEBUG: 더블 탭 감지 - 위치: $position');

    // 제스처 모드가 아닌 경우에만 동작
    if (_selectedTool != '제스처') {
      print('DEBUG: 제스처 모드가 아니므로 더블 탭 무시');
      return;
    }

    // 다중 페이지 파일이 아닌 경우 무시
    if (_currentHandwritingFile?.isMultiPage != true) {
      print('DEBUG: 단일 페이지 파일이므로 더블 탭 무시');
      return;
    }

    // 화면 너비의 절반을 기준으로 좌측/우측 판단
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = position.dx < screenWidth / 2;

    print(
      'DEBUG: 더블 탭 위치 판단 - ${isLeftSide ? '좌측' : '우측'} (${position.dx}/${screenWidth})',
    );

    if (isLeftSide) {
      // 좌측 더블 탭 -> 이전 페이지로 이동
      if (_currentHandwritingFile!.canGoPreviousPage) {
        print('DEBUG: 좌측 더블 탭 -> 이전 페이지로 이동');
        _goToPreviousPage();
      } else {
        print('DEBUG: 이전 페이지가 없음');
      }
    } else {
      // 우측 더블 탭 -> 다음 페이지로 이동
      if (_currentHandwritingFile!.canGoNextPage) {
        print('DEBUG: 우측 더블 탭 -> 다음 페이지로 이동');
        _goToNextPage();
      } else {
        print('DEBUG: 다음 페이지가 없음');
      }
    }
  }

  /// 탭 이벤트 처리 (더블 탭 감지)
  void _handleTap(Offset position) {
    final now = DateTime.now();

    // 텍스트 도구가 선택된 경우 즉시 텍스트 입력 모드 시작
    if (_selectedTool == '텍스트') {
      print('DEBUG: 텍스트 도구 선택됨 - 즉시 입력 모드 시작');
      _handleTextToolTap(position);
      return;
    }

    // 이전 탭 시간과 위치 확인
    if (_lastTapTime != null && _lastTapPosition != null) {
      final timeDiff = now.difference(_lastTapTime!);
      final positionDiff = (position - _lastTapPosition!).distance;

      // 더블 탭 조건 확인
      if (timeDiff <= _doubleTapTimeout &&
          positionDiff <= _doubleTapDistanceThreshold) {
        print(
          'DEBUG: 더블 탭 조건 만족 - 시간차: ${timeDiff.inMilliseconds}ms, 거리차: ${positionDiff.toStringAsFixed(1)}px',
        );
        _handleDoubleTap(position);

        // 더블 탭 처리 후 초기화
        _lastTapTime = null;
        _lastTapPosition = null;
        return;
      }
    }

    // 단일 탭으로 처리 (더블 탭 대기를 위한 정보 저장)
    _lastTapTime = now;
    _lastTapPosition = position;
    print('DEBUG: 단일 탭 감지 - 더블 탭 대기 중');
  }

  void _handleTextToolTap(Offset position) {
    try {
      print('DEBUG: 텍스트 도구 탭 처리 시작 - 위치: $position');

      // 터치 위치를 캔버스 좌표계로 변환
      final canvasPosition = _transformLocalToCanvasCoordinates(position);

      // 캔버스 좌표 저장
      _textInputPosition = canvasPosition;

      // 화면 좌표 계산 (UI 배치용)
      final screenPosition = _calculateGlobalTextInputPosition(position);

      // 텍스트 컨트롤러 초기화
      _canvasTextController?.clear();

      setState(() {
        _screenTextInputPosition = screenPosition;
        _isTextInputMode = true;
      });

      print('DEBUG: 텍스트 입력 모드 즉시 시작 완료');
      print('DEBUG: 캔버스 위치: $canvasPosition');
      print('DEBUG: 화면 위치: $screenPosition');
    } catch (e) {
      print('DEBUG: 텍스트 도구 탭 처리 중 오류 - $e');
    }
  }

  Future<void> _saveCurrentPageDrawing() async {
    if (_currentHandwritingFile != null && _painterController != null) {
      try {
        // 필기 내용이 있는지 확인 (drawables 목록으로 체크)
        if (_painterController.drawables.isEmpty) {
          print('DEBUG: 필기 내용이 없어서 저장하지 않음 (원본 배경 이미지 품질 보존)');
          return;
        }

        // Old 파일 방식: 배경 이미지 원본 크기로 렌더링
        Size renderSize;
        if (_backgroundImageOriginalSize != null) {
          // 배경 이미지가 있는 경우 원본 크기 사용 (품질 보존)
          renderSize = _backgroundImageOriginalSize!;
          print(
            'DEBUG: 배경 이미지 원본 크기로 렌더링 - ${renderSize.width}x${renderSize.height}',
          );
        } else {
          // 배경 이미지가 없는 경우 고해상도 사용 (비율 유지)
          final aspectRatio = _backgroundImageAspectRatio ?? 1.414; // A4 비율 기본값
          const double targetWidth = 1200; // 고해상도
          final double targetHeight = targetWidth / aspectRatio;
          renderSize = Size(targetWidth, targetHeight);
          print('DEBUG: 고해상도로 렌더링 - ${renderSize.width}x${renderSize.height}');
        }
        final ui.Image renderedImage = await _painterController!.renderImage(
          renderSize,
        );

        final ByteData? byteData = await renderedImage.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();

          if (kIsWeb) {
            await _saveCurrentPageDrawingForWeb(pngBytes);
          } else {
            await _saveCurrentPageDrawingForMobile(pngBytes);
          }
        }
      } catch (e) {
        print('ERROR: 페이지 필기 내용 저장 실패 - $e');
      }
    }
  }

  Future<void> _saveCurrentPageDrawingForWeb(Uint8List pngBytes) async {
    final storage = FileStorageService.instance;

    String drawingKey;
    if (_currentHandwritingFile!.isMultiPage &&
        _currentHandwritingFile!.pageImagePaths.isNotEmpty) {
      // 다중 페이지인 경우 필기 레이어 키 생성
      drawingKey =
          '${_currentHandwritingFile!.id}_page_${_currentHandwritingFile!.currentPageIndex + 1}_drawing.png';
      print('DEBUG: 웹 - 다중 페이지 필기 레이어 저장 - $drawingKey');
    } else {
      // 단일 페이지인 경우 필기 레이어 키 생성
      drawingKey = '${_currentHandwritingFile!.id}_drawing.png';
      print('DEBUG: 웹 - 단일 페이지 필기 레이어 저장 - $drawingKey');
    }

    final success = await storage.saveImageBytesToWeb(drawingKey, pngBytes);
    if (success) {
      print(
        'DEBUG: 웹 - 현재 페이지 필기 내용 저장 완료 - ${_currentHandwritingFile!.pageInfo}, 키: $drawingKey',
      );
    } else {
      print('ERROR: 웹 - 현재 페이지 필기 내용 저장 실패 - $drawingKey');
    }
  }

  Future<void> _saveCurrentPageDrawingForMobile(Uint8List pngBytes) async {
    // 현재 페이지의 이미지를 직접 파일로 저장
    final directory = await getApplicationDocumentsDirectory();
    final littenDir = Directory(
      '${directory.path}/litten_${_currentHandwritingFile!.littenId}',
    );

    String fileName;
    if (_currentHandwritingFile!.isMultiPage &&
        _currentHandwritingFile!.pageImagePaths.isNotEmpty) {
      // 다중 페이지인 경우 필기 레이어 파일명 생성
      fileName =
          '${_currentHandwritingFile!.id}_page_${_currentHandwritingFile!.currentPageIndex + 1}_drawing.png';
      print('DEBUG: 모바일 - 다중 페이지 필기 레이어 저장 - $fileName');
    } else {
      // 단일 페이지인 경우 필기 레이어 파일명 생성
      fileName = '${_currentHandwritingFile!.id}_drawing.png';
      print('DEBUG: 모바일 - 단일 페이지 필기 레이어 저장 - $fileName');
    }

    final pageFile = File('${littenDir.path}/$fileName');
    await pageFile.writeAsBytes(pngBytes);

    print(
      'DEBUG: 모바일 - 현재 페이지 필기 내용 저장 완료 - ${_currentHandwritingFile!.pageInfo}, 파일: $fileName',
    );
  }

  Future<void> _loadHandwritingImage(HandwritingFile file) async {
    try {
      print('디버그: 필기 이미지 로드 시작 - ${file.displayTitle} ${file.pageInfo}');

      if (kIsWeb) {
        await _loadHandwritingImageForWeb(file);
      } else {
        await _loadHandwritingImageForMobile(file);
      }
    } catch (e) {
      print('에러: 필기 이미지 로드 실패 - $e');
    }
  }

  Future<void> _loadHandwritingImageForWeb(HandwritingFile file) async {
    final storage = FileStorageService.instance;

    // 캔버스를 클리어
    _painterController.clearDrawables();

    // 파일에 저장된 비율 정보를 먼저 복원
    if (file.aspectRatio != null) {
      _backgroundImageAspectRatio = file.aspectRatio;
      print('DEBUG: 웹 - 파일 저장된 비율 정보 우선 적용 - ${file.aspectRatio}');
    }

    // UI 업데이트로 _canvasSize 계산
    setState(() {});

    // 1. 먼저 배경 이미지 로드 (원본 PDF 페이지)
    if (file.isMultiPage && file.pageImagePaths.isNotEmpty) {
      String backgroundKey;
      if (file.currentPageIndex < file.pageImagePaths.length) {
        backgroundKey = file.pageImagePaths[file.currentPageIndex];
      } else {
        backgroundKey = file.pageImagePaths.first;
      }

      print('DEBUG: 웹 - 배경 이미지 로드 시도 - 키: $backgroundKey');
      final backgroundBytes = await storage.getImageBytesFromWeb(backgroundKey);

      if (backgroundBytes != null) {
        await _setBackgroundFromBytes(backgroundBytes);
        print('DEBUG: 웹 - 배경 이미지 로드 완료 - $backgroundKey');
      } else {
        print('ERROR: 웹 - 배경 이미지 로드 실패 - $backgroundKey');
      }
    }

    // 2. 필기 레이어 로드 (있으면)
    String drawingKey;
    if (file.isMultiPage && file.pageImagePaths.isNotEmpty) {
      drawingKey = '${file.id}_page_${file.currentPageIndex + 1}_drawing.png';
    } else {
      drawingKey = '${file.id}_drawing.png';
    }

    final drawingBytes = await storage.getImageBytesFromWeb(drawingKey);
    if (drawingBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDrawingLayer(drawingBytes);
        print('DEBUG: 웹 - 필기 레이어 로드 완료 - $drawingKey');
      });
    } else {
      print('DEBUG: 웹 - 필기 레이어 파일 없음 - $drawingKey (새로운 필기 가능)');
    }
  }

  Future<void> _loadHandwritingImageForMobile(HandwritingFile file) async {
    final directory = await getApplicationDocumentsDirectory();
    final littenDir = Directory('${directory.path}/litten_${file.littenId}');

    // 다중 페이지인 경우 현재 페이지의 이미지 경로를 사용
    String targetPath;
    String fileName;

    if (file.isMultiPage && file.pageImagePaths.isNotEmpty) {
      // 새로운 파일명 구조: {mainFileId}_page_{pageNumber}.png
      if (file.currentPageIndex < file.pageImagePaths.length) {
        fileName = file.pageImagePaths[file.currentPageIndex];
      } else {
        // 페이지 인덱스가 범위를 벗어나는 경우 첫 번째 페이지로 폴백
        fileName = file.pageImagePaths.first;
      }

      // fileName이 이미 실제 파일명인지 확인 (예: "abc123_page_1.png")
      if (fileName.contains('_page_')) {
        targetPath = '${littenDir.path}/$fileName';
        print(
          '디버그: 모바일 - 다중 페이지 - 페이지 ${file.currentPageIndex + 1} 파일 로드: $fileName',
        );
      } else {
        // 기존 가상 경로 형태인 경우 새 파일명 구조로 변환
        final pageNumber = file.currentPageIndex + 1;
        fileName = '${file.id}_page_$pageNumber.png';
        targetPath = '${littenDir.path}/$fileName';
        print('디버그: 모바일 - 다중 페이지 - 페이지 $pageNumber 파일 로드 (변환됨): $fileName');
      }
    } else {
      // 단일 페이지인 경우 기존 방식 사용
      fileName = '${file.id}.png';
      targetPath = '${littenDir.path}/$fileName';
      print('디버그: 모바일 - 단일 페이지 파일 로드: $fileName');
    }

    final imageFile = File(targetPath);

    // 필기 레이어 파일 확인 및 로드
    String drawingFileName;
    if (file.isMultiPage && file.pageImagePaths.isNotEmpty) {
      drawingFileName =
          '${file.id}_page_${file.currentPageIndex + 1}_drawing.png';
    } else {
      drawingFileName = '${file.id}_drawing.png';
    }

    final drawingFile = File('${littenDir.path}/$drawingFileName');

    // 캔버스를 클리어
    _painterController.clearDrawables();

    // 파일에 저장된 비율 정보를 먼저 복원
    if (file.aspectRatio != null) {
      _backgroundImageAspectRatio = file.aspectRatio;
      print('DEBUG: 모바일 - 파일 저장된 비율 정보 우선 적용 - ${file.aspectRatio}');
    }

    // UI 업데이트로 _canvasSize 계산
    setState(() {});

    // 1. 먼저 배경 이미지 로드 (원본 PDF 페이지)
    if (file.isMultiPage && file.pageImagePaths.isNotEmpty) {
      final backgroundFileName = file.pageImagePaths[file.currentPageIndex];
      final backgroundFile = File('${littenDir.path}/$backgroundFileName');

      if (await backgroundFile.exists()) {
        final backgroundBytes = await backgroundFile.readAsBytes();
        await _setBackgroundFromBytes(backgroundBytes);
        print('DEBUG: 모바일 - 배경 이미지 로드 완료 - $backgroundFileName');
      }
    }

    // 2. 필기 레이어 로드 (있으면)
    if (await drawingFile.exists()) {
      final drawingBytes = await drawingFile.readAsBytes();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDrawingLayer(drawingBytes);
        print('DEBUG: 모바일 - 필기 레이어 로드 완료 - $drawingFileName');
      });
    } else {
      print('DEBUG: 모바일 - 필기 레이어 파일 없음 - $drawingFileName (새로운 필기 가능)');
    }
  }

  // 필기 레이어만 로드하는 함수
  Future<void> _loadDrawingLayer(Uint8List drawingBytes) async {
    try {
      // Uint8List를 ui.Image로 변환
      final codec = await ui.instantiateImageCodec(drawingBytes);
      final frameInfo = await codec.getNextFrame();
      final uiImage = frameInfo.image;

      print(
        'DEBUG: 필기 레이어 이미지 크기 - 너비: ${uiImage.width}, 높이: ${uiImage.height}',
      );

      // 필기 레이어를 배경으로 설정 (원래 방식)
      _painterController.background = ImageBackgroundDrawable(image: uiImage);
      print('DEBUG: 필기 레이어를 배경으로 로드 완료');

      // UI 업데이트
      setState(() {});
    } catch (e) {
      print('ERROR: 필기 레이어 로드 실패 - $e');
    }
  }

  Future<void> _loadSavedDrawingImage(
    Uint8List imageBytes,
    HandwritingFile file,
  ) async {
    try {
      // Uint8List를 ui.Image로 변환
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final uiImage = frameInfo.image;

      // 원본 이미지 크기 정보 및 비율 계산
      print(
        'DEBUG: 배경 이미지 원본 크기 - 너비: ${uiImage.width}, 높이: ${uiImage.height}',
      );

      // 파일에 저장된 비율 정보를 절대 우선으로 사용 (이미지 크기는 무시)
      if (file.aspectRatio != null) {
        _backgroundImageAspectRatio = file.aspectRatio;
        print(
          'DEBUG: 파일 저장된 비율 정보 강제 적용 - ${file.aspectRatio} (이미지 크기 ${uiImage.width}x${uiImage.height} 무시)',
        );
      } else if (uiImage.width > 0 && uiImage.height > 0) {
        _backgroundImageAspectRatio = uiImage.width / uiImage.height;
        print('DEBUG: 비율 정보가 없어서 이미지에서 계산 - $_backgroundImageAspectRatio');
      }

      // 이미지 크기 정보 저장 (표시용, 비율 계산에는 사용 안 함)
      if (uiImage.width > 0 && uiImage.height > 0) {
        _backgroundImageOriginalSize = Size(
          uiImage.width.toDouble(),
          uiImage.height.toDouble(),
        );
        print('DEBUG: 저장된 이미지 크기 - ${uiImage.width}x${uiImage.height} (표시용)');
      }

      // 저장된 이미지를 배경으로 직접 설정 (리사이즈 없이)
      // Flutter Painter가 자동으로 캔버스 크기에 맞춰 스케일링 처리함
      _painterController.background = uiImage.backgroundDrawable;

      // UI 업데이트
      setState(() {});

      // 캔버스를 좌상단으로 초기화
      _resetCanvasToTopLeft();

      print('DEBUG: 배경 이미지 설정 완료');
    } catch (e) {
      print('ERROR: 저장된 필기 이미지 로드 실패 - $e');
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

  void _handleHandwritingFileAction(String action, HandwritingFile file) {
    switch (action) {
      case 'edit':
        _editHandwritingFile(file);
        break;
      case 'duplicate':
        // TODO: 파일 복사 로직
        break;
      case 'delete':
        _showDeleteConfirmDialog(file.displayTitle, () {
          _deleteHandwritingFile(file);
        });
        break;
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

  Future<void> _deleteHandwritingFile(HandwritingFile file) async {
    try {
      print('디버그: 필기 파일 삭제 시작 - ${file.displayTitle}');

      // 실제 파일 시스템에서 이미지 파일 삭제
      final storage = FileStorageService.instance;
      await storage.deleteHandwritingFile(file);

      // 메모리에서 제거
      setState(() {
        _handwritingFiles.removeWhere((f) => f.id == file.id);
      });

      // 파일 목록 업데이트하여 SharedPreferences에 저장
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten != null) {
        await storage.saveHandwritingFiles(
          selectedLitten.id,
          _handwritingFiles,
        );

        // 리튼에서 파일 제거
        final littenService = LittenService();
        await littenService.removeHandwritingFileFromLitten(
          selectedLitten.id,
          file.id,
        );
      }

      print('디버그: 필기 파일 삭제 완료 - ${file.displayTitle}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.displayTitle} 파일이 삭제되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('에러: 필기 파일 삭제 실패 - $e');
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

  Future<void> _saveCurrentTextFile() async {
    if (_currentTextFile != null) {
      try {
        print('디버그: 텍스트 파일 저장 시작 - ${_currentTextFile!.displayTitle}');

        // HTML 콘텐츠 가져오기 - 실패 시 현재 저장된 콘텐츠 사용
        String htmlContent = '';
        try {
          htmlContent = await _htmlController.getText();
          print('디버그: HTML 내용 로드됨 - 길이: ${htmlContent.length}자');
        } catch (e) {
          print('경고: HTML 콘텐츠 가져오기 실패, 기존 내용 사용: $e');
          htmlContent = _currentTextFile?.content ?? '';
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
        }

        setState(() {
          _isEditing = false;
          _currentTextFile = null;
        });

        _focusTimer?.cancel();

        print('디버그: 텍스트 파일 저장 완료 - 총 ${_textFiles.length}개 파일');

        // 파일 수 배지 업데이트를 위해 AppStateProvider 리플래시
        await appState.refreshLittens();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${updatedFile.displayTitle} 파일이 저장되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('에러: 텍스트 파일 저장 실패 - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _saveCurrentHandwritingFile() async {
    if (_currentHandwritingFile != null) {
      final String fileTitle = _currentHandwritingFile!.displayTitle;
      try {
        print(
          '디버그: 필기 파일 저장 시작 - $fileTitle ${_currentHandwritingFile!.pageInfo}',
        );

        // 필기 내용이 있을 때만 저장
        if (_painterController.drawables.isNotEmpty) {
          await _saveCurrentPageDrawing();
          print('DEBUG: 필기 내용 있어서 저장함');
        } else {
          print('DEBUG: 필기 내용 없어서 저장 건너뜀');
        }

        // 파일 목록에서 현재 파일의 페이지 정보 업데이트 (비율 정보 포함)
        final currentAspectRatio = _getCanvasAspectRatio();
        final updatedFile = _currentHandwritingFile!.copyWith(
          aspectRatio: currentAspectRatio,
        );
        print('DEBUG: 필기 파일 저장 - 비율 정보 업데이트: $currentAspectRatio');
        final existingIndex = _handwritingFiles.indexWhere(
          (f) => f.id == updatedFile.id,
        );

        // appState를 미리 가져옴
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final selectedLitten = appState.selectedLitten;

        if (existingIndex >= 0) {
          _handwritingFiles[existingIndex] = updatedFile;
          print(
            '디버그: 기존 필기 파일 페이지 정보 업데이트됨 - ${updatedFile.displayTitle} ${updatedFile.pageInfo}',
          );
        } else {
          // 새로운 파일인 경우 목록에 추가
          _handwritingFiles.add(updatedFile);
          print(
            '디버그: 새로운 필기 파일 목록에 추가됨 - ${updatedFile.displayTitle} ${updatedFile.pageInfo}',
          );

          // 리튼에 필기 파일 추가
          if (selectedLitten != null) {
            final littenService = LittenService();
            await littenService.addHandwritingFileToLitten(
              selectedLitten.id,
              updatedFile.id,
            );
          }
        }

        // SharedPreferences에 파일 목록 저장

        if (selectedLitten != null) {
          final storage = FileStorageService.instance;
          await storage.saveHandwritingFiles(
            selectedLitten.id,
            _handwritingFiles,
          );
        }

        print(
          '디버그: 필기 파일 저장 완료 - $fileTitle ${_currentHandwritingFile!.pageInfo}',
        );

        // 저장 완료 알림을 위한 간단한 피드백 (선택사항)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장되었습니다'),
            duration: const Duration(seconds: 1),
          ),
        );

        // 편집 모드를 유지하고 화면 전환하지 않음
        // setState(() {
        //   _isEditing = false;
        //   _currentHandwritingFile = null;
        //   _backgroundImageOriginalSize = null;
        // });
      } catch (e) {
        print('에러: 필기 파일 저장 실패 - $e');
      }
    }
  }

  Widget _buildAudioFileItem(AudioFile audioFile) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.s),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.hearing,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          audioFile.fileName,
          style: AppTextStyles.headline3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              timeFormat.format(audioFile.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(width: 12),
            Icon(Icons.timer, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              _formatDuration(audioFile.duration ?? Duration.zero),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 재생/정지 버튼
            AnimatedBuilder(
              animation: _audioService,
              builder: (context, child) {
                final isCurrentlyPlaying = _audioService.isPlaying &&
                    _audioService.currentPlayingFile?.id == audioFile.id;

                return IconButton(
                  onPressed: () => _playAudio(audioFile),
                  icon: Icon(
                    isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                    color: Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
            // 삭제 버튼
            IconButton(
              onPressed: () => _deleteAudioFile(audioFile),
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    if (_audioService.isRecording) {
      final audioFile = await _audioService.stopRecording(selectedLitten);
      if (audioFile != null) {
        await _loadFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('녹음이 저장되었습니다: ${audioFile.fileName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      final success = await _audioService.startRecording(selectedLitten);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('녹음을 시작할 수 없습니다. 마이크 권한을 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playAudio(AudioFile audioFile) async {
    if (_audioService.isPlaying && _audioService.currentPlayingFile?.id == audioFile.id) {
      await _audioService.stopAudio();
    } else {
      await _audioService.playAudio(audioFile);
    }
  }

  Future<void> _deleteAudioFile(AudioFile audioFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오디오 파일 삭제'),
        content: Text('${audioFile.fileName}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _audioService.deleteAudioFile(audioFile);
      if (success) {
        await _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${audioFile.fileName}이(가) 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  // WebView URL 로드 함수
  void _loadUrl(String url) async {
    if (url.isEmpty) return;

    // URL 정규화 - http:// 또는 https://가 없으면 추가
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    try {
      if (_webViewController == null) {
        // WebViewController 초기화
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // 로딩 진행률 처리
              },
              onPageStarted: (String url) {
                setState(() {
                  _currentUrl = url;
                });
                // SessionService에 현재 활성 URL 저장
                _sessionService.setCurrentActiveUrl(url);
              },
              onPageFinished: (String url) {
                setState(() {
                  _currentUrl = url;
                });
                // SessionService에 현재 활성 URL 저장
                _sessionService.setCurrentActiveUrl(url);
                // 백그라운드 재생을 위한 JavaScript 실행
                _enableBackgroundPlayback();
              },
            ),
          );
      }

      await _webViewController!.loadRequest(Uri.parse(finalUrl));

      setState(() {
        _currentUrl = finalUrl;
      });

      // SessionService에 현재 활성 URL 저장
      _sessionService.setCurrentActiveUrl(finalUrl);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URL을 로드할 수 없습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 현재 URL의 즐겨찾기 상태 업데이트
  Future<void> _updateBookmarkStatus() async {
    if (_currentUrl.isNotEmpty) {
      final isBookmarked = await _bookmarkService.isBookmarked(_currentUrl);
      setState(() {
        _isCurrentUrlBookmarked = isBookmarked;
      });
    }
  }

  // 즐겨찾기 토글
  Future<void> _toggleBookmark() async {
    if (_currentUrl.isEmpty) return;

    if (_isCurrentUrlBookmarked) {
      final bookmarks = await _bookmarkService.getBookmarks();
      final bookmark = bookmarks.firstWhere((b) => b.url == _currentUrl);
      final success = await _bookmarkService.removeBookmark(bookmark.id);
      if (success && mounted) {
        setState(() => _isCurrentUrlBookmarked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('즐겨찾기에서 제거되었습니다')),
        );
      }
    } else {
      final title = await _getPageTitle() ?? _extractTitleFromUrl(_currentUrl);
      final success = await _bookmarkService.addBookmark(title, _currentUrl);
      if (success && mounted) {
        setState(() => _isCurrentUrlBookmarked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('즐겨찾기에 추가되었습니다')),
        );
      }
    }
  }

  // 즐겨찾기 목록 토글
  void _toggleBookmarksList() {
    setState(() {
      _showBookmarks = !_showBookmarks;
    });
  }

  // 즐겨찾기에서 URL 선택
  void _onBookmarkSelected(String url) {
    _urlController.text = url;
    _loadUrl(url);
    setState(() {
      _showBookmarks = false;
    });
  }

  /// 웹뷰에서 백그라운드 미디어 재생을 활성화합니다
  Future<void> _enableBackgroundPlayback() async {
    if (_webViewController == null) return;

    try {
      print('🎵 웹뷰 백그라운드 재생 설정 중...');

      // 백그라운드 재생을 위한 JavaScript 코드 실행
      await _webViewController!.runJavaScript('''
        (function() {
          // 미디어 세션 API가 지원되는 경우 활성화
          if ('mediaSession' in navigator) {
            console.log('Media Session API 지원됨');

            // 미디어 핸들러 설정
            navigator.mediaSession.setActionHandler('play', () => {
              console.log('Media Session: 재생 이벤트');
              const videos = document.querySelectorAll('video');
              const audios = document.querySelectorAll('audio');

              videos.forEach(video => {
                if (video.paused) video.play().catch(e => console.log(e));
              });
              audios.forEach(audio => {
                if (audio.paused) audio.play().catch(e => console.log(e));
              });
            });

            navigator.mediaSession.setActionHandler('pause', () => {
              console.log('Media Session: 일시정지 이벤트');
              const videos = document.querySelectorAll('video');
              const audios = document.querySelectorAll('audio');

              videos.forEach(video => {
                if (!video.paused) video.pause();
              });
              audios.forEach(audio => {
                if (!audio.paused) audio.pause();
              });
            });
          }

          // 모든 비디오/오디오 요소에 백그라운드 재생 설정
          const mediaElements = [...document.querySelectorAll('video'), ...document.querySelectorAll('audio')];
          mediaElements.forEach(element => {
            // 백그라운드 재생 허용
            element.setAttribute('playsinline', 'true');
            if (element.tagName === 'VIDEO') {
              // 비디오의 경우 picture-in-picture 지원
              if ('pictureInPictureEnabled' in document) {
                element.setAttribute('pip', 'true');
              }
            }
          });

          // 새로 추가되는 미디어 요소에도 설정 적용
          const observer = new MutationObserver(mutations => {
            mutations.forEach(mutation => {
              mutation.addedNodes.forEach(node => {
                if (node.nodeType === 1) { // ELEMENT_NODE
                  const newMediaElements = [...node.querySelectorAll('video'), ...node.querySelectorAll('audio')];
                  newMediaElements.forEach(element => {
                    element.setAttribute('playsinline', 'true');
                    if (element.tagName === 'VIDEO' && 'pictureInPictureEnabled' in document) {
                      element.setAttribute('pip', 'true');
                    }
                  });
                }
              });
            });
          });

          observer.observe(document.body, {
            childList: true,
            subtree: true
          });

          console.log('백그라운드 재생 설정 완료');
        })();
      ''');

      print('✅ 웹뷰 백그라운드 재생 설정 완료');
    } catch (e) {
      print('❌ 웹뷰 백그라운드 재생 설정 에러: $e');
    }
  }

  // WebView 초기화
  Future<void> _initializeWebView() async {
    if (_webViewController == null) {
      // 우선순위: 1) 현재 _currentUrl 2) SessionService 활성 URL 3) 기본 URL
      String urlToLoad;
      if (_currentUrl.isNotEmpty) {
        urlToLoad = _currentUrl;
      } else {
        final activeUrl = _sessionService.getCurrentActiveUrl();
        if (activeUrl != null && activeUrl.isNotEmpty) {
          urlToLoad = activeUrl;
          _currentUrl = activeUrl; // 복원된 URL로 _currentUrl 업데이트
        } else {
          urlToLoad = _sessionService.getDefaultUrl();
        }
      }
      debugPrint('🌐 WebView 초기화: $_currentUrl → $urlToLoad');
      _loadUrl(urlToLoad);
    }
  }

  // 페이지 제목 가져오기
  Future<String?> _getPageTitle() async {
    try {
      if (_webViewController != null) {
        return await _webViewController!.getTitle();
      }
    } catch (e) {
      debugPrint('페이지 제목 가져오기 실패: $e');
    }
    return null;
  }

  // URL에서 제목 추출
  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (e) {
      return url;
    }
  }

}

enum WritingMode { text, handwriting }
