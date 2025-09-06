import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../utils/responsive_utils.dart';
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
  String? _backgroundImagePath;
  String _selectedTool = '펜';
  bool _showAdvancedTools = false;
  bool _showColorPicker = false;
  bool _showTextToolbar = false; // 텍스트 툴바 표시 상태
  bool _showDrawingToolbar = false; // 필기 툴바 표시 상태
  
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
    
    // 초기 펜 모드 설정
    _painterController.freeStyleMode = FreeStyleMode.draw;
    _painterController.freeStyleStrokeWidth = _strokeWidth;
    _painterController.freeStyleColor = _selectedColor;
    
    _loadFiles();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포어그라운드로 돌아왔을 때 파일 목록 재로드
    if (state == AppLifecycleState.resumed) {
      _loadFiles();
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
    WidgetsBinding.instance.removeObserver(this);
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;
      
      if (selectedLitten != null) {
        // 실제 파일 로드 로직 구현
        final storage = FileStorageService.instance;
        
        // 텍스트 파일 로드
        final loadedTextFiles = await storage.loadTextFiles(selectedLitten.id);
        
        // 필기 파일 로드
        final loadedHandwritingFiles = await storage.loadHandwritingFiles(selectedLitten.id);
        
        setState(() {
          _textFiles.clear();
          _textFiles.addAll(loadedTextFiles);
          _handwritingFiles.clear();
          _handwritingFiles.addAll(loadedHandwritingFiles);
        });
        
        print('디버그: 파일 목록 로드 완료 - 텍스트: ${_textFiles.length}개, 필기: ${_handwritingFiles.length}개');
      }
    } catch (e) {
      print('에러: 파일 로드 실패 - $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      });
      
      // 새 텍스트 파일이므로 포커스 및 커서 위치 설정
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        _htmlController.setFocus();
        // 새 파일이므로 커서를 1행1열에 위치
        await Future.delayed(const Duration(milliseconds: 200));
        _positionCursorForContent(''); // 빈 내용이므로 1행1열로
      } catch (e) {
        print('새 텍스트 파일 포커스 설정 실패: $e');
      }
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
      );
      
      print('디버그: 새로운 필기 파일 생성 - $defaultTitle');
      
      setState(() {
        _currentHandwritingFile = newHandwritingFile;
        _isEditing = true;
        // 캔버스 초기화
        _painterController.clearDrawables();
      });
    }
  }



  Widget _buildPainterWidget() {
    return Container(
      color: Colors.white,
      child: FlutterPainter(
        controller: _painterController,
      ),
    );
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

  Future<void> _convertPdfToPngAndAddToHandwriting(String pdfPath, String fileName) async {
    try {
      print('DEBUG: PDF를 PNG로 변환 시작 - $fileName');
      
      // PDF 파일을 Uint8List로 읽기
      final pdfFile = File(pdfPath);
      final pdfBytes = await pdfFile.readAsBytes();
      
      // printing 패키지를 사용해서 PDF를 이미지로 변환
      final List<Uint8List> images = [];
      await for (final page in Printing.raster(
        pdfBytes,
        pages: [0], // 첫 번째 페이지만 변환 (추후 다중 페이지 지원 가능)
        dpi: 300, // 고화질 변환
      )) {
        images.add(await page.toPng());
      }
      
      if (images.isNotEmpty) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final selectedLitten = appState.selectedLitten;
        
        if (selectedLitten != null) {
          // PDF 이름에서 확장자 제거하여 필기 파일 제목으로 사용
          final titleWithoutExtension = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
          
          // 새로운 필기 파일 생성
          final newHandwritingFile = HandwritingFile(
            littenId: selectedLitten.id,
            title: titleWithoutExtension, // PDF 이름을 제목으로 사용
            imagePath: '/temp/pdf_converted.png',
            type: HandwritingType.pdfConvert,
          );
          
          print('DEBUG: 필기 파일 생성 - 제목: $titleWithoutExtension');
          
          // 이미지를 파일로 저장
          final storage = FileStorageService.instance;
          await storage.saveHandwritingImage(newHandwritingFile, images.first);
          
          // 필기 파일 목록에 추가
          setState(() {
            _handwritingFiles.add(newHandwritingFile);
            _currentHandwritingFile = newHandwritingFile;
            _isEditing = true;
          });
          
          // 필기 파일 목록을 SharedPreferences에 저장
          await storage.saveHandwritingFiles(selectedLitten.id, _handwritingFiles);
          
          // 리튼에 필기 파일 추가
          final littenService = LittenService();
          await littenService.addHandwritingFileToLitten(selectedLitten.id, newHandwritingFile.id);
          
          // 변환된 이미지를 캔버스 배경으로 설정
          await _setBackgroundFromBytes(images.first);
          
          print('DEBUG: PDF to PNG 변환 및 필기 파일 추가 완료');
          
          // 성공 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$titleWithoutExtension이(가) 필기 파일로 추가되었습니다.'),
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
        }
      } else {
        print('ERROR: PDF 변환 결과 이미지가 없음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF 변환에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: PDF to PNG 변환 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF 변환 실패: $e'),
            backgroundColor: Colors.red,
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
      
      // 배경으로 설정
      _painterController.background = uiImage.backgroundDrawable;
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
          // TODO: flutter_painter_v2에서 줌 기능 구현
          print('DEBUG: 줌인 - 현재 라이브러리에서 지원되지 않음');
          break;
        case '줌아웃':
          // TODO: flutter_painter_v2에서 줌 기능 구현
          print('DEBUG: 줌아웃 - 현재 라이브러리에서 지원되지 않음');
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

  void _showTextInput() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('텍스트 입력'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '텍스트를 입력하세요',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  _addTextToCanvas(text);
                }
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _addTextToCanvas(String text) {
    // flutter_painter_v2에서 텍스트 추가하는 방법은 다를 수 있음
    // 임시로 간단한 구현
    try {
      // PainterController에 텍스트 관련 메소드가 있는지 확인 필요
      print('텍스트 추가: $text');
      // TODO: flutter_painter_v2의 올바른 텍스트 추가 방법으로 수정 필요
    } catch (e) {
      print('텍스트 추가 실패: $e');
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
            Text(
              file.isFromPdf ? 'PDF에서 변환됨' : '직접 작성',
              style: TextStyle(color: Colors.grey.shade600),
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
                onPressed: () {
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
                ),
              ),
              TextButton(
                onPressed: _saveCurrentTextFile,
                child: Text(l10n?.save ?? '저장'),
              ),
            ],
          ),
        ),
        // 텍스트 툴바 토글 버튼
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showTextToolbar = !_showTextToolbar;
                  });
                },
                icon: Icon(
                  _showTextToolbar ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                ),
                label: Text(
                  _showTextToolbar ? '툴바 숨기기' : '툴바 보기',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // HTML 에디터
        Expanded(
          child: HtmlEditor(
            controller: _htmlController,
            htmlEditorOptions: HtmlEditorOptions(
              hint: '여기에 텍스트를 입력하세요...\n\n🎙️ 음성 동기화 마커를 사용할 수 있습니다.',
              shouldEnsureVisible: true,
              initialText: _currentTextFile?.content ?? '',
              adjustHeightForKeyboard: true,
              darkMode: Theme.of(context).brightness == Brightness.dark,
              autoAdjustHeight: false, // 자동 높이 조정 비활성화하여 최대 크기 사용
              spellCheck: true,
              characterLimit: null, // 글자 수 제한 없음
            ),
            htmlToolbarOptions: HtmlToolbarOptions(
              toolbarPosition: ToolbarPosition.aboveEditor,
              toolbarType: ToolbarType.nativeExpandable,
              toolbarItemHeight: 40,
              buttonColor: Theme.of(context).primaryColor,
              buttonSelectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.8),
              buttonBorderColor: Colors.grey.withValues(alpha: 0.3),
              buttonBorderWidth: 1,
              buttonBorderRadius: BorderRadius.circular(8),
              buttonFillColor: Colors.grey.withValues(alpha: 0.1),
              dropdownBackgroundColor: Theme.of(context).cardColor,
              gridViewHorizontalSpacing: 4,
              gridViewVerticalSpacing: 4,
              defaultToolbarButtons: _showTextToolbar ? [
                FontButtons(
                  bold: true,
                  italic: true,
                  underline: true,
                  clearAll: true,
                  strikethrough: false, // 간소화
                  subscript: false, // 간소화
                  superscript: false, // 간소화
                ),
                ColorButtons(
                  foregroundColor: true,
                  highlightColor: true,
                ),
                ParagraphButtons(
                  textDirection: false, // 간소화
                  lineHeight: true,
                  caseConverter: false, // 간소화
                  alignLeft: true,
                  alignCenter: true,
                  alignRight: true,
                  alignJustify: false, // 간소화
                  decreaseIndent: true,
                  increaseIndent: true,
                ),
                ListButtons(
                  ul: true,
                  ol: true,
                  listStyles: true, // 활성화
                ),
                OtherButtons(
                  fullscreen: true, // 활성화
                  codeview: true, // 활성화
                  undo: true,
                  redo: true,
                  help: true, // 활성화
                ),
              ] : [], // 툴바가 숨겨져 있으면 빈 배열
            ),
            otherOptions: const OtherOptions(),
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
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _currentHandwritingFile = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _currentHandwritingFile?.displayTitle ?? '새 필기',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saveCurrentHandwritingFile,
                child: Text(l10n?.save ?? '저장'),
              ),
            ],
          ),
        ),
        // 필기 도구 패널 토글 버튼
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showDrawingToolbar = !_showDrawingToolbar;
                  });
                },
                icon: Icon(
                  _showDrawingToolbar ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                ),
                label: Text(
                  _showDrawingToolbar ? '도구 숨기기' : '도구 보기',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // 필기 도구 패널 (조건부 표시)
        if (_showDrawingToolbar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
              // 기본 도구바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDrawingTool(Icons.edit, '펜', _selectedTool == '펜'),
                  _buildDrawingTool(Icons.highlight, '하이라이터', _selectedTool == '하이라이터'),
                  _buildDrawingTool(Icons.cleaning_services, '지우개', _selectedTool == '지우개'),
                  _buildDrawingTool(Icons.crop_square, '도형', _selectedTool == '도형'),
                  _buildDrawingTool(Icons.circle_outlined, '원형', _selectedTool == '원형'),
                  _buildDrawingTool(Icons.remove, '직선', _selectedTool == '직선'),
                ],
              ),
              AppSpacing.verticalSpaceXS,
              // 두 번째 도구바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDrawingTool(Icons.arrow_forward, '화살표', _selectedTool == '화살표'),
                  _buildDrawingTool(Icons.text_fields, '텍스트', _selectedTool == '텍스트'),
                  _buildDrawingTool(Icons.undo, '실행취소', false),
                  _buildDrawingTool(Icons.redo, '다시실행', false),
                  _buildDrawingTool(Icons.zoom_in, '줌인', false),
                  _buildDrawingTool(Icons.zoom_out, '줌아웃', false),
                ],
              ),
              AppSpacing.verticalSpaceXS,
              // 세 번째 도구바 (설정)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDrawingTool(Icons.line_weight, '선굵기', false),
                  _buildDrawingTool(Icons.palette, '색상', _showColorPicker),
                  _buildDrawingTool(Icons.clear, '초기화', false),
                  _buildDrawingTool(Icons.expand_more, '고급도구', _showAdvancedTools),
                  Container(width: 20), // 빈 공간 줄임
                  Container(width: 20), // 빈 공간 줄임
                ],
              ),
              if (_showAdvancedTools) ...[
                AppSpacing.verticalSpaceXS,
                // 고급 도구바
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDrawingTool(Icons.architecture, '삼각형', false),
                    _buildDrawingTool(Icons.star_outline, '별모양', false),
                    _buildDrawingTool(Icons.lens_blur, '원점', false),
                    _buildDrawingTool(Icons.timeline, '곡선', false),
                    _buildDrawingTool(Icons.grid_on, '격자', false),
                    _buildDrawingTool(Icons.straighten, '자', false),
                  ],
                ),
              ],
              AppSpacing.verticalSpaceS,
              // 기본 색상 팔레트
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildColorOption(Colors.black, _selectedColor == Colors.black),
                  _buildColorOption(Colors.red, _selectedColor == Colors.red),
                  _buildColorOption(Colors.blue, _selectedColor == Colors.blue),
                  _buildColorOption(Colors.green, _selectedColor == Colors.green),
                  _buildColorOption(Colors.yellow, _selectedColor == Colors.yellow),
                  _buildColorOption(Colors.orange, _selectedColor == Colors.orange),
                  _buildColorOption(Colors.purple, _selectedColor == Colors.purple),
                  _buildColorOption(Colors.brown, _selectedColor == Colors.brown),
                ],
              ),
              if (_showColorPicker) ...[
                AppSpacing.verticalSpaceXS,
                // 확장 색상 팔레트
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildColorOption(Colors.pink, _selectedColor == Colors.pink),
                        _buildColorOption(Colors.indigo, _selectedColor == Colors.indigo),
                        _buildColorOption(Colors.teal, _selectedColor == Colors.teal),
                        _buildColorOption(Colors.lime, _selectedColor == Colors.lime),
                        _buildColorOption(Colors.amber, _selectedColor == Colors.amber),
                        _buildColorOption(Colors.deepOrange, _selectedColor == Colors.deepOrange),
                        _buildColorOption(Colors.grey, _selectedColor == Colors.grey),
                        _buildColorOption(Colors.blueGrey, _selectedColor == Colors.blueGrey),
                      ],
                    ),
                    AppSpacing.verticalSpaceXS,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildColorOption(Colors.lightBlue, _selectedColor == Colors.lightBlue),
                        _buildColorOption(Colors.lightGreen, _selectedColor == Colors.lightGreen),
                        _buildColorOption(Colors.deepPurple, _selectedColor == Colors.deepPurple),
                        _buildColorOption(Colors.cyan, _selectedColor == Colors.cyan),
                        _buildColorOption(Colors.white, _selectedColor == Colors.white),
                        _buildColorOption(Colors.black87, _selectedColor == Colors.black87),
                        _buildColorOption(Colors.black54, _selectedColor == Colors.black54),
                        _buildColorOption(Colors.black38, _selectedColor == Colors.black38),
                      ],
                    ),
                  ],
                ),
              ],
              AppSpacing.verticalSpaceXS,
              // 현재 선택된 도구와 설정 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_selectedTool | ${_strokeWidth.round()}px',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 캔버스 영역
        Expanded(
          child: Container(
            margin: AppSpacing.paddingL,
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
        // 파일 로드 버튼들 (하단으로 이동)
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
                  ElevatedButton.icon(
                    onPressed: _loadPdfFile,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF 로드'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 36),
                    ),
                  ),
                  AppSpacing.horizontalSpaceM,
                  ElevatedButton.icon(
                    onPressed: _loadImageFile,
                    icon: const Icon(Icons.image),
                    label: const Text('이미지 로드'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 36),
                    ),
                  ),
                  const Spacer(),
                  if (_pdfPages != null && _pdfPages!.length > 1) ...[
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
    });
    
    // HTML 에디터가 로딩될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      // HTML 컨텐츠 로드
      _htmlController.setText(file.content);
      
      // 에디터에 포커스 설정 및 커서를 1행1열로 위치
      await Future.delayed(const Duration(milliseconds: 300));
      _htmlController.setFocus();
      
      // 파일 내용에 따라 커서 위치 설정
      await Future.delayed(const Duration(milliseconds: 200));
      _positionCursorForContent(file.content);
      
    } catch (e) {
      print('HTML 에디터 로딩 에러: $e');
      // 재시도
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        _htmlController.setText(file.content);
        _htmlController.setFocus();
      } catch (e2) {
        print('HTML 에디터 로딩 재시도 실패: $e2');
      }
    }
  }

  void _editHandwritingFile(HandwritingFile file) async {
    setState(() {
      _currentHandwritingFile = file;
      _isEditing = true;
    });
    
    // 저장된 필기 이미지 로드
    await _loadHandwritingImage(file);
  }
  
  Future<void> _loadHandwritingImage(HandwritingFile file) async {
    try {
      print('디버그: 필기 이미지 로드 시작 - ${file.displayTitle}');
      
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/litten_${file.littenId}');
      final fileName = '${file.id}.png';
      final filePath = '${littenDir.path}/$fileName';
      
      final imageFile = File(filePath);
      
      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        final image = await decodeImageFromList(imageBytes);
        
        // 캔버스를 클리어하고 이미지를 배경으로 설정
        _painterController.clearDrawables();
        await _setBackgroundFromBytes(imageBytes);
        
        print('디버그: 필기 이미지 로드 완료 - ${file.displayTitle}');
      } else {
        print('디버그: 저장된 이미지 파일이 없음 - $filePath');
      }
    } catch (e) {
      print('에러: 필기 이미지 로드 실패 - $e');
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
        
        final htmlContent = await _htmlController.getText();
        print('디버그: HTML 내용 로드됨 - 길이: ${htmlContent.length}자');
        
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
      final String fileTitle = _currentHandwritingFile!.displayTitle; // 파일 제목을 미리 저장
      try {
        print('디버그: 필기 파일 저장 시작 - $fileTitle');
        
        // 캔버스를 이미지로 변환
        final image = await _painterController.renderImage(Size(800, 600));
        
        if (image != null) {
          // ui.Image를 PNG bytes로 변환
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final imageBytes = byteData?.buffer.asUint8List();
          
          if (imageBytes != null) {
            // 업데이트된 시간으로 파일 생성
            final updatedFile = _currentHandwritingFile!.copyWith();
            
            // 파일 목록에 추가 또는 업데이트
            final existingIndex = _handwritingFiles.indexWhere((f) => f.id == updatedFile.id);
            if (existingIndex >= 0) {
              _handwritingFiles[existingIndex] = updatedFile;
              print('디버그: 기존 필기 파일 업데이트됨 - ${updatedFile.displayTitle}');
            } else {
              _handwritingFiles.add(updatedFile);
              print('디버그: 새로운 필기 파일 추가됨 - ${updatedFile.displayTitle}');
            }
            
            // 실제 파일 시스템에 저장
            final appState = Provider.of<AppStateProvider>(context, listen: false);
            final selectedLitten = appState.selectedLitten;
            
            if (selectedLitten != null) {
              final storage = FileStorageService.instance;
              
              // 이미지를 파일로 저장
              await storage.saveHandwritingImage(updatedFile, imageBytes);
              
              // 파일 목록을 SharedPreferences에 저장
              await storage.saveHandwritingFiles(selectedLitten.id, _handwritingFiles);
              
              // 리튼의 파일 목록 업데이트
              final littenService = LittenService();
              if (existingIndex >= 0) {
                // 기존 파일 업데이트는 추가 작업 불필요
              } else {
                // 새 파일 추가
                await littenService.addHandwritingFileToLitten(selectedLitten.id, updatedFile.id);
              }
            }
          }
        }
        
        setState(() {
          _isEditing = false;
          _currentHandwritingFile = null;
        });
        
        print('디버그: 필기 파일 저장 완료 - 총 ${_handwritingFiles.length}개 파일');
        
        // 파일 수 배지 업데이트를 위해 AppStateProvider 리플래시
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        await appState.refreshLittens();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fileTitle 파일이 저장되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('에러: 필기 파일 저장 실패 - $e');
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
}

enum WritingMode {
  text,
  handwriting,
}