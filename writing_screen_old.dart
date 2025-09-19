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
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late HtmlEditorController _htmlController;
  late PainterController _painterController;
  final AudioService _audioService = AudioService();
  
  // 파일 목록 관련
  List<TextFile> _textFiles = [];
  List<HandwritingFile> _handwritingFiles = [];
  bool _isLoading = false;
  
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
  bool _showAdvancedTools = false;
  bool _showColorPicker = false;
  double? _backgroundImageAspectRatio;
  Size? _backgroundImageOriginalSize;

  // 제스처 및 애니메이션 관련
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  // 캔버스 내 텍스트 입력 관련
  bool _isTextInputMode = false;
  TextEditingController? _canvasTextController;
  FocusNode? _canvasTextFocusNode;
  Offset? _textInputPosition;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _htmlController = HtmlEditorController();
    _painterController = PainterController();
    _transformationController = TransformationController();

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

    _zoomAnimation = Matrix4Tween(
      begin: startMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

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
    // 앱이 포어그라운드로 돌아왔을 때 파일 목록 재로드
    if (state == AppLifecycleState.resumed) {
      _loadFiles();
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

  // 음성-쓰기 동기화 상태 표시 위젯
  Widget _buildSyncStatusBar() {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Icon(
                _audioService.isRecording ? Icons.mic : Icons.sync, 
                color: Colors.black87, 
                size: 16
              );
            },
          ),
          AppSpacing.horizontalSpaceS,
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Text(
                _audioService.isRecording 
                    ? (l10n?.recording ?? '듣기 중...')
                    : (l10n?.recordingTitle ?? '음성 동기화 준비됨'),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _audioService,
            builder: (context, child) {
              return Text(
                _audioService.isRecording 
                    ? _formatDuration(_audioService.recordingDuration)
                    : '00:00',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위한 리소스 정리
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    _canvasTextController?.dispose();
    _canvasTextFocusNode?.dispose();
    _htmlController.disable();
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
            description: l10n?.emptyLittenDescription ?? '쓰기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
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

        // 텍스트 파일과 필기 파일을 병렬로 로드하여 성능 향상
        final textFilesFuture = storage.loadTextFiles(selectedLitten.id);
        final handwritingFilesFuture = storage.loadHandwritingFiles(selectedLitten.id);

        final results = await Future.wait([textFilesFuture, handwritingFilesFuture]);

        final loadedTextFiles = results[0] as List<TextFile>;
        final loadedHandwritingFiles = results[1] as List<HandwritingFile>;

        // 한 번의 setState로 모든 상태 업데이트
        if (mounted) {
          setState(() {
            _textFiles
              ..clear()
              ..addAll(loadedTextFiles);
            _handwritingFiles
              ..clear()
              ..addAll(loadedHandwritingFiles);
            _isLoading = false;
          });
        }

        print('디버그: 파일 목록 로드 완료 - 텍스트: ${_textFiles.length}개, 필기: ${_handwritingFiles.length}개');
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
        // 음성-쓰기 동기화 상태 표시
        _buildSyncStatusBar(),
        // 파일 목록
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_textFiles.isEmpty && _handwritingFiles.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_add,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          AppSpacing.verticalSpaceM,
                          Text(
                            '아직 작성된 파일이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          AppSpacing.verticalSpaceS,
                          Text(
                            '아래 버튼을 눌러 새로운 파일을 만들어보세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // 텍스트 파일 섹션 (상단 절반)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              // 텍스트 파일 헤더
                              Container(
                                padding: AppSpacing.paddingM,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.keyboard, size: 20, color: Theme.of(context).primaryColor),
                                    AppSpacing.horizontalSpaceS,
                                    Text(
                                      '텍스트 (${_textFiles.length})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 텍스트 파일 리스트
                              Expanded(
                                child: _textFiles.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
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
                                          return _buildTextFileItem(_textFiles[index]);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        // 구분선
                        Container(
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                        // 필기 파일 섹션 (하단 절반)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              // 필기 파일 헤더
                              Container(
                                padding: AppSpacing.paddingM,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.draw, size: 20, color: Theme.of(context).primaryColor),
                                    AppSpacing.horizontalSpaceS,
                                    Text(
                                      '필기 (${_handwritingFiles.length})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 필기 파일 리스트
                              Expanded(
                                child: _handwritingFiles.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
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
                                          return _buildHandwritingFileItem(_handwritingFiles[index]);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
        // 새로 만들기 버튼 - 하단으로 이동
        Container(
          padding: AppSpacing.paddingM,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createNewTextFile,
                      icon: const Icon(Icons.keyboard),
                      label: Text(l10n?.textWriting ?? '텍스트 쓰기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  AppSpacing.horizontalSpaceM,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createNewHandwritingFile,
                      icon: const Icon(Icons.draw),
                      label: Text(l10n?.handwriting ?? '필기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              // 하단 네비게이션 바와의 간격 확보
              const SizedBox(height: 16),
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
      final defaultTitle = '텍스트 ${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
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
      final defaultTitle = '필기 ${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      // 임시 경로 - 실제로는 제대로 된 경로를 사용해야 함
      final newHandwritingFile = HandwritingFile(
        littenId: selectedLitten.id,
        title: defaultTitle,
        imagePath: '/temp/new_handwriting.png',
        type: HandwritingType.drawing,
        aspectRatio: _backgroundImageAspectRatio ?? (3.0 / 4.0), // 현재 비율 또는 기본 3:4 비율
      );
      
      print('디버그: 새로운 필기 파일 생성 - $defaultTitle');
      
      setState(() {
        _currentHandwritingFile = newHandwritingFile;
        _isEditing = true;
        // 캔버스 및 배경 이미지 정보 초기화
        _painterController.clearDrawables();
        _backgroundImageOriginalSize = null;
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

          // 실제 캔버스 크기 계산
          double canvasWidth, canvasHeight;
          if (maxWidth / maxHeight > aspectRatio) {
            // 높이 기준으로 크기 결정
            canvasHeight = maxHeight;
            canvasWidth = canvasHeight * aspectRatio;
          } else {
            // 너비 기준으로 크기 결정
            canvasWidth = maxWidth;
            canvasHeight = canvasWidth / aspectRatio;
          }

          // 실제 캔버스 크기 저장
          _canvasSize = Size(canvasWidth, canvasHeight);

          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: _minScale,
            maxScale: _maxScale,
            constrained: true,
            boundaryMargin: const EdgeInsets.all(20),
            // 제스처 기능 활성화
            panEnabled: true,           // 팬(이동) 제스처 항상 활성화
            scaleEnabled: true,         // 스케일(확대/축소) 제스처 항상 활성화
            // 클립 비활성화로 경계 밖에서도 제스처 가능
            clipBehavior: Clip.none,
            // 더블 탭으로 줌인/줌아웃
            onInteractionStart: (details) {
              print('DEBUG: 제스처 시작 - 포인터 수: ${details.pointerCount}');
            },
            onInteractionUpdate: (details) {
              // 현재 변환 상태 업데이트
              final Matrix4 matrix = _transformationController.value;
              final double scale = matrix.getMaxScaleOnAxis();
              print('DEBUG: 제스처 업데이트 - 스케일: ${scale.toStringAsFixed(2)}');
            },
            onInteractionEnd: (details) {
              print('DEBUG: 제스처 종료');
              // 스케일 범위 체크 및 조정
              final Matrix4 matrix = _transformationController.value;
              final double scale = matrix.getMaxScaleOnAxis();
              if (scale < _minScale || scale > _maxScale) {
                final double clampedScale = scale.clamp(_minScale, _maxScale);
                final double scaleFactor = clampedScale / scale;
                _transformationController.value = matrix.scaled(scaleFactor);
              }
            },
            child: Stack(
              children: [
                // 메인 캔버스 - InteractiveViewer의 제스처가 작동하도록 직접 배치
                SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: IgnorePointer(
                    ignoring: _isTextInputMode, // 텍스트 입력 모드에서만 포인터 무시
                    child: FlutterPainter(
                      controller: _painterController,
                    ),
                  ),
                ),
                // 텍스트 입력 전용 제스처 감지 레이어
                if (_isTextInputMode)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        setState(() {
                          _textInputPosition = details.localPosition;
                        });
                        _showCanvasTextInput();
                      },
                      child: Container(),
                    ),
                  ),
                // 텍스트 입력 오버레이
                if (_isTextInputMode && _textInputPosition != null)
                  _buildCanvasTextInput(),
              ],
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
                          await _convertPdfToPngAndAddToHandwriting(pdfPath, fileName);
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

  Future<void> _convertPdfToPngAndAddToHandwriting(String pdfPath, String fileName) async {
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
      final littenDir = Directory('${directory.path}/litten_${selectedLitten.id}');
      if (!await littenDir.exists()) {
        await littenDir.create(recursive: true);
      }

      final titleWithoutExtension = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
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
        final List<int> pageIndices = List.generate(endPage - startPage, (index) => startPage + index);

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
          final pageFileName = '${mainHandwritingFile.id}_page_${pageIndex + 1}.png';
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

        print('DEBUG: 다중 페이지 필기 파일 생성 - 제목: $titleWithoutExtension, 페이지 수: $totalPages');

        // 필기 파일 목록에 추가
        setState(() {
          _handwritingFiles.add(newHandwritingFile);
          _currentHandwritingFile = newHandwritingFile;
          _isEditing = true;
          _isConverting = false;
        });

        // 필기 파일 목록을 SharedPreferences에 저장
        await storage.saveHandwritingFiles(selectedLitten.id, _handwritingFiles);

        // 리튼에 필기 파일 추가
        final littenService = LittenService();
        await littenService.addHandwritingFileToLitten(selectedLitten.id, newHandwritingFile.id);

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
              content: Text('$titleWithoutExtension ($totalPages페이지)이(가) 필기 파일로 추가되었습니다.'),
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

  Future<void> _setBackgroundFromBytes(Uint8List imageBytes) async {
    try {
      // Uint8List를 ui.Image로 변환 후 배경으로 설정
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final uiImage = frameInfo.image;

      // 원본 이미지 크기 정보 로그 및 비율 계산
      print('DEBUG: 배경 이미지 원본 크기 - 너비: ${uiImage.width}, 높이: ${uiImage.height}');

      // 이미지 비율과 원본 크기 저장
      if (uiImage.width > 0 && uiImage.height > 0) {
        _backgroundImageAspectRatio = uiImage.width / uiImage.height;
        _backgroundImageOriginalSize = Size(uiImage.width.toDouble(), uiImage.height.toDouble());
        print('DEBUG: 배경 이미지 정보 저장 - 비율: $_backgroundImageAspectRatio, 크기: ${uiImage.width}x${uiImage.height}');
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
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
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
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
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
          _painterController.freeStyleColor = _selectedColor.withValues(alpha: 0.5);
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
      final Offset center = Offset(viewportSize.width / 2, viewportSize.height / 2);

      // 중심점을 기준으로 확대
      final Matrix4 matrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(scaleDelta)
        ..translate(-center.dx, -center.dy);

      // 부드러운 애니메이션으로 변환
      final Matrix4 targetMatrix = matrix * currentTransform;
      _animateToTransform(targetMatrix);

      print('DEBUG: 줌인 - 현재 스케일: ${currentScale.toStringAsFixed(2)} -> ${newScale.toStringAsFixed(2)}');
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
      final Offset center = Offset(viewportSize.width / 2, viewportSize.height / 2);

      // 중심점을 기준으로 축소
      final Matrix4 matrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(scaleDelta)
        ..translate(-center.dx, -center.dy);

      // 부드러운 애니메이션으로 변환
      final Matrix4 targetMatrix = matrix * currentTransform;
      _animateToTransform(targetMatrix);

      print('DEBUG: 줌아웃 - 현재 스케일: ${currentScale.toStringAsFixed(2)} -> ${newScale.toStringAsFixed(2)}');
    }
  }

  void _showTextInput() {
    setState(() {
      _isTextInputMode = true;
      _selectedTool = '텍스트';
      // 기본 텍스트 입력 위치를 캔버스 중앙으로 설정
      final Size canvasSize = _canvasSize ?? const Size(300, 400);
      _textInputPosition = Offset(canvasSize.width / 4, canvasSize.height / 4);
    });
    print('DEBUG: 캔버스 내 텍스트 입력 모드 활성화');
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
              style: TextStyle(
                color: _selectedColor,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: '텍스트를 입력하세요',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: null,
              autofocus: true,
              onSubmitted: (text) => _confirmTextInput(),
              onTapOutside: (event) => _cancelTextInput(),
            ),
            // 버튼들
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _cancelTextInput,
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _confirmTextInput,
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
    final text = _canvasTextController!.text.trim();
    if (text.isNotEmpty) {
      _addTextToCanvas(text);
    }
    _cancelTextInput();
  }

  void _cancelTextInput() {
    setState(() {
      _isTextInputMode = false;
      _textInputPosition = null;
      _selectedTool = '펜'; // 기본 도구로 돌아가기
    });
    _canvasTextFocusNode!.unfocus();
    print('DEBUG: 텍스트 입력 모드 종료');
  }

  void _addTextToCanvas(String text) {
    try {
      if (_textInputPosition != null) {
        // FlutterPainter의 올바른 텍스트 추가 방법
        _painterController.textSettings = TextSettings(
          textStyle: TextStyle(
            color: _selectedColor,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        );

        // 텍스트 drawable 생성하여 추가
        final textDrawable = TextDrawable(
          text: text,
          position: _textInputPosition!,
          style: TextStyle(
            color: _selectedColor,
            fontSize: 16,
          ),
        );

        _painterController.addDrawables([textDrawable]);
        print('DEBUG: 텍스트 추가 완료 - "$text" at ${_textInputPosition!}');
      }
    } catch (e) {
      print('DEBUG: 텍스트 추가 실패 - $e');
      // 간단한 fallback: 텍스트 위치를 로그로만 기록
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
          _painterController.freeStyleColor = _selectedColor.withValues(alpha: 0.5);
          break;
        case '도형':
          _painterController.shapeFactory = RectangleFactory();
          break;
      }
    });
    
    print('DEBUG: 색상 변경됨 - $color, 도구: $_selectedTool');
  }

  // 컴팩트한 드로잉 도구 위젯 (한 줄 레이아웃용)
  Widget _buildCompactDrawingTool(IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectDrawingTool(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 1) : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
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
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.keyboard, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          file.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
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
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.draw, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          file.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  file.isFromPdf ? 'PDF에서 변환됨' : '직접 작성',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (file.isMultiPage) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
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
        // 음성-쓰기 동기화 상태 표시
        _buildSyncStatusBar(),
        // 상단 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
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
                  buttonSelectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  buttonBorderColor: Colors.grey.shade700,
                  buttonBorderWidth: 2.0,
                  defaultToolbarButtons: const [
                    FontButtons(bold: true, italic: true, underline: true),
                    ColorButtons(),
                    ListButtons(listStyles: true),
                    ParagraphButtons(textDirection: false, lineHeight: false, caseConverter: false),
                  ],
                ),
                otherOptions: const OtherOptions(
                  height: 350,
                ),
                callbacks: Callbacks(
                  onInit: () async {
                    print('HTML 에디터 초기화 완료');
                    
                    // 새 파일이고 아직 자동 포커스가 안 되었다면 자동 포커스
                    if (!_hasAutoFocused && _currentTextFile?.content.isEmpty == true) {
                      // HTML 에디터 초기화 완료 후 즉시 자동 포커스 시도
                      await Future.delayed(const Duration(milliseconds: 100));
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
    return Column(
      children: [
        // 음성-쓰기 동기화 상태 표시
        _buildSyncStatusBar(),
        // 상단 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentHandwritingFile?.displayTitle ?? '새 필기',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_currentHandwritingFile?.isMultiPage == true)
                      Text(
                        _currentHandwritingFile!.pageInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              // 페이지 네비게이션 (다중 페이지인 경우)
              if (_currentHandwritingFile?.isMultiPage == true) ...[
                IconButton(
                  onPressed: _currentHandwritingFile!.canGoPreviousPage
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
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // 기본 그리기 도구들
                _buildCompactDrawingTool(Icons.edit, '펜', _selectedTool == '펜'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.highlight, '하이라이터', _selectedTool == '하이라이터'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.cleaning_services, '지우개', _selectedTool == '지우개'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.crop_square, '도형', _selectedTool == '도형'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.circle_outlined, '원형', _selectedTool == '원형'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.remove, '직선', _selectedTool == '직선'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.arrow_forward, '화살표', _selectedTool == '화살표'),
                _buildToolSeparator(),
                _buildCompactDrawingTool(Icons.text_fields, '텍스트', _selectedTool == '텍스트'),
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
                _buildCompactDrawingTool(Icons.palette, '색상', _showColorPicker),
                _buildToolSeparator(),

                // 기본 색상 옵션들
                _buildCompactColorOption(Colors.black, _selectedColor == Colors.black),
                _buildCompactColorOption(Colors.red, _selectedColor == Colors.red),
                _buildCompactColorOption(Colors.blue, _selectedColor == Colors.blue),
                _buildCompactColorOption(Colors.green, _selectedColor == Colors.green),
                _buildCompactColorOption(Colors.yellow, _selectedColor == Colors.yellow),
                _buildCompactColorOption(Colors.orange, _selectedColor == Colors.orange),
                _buildCompactColorOption(Colors.purple, _selectedColor == Colors.purple),
                _buildCompactColorOption(Colors.brown, _selectedColor == Colors.brown),
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
                  _buildCompactColorOption(Colors.pink, _selectedColor == Colors.pink),
                  _buildCompactColorOption(Colors.indigo, _selectedColor == Colors.indigo),
                  _buildCompactColorOption(Colors.teal, _selectedColor == Colors.teal),
                  _buildCompactColorOption(Colors.lime, _selectedColor == Colors.lime),
                  _buildCompactColorOption(Colors.amber, _selectedColor == Colors.amber),
                  _buildCompactColorOption(Colors.deepOrange, _selectedColor == Colors.deepOrange),
                  _buildCompactColorOption(Colors.grey, _selectedColor == Colors.grey),
                  _buildCompactColorOption(Colors.blueGrey, _selectedColor == Colors.blueGrey),
                  _buildCompactColorOption(Colors.lightBlue, _selectedColor == Colors.lightBlue),
                  _buildCompactColorOption(Colors.lightGreen, _selectedColor == Colors.lightGreen),
                  _buildCompactColorOption(Colors.deepPurple, _selectedColor == Colors.deepPurple),
                  _buildCompactColorOption(Colors.cyan, _selectedColor == Colors.cyan),
                  _buildCompactColorOption(Colors.white, _selectedColor == Colors.white),
                  _buildCompactColorOption(Colors.black87, _selectedColor == Colors.black87),
                  _buildCompactColorOption(Colors.black54, _selectedColor == Colors.black54),
                  _buildCompactColorOption(Colors.black38, _selectedColor == Colors.black38),
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
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${_currentPdfPage + 1}/${_pdfPages!.length}'),
                AppSpacing.horizontalSpaceS,
                IconButton(
                  onPressed: _currentPdfPage > 0 ? () async {
                    setState(() {
                      _currentPdfPage--;
                    });
                    await _setBackgroundFromBytes(_pdfPages![_currentPdfPage]);
                  } : null,
                  icon: const Icon(Icons.navigate_before),
                ),
                IconButton(
                  onPressed: _currentPdfPage < _pdfPages!.length - 1 ? () async {
                    setState(() {
                      _currentPdfPage++;
                    });
                    await _setBackgroundFromBytes(_pdfPages![_currentPdfPage]);
                  } : null,
                  icon: const Icon(Icons.navigate_next),
                ),
              ],
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
    // UI를 즉시 편집 모드로 전환
    setState(() {
      _currentHandwritingFile = file;
      _isEditing = true;
    });

    // 이미지 로딩을 비동기로 처리하여 UI 블로킹 방지
    _loadHandwritingImageAsync(file);
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

  Future<void> _saveCurrentPageDrawing() async {
    if (_currentHandwritingFile != null && _painterController != null) {
      try {
        // 고해상도 렌더링을 위한 크기 계산
        Size renderSize;
        if (_backgroundImageOriginalSize != null) {
          // 배경 이미지가 있는 경우 원본 크기 사용
          renderSize = _backgroundImageOriginalSize!;
          print('DEBUG: 배경 이미지 원본 크기로 렌더링 - ${renderSize.width}x${renderSize.height}');
        } else {
          // 배경 이미지가 없는 경우 고해상도 사용 (비율 유지)
          final aspectRatio = _backgroundImageAspectRatio ?? 1.414; // A4 비율 기본값
          const double targetWidth = 1200; // 고해상도
          final double targetHeight = targetWidth / aspectRatio;
          renderSize = Size(targetWidth, targetHeight);
          print('DEBUG: 고해상도로 렌더링 - ${renderSize.width}x${renderSize.height}');
        }

        final ui.Image renderedImage = await _painterController!.renderImage(renderSize);
        final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();

          // 현재 페이지의 이미지를 직접 파일로 저장
          final directory = await getApplicationDocumentsDirectory();
          final littenDir = Directory('${directory.path}/litten_${_currentHandwritingFile!.littenId}');

          String fileName;
          if (_currentHandwritingFile!.isMultiPage && _currentHandwritingFile!.pageImagePaths.isNotEmpty) {
            // 다중 페이지인 경우 현재 페이지 파일명 사용
            if (_currentHandwritingFile!.currentPageIndex < _currentHandwritingFile!.pageImagePaths.length) {
              fileName = _currentHandwritingFile!.pageImagePaths[_currentHandwritingFile!.currentPageIndex];
            } else {
              fileName = '${_currentHandwritingFile!.id}_page_${_currentHandwritingFile!.currentPageIndex + 1}.png';
            }

            // 파일명이 실제 파일명이 아닌 경우 변환
            if (!fileName.contains('_page_')) {
              fileName = '${_currentHandwritingFile!.id}_page_${_currentHandwritingFile!.currentPageIndex + 1}.png';
            }
          } else {
            // 단일 페이지인 경우
            fileName = '${_currentHandwritingFile!.id}.png';
          }

          final pageFile = File('${littenDir.path}/$fileName');
          await pageFile.writeAsBytes(pngBytes);

          print('DEBUG: 현재 페이지 필기 내용 저장 완료 - ${_currentHandwritingFile!.pageInfo}, 파일: $fileName');
        }
      } catch (e) {
        print('ERROR: 페이지 필기 내용 저장 실패 - $e');
      }
    }
  }
  
  Future<void> _loadHandwritingImage(HandwritingFile file) async {
    try {
      print('디버그: 필기 이미지 로드 시작 - ${file.displayTitle} ${file.pageInfo}');

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
          print('디버그: 다중 페이지 - 페이지 ${file.currentPageIndex + 1} 파일 로드: $fileName');
        } else {
          // 기존 가상 경로 형태인 경우 새 파일명 구조로 변환
          final pageNumber = file.currentPageIndex + 1;
          fileName = '${file.id}_page_$pageNumber.png';
          targetPath = '${littenDir.path}/$fileName';
          print('디버그: 다중 페이지 - 페이지 $pageNumber 파일 로드 (변환됨): $fileName');
        }
      } else {
        // 단일 페이지인 경우 기존 방식 사용
        fileName = '${file.id}.png';
        targetPath = '${littenDir.path}/$fileName';
        print('디버그: 단일 페이지 파일 로드: $fileName');
      }

      final imageFile = File(targetPath);

      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();

        // 캔버스를 클리어
        _painterController.clearDrawables();

        // 파일에 저장된 비율 정보를 먼저 복원
        if (file.aspectRatio != null) {
          _backgroundImageAspectRatio = file.aspectRatio;
          print('DEBUG: 파일 저장된 비율 정보 우선 적용 - ${file.aspectRatio}');
        }

        // UI 업데이트로 _canvasSize 계산
        setState(() {});

        // 다음 프레임에서 저장된 이미지를 로드해서 표시 (배경 + 필기 내역이 포함된 이미지)
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _loadSavedDrawingImage(imageBytes, file);
          print('디버그: 필기 이미지 로드 완료 - ${file.displayTitle} ${file.pageInfo}');
        });
      } else {
        print('디버그: 저장된 이미지 파일이 없음 - $targetPath');

        // 파일이 없는 경우 캔버스를 클리어하고 비율 정보만 복원
        _painterController.clearDrawables();
        if (file.aspectRatio != null) {
          _backgroundImageAspectRatio = file.aspectRatio;
          setState(() {}); // UI 업데이트
          print('DEBUG: 파일 저장된 비율 정보 복원 - ${file.aspectRatio}');
        }
      }
    } catch (e) {
      print('에러: 필기 이미지 로드 실패 - $e');
    }
  }

  Future<void> _loadSavedDrawingImage(Uint8List imageBytes, HandwritingFile file) async {
    try {
      // Uint8List를 ui.Image로 변환
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final uiImage = frameInfo.image;

      // 원본 이미지 크기 정보 및 비율 계산
      print('DEBUG: 배경 이미지 원본 크기 - 너비: ${uiImage.width}, 높이: ${uiImage.height}');

      // 이미지 비율과 원본 크기 저장
      if (uiImage.width > 0 && uiImage.height > 0) {
        _backgroundImageAspectRatio = uiImage.width / uiImage.height;
        _backgroundImageOriginalSize = Size(uiImage.width.toDouble(), uiImage.height.toDouble());
        print('DEBUG: 저장된 이미지 정보 - 비율: $_backgroundImageAspectRatio, 크기: ${uiImage.width}x${uiImage.height}');
      } else if (file.aspectRatio != null) {
        _backgroundImageAspectRatio = file.aspectRatio;
        print('DEBUG: 파일 저장된 비율 사용 - ${file.aspectRatio}');
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
        await littenService.removeTextFileFromLitten(selectedLitten.id, file.id);
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
        await storage.saveHandwritingFiles(selectedLitten.id, _handwritingFiles);
        
        // 리튼에서 파일 제거
        final littenService = LittenService();
        await littenService.removeHandwritingFileFromLitten(selectedLitten.id, file.id);
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
          content: htmlContent.isEmpty ? '<p><br></p>' : htmlContent, // 빈 내용일 때 기본 HTML 추가
        );
        
        // 파일 목록에 추가 또는 업데이트
        final existingIndex = _textFiles.indexWhere((f) => f.id == updatedFile.id);
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
            await littenService.addTextFileToLitten(selectedLitten.id, updatedFile.id);
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
            SnackBar(
              content: Text('저장 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveCurrentHandwritingFile() async {
    if (_currentHandwritingFile != null) {
      final String fileTitle = _currentHandwritingFile!.displayTitle;
      try {
        print('디버그: 필기 파일 저장 시작 - $fileTitle ${_currentHandwritingFile!.pageInfo}');

        // 다중 페이지인 경우 현재 페이지만 저장
        await _saveCurrentPageDrawing();

        // 파일 목록에서 현재 파일의 페이지 정보 업데이트 (비율 정보 포함)
        final currentAspectRatio = _getCanvasAspectRatio();
        final updatedFile = _currentHandwritingFile!.copyWith(
          aspectRatio: currentAspectRatio,
        );
        print('DEBUG: 필기 파일 저장 - 비율 정보 업데이트: $currentAspectRatio');
        final existingIndex = _handwritingFiles.indexWhere((f) => f.id == updatedFile.id);

        // appState를 미리 가져옴
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final selectedLitten = appState.selectedLitten;

        if (existingIndex >= 0) {
          _handwritingFiles[existingIndex] = updatedFile;
          print('디버그: 기존 필기 파일 페이지 정보 업데이트됨 - ${updatedFile.displayTitle} ${updatedFile.pageInfo}');
        } else {
          // 새로운 파일인 경우 목록에 추가
          _handwritingFiles.add(updatedFile);
          print('디버그: 새로운 필기 파일 목록에 추가됨 - ${updatedFile.displayTitle} ${updatedFile.pageInfo}');

          // 리튼에 필기 파일 추가
          if (selectedLitten != null) {
            final littenService = LittenService();
            await littenService.addHandwritingFileToLitten(selectedLitten.id, updatedFile.id);
          }
        }

        // SharedPreferences에 파일 목록 저장

        if (selectedLitten != null) {
          final storage = FileStorageService.instance;
          await storage.saveHandwritingFiles(selectedLitten.id, _handwritingFiles);
        }

        print('디버그: 필기 파일 저장 완료 - $fileTitle ${_currentHandwritingFile!.pageInfo}');

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
}

enum WritingMode {
  text,
  handwriting,
}