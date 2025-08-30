import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:pdf_render/pdf_render.dart';  // 임시 비활성화
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen>
    with SingleTickerProviderStateMixin {
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
  
  // 편집 상태
  TextFile? _currentTextFile;
  HandwritingFile? _currentHandwritingFile;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _htmlController = HtmlEditorController();
    _painterController = PainterController();
    
    // 초기 펜 모드 설정
    _painterController.freeStyleMode = FreeStyleMode.draw;
    _painterController.freeStyleStrokeWidth = _strokeWidth;
    _painterController.freeStyleColor = _selectedColor;
    
    _loadFiles();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
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
        // TODO: 실제 파일 로드 로직 구현
        // 현재는 기존 파일 목록을 유지 (파일이 사라지지 않도록)
        // 실제 구현 시에는 디스크에서 파일을 로드해야 함
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
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 텍스트 파일 섹션
                          if (_textFiles.isNotEmpty) ...[
                            Padding(
                              padding: AppSpacing.paddingM,
                              child: Row(
                                children: [
                                  Icon(Icons.text_fields, size: 20, color: Theme.of(context).primaryColor),
                                  AppSpacing.horizontalSpaceS,
                                  Text(
                                    '텍스트 파일 (${_textFiles.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._textFiles.map((file) => _buildTextFileItem(file)),
                          ],
                          // 필기 파일 섹션
                          if (_handwritingFiles.isNotEmpty) ...[
                            Padding(
                              padding: AppSpacing.paddingM,
                              child: Row(
                                children: [
                                  Icon(Icons.draw, size: 20, color: Theme.of(context).primaryColor),
                                  AppSpacing.horizontalSpaceS,
                                  Text(
                                    '필기 파일 (${_handwritingFiles.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._handwritingFiles.map((file) => _buildHandwritingFileItem(file)),
                          ],
                        ],
                      ),
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
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createNewTextFile,
                  icon: const Icon(Icons.text_fields),
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
        ),
      ],
    );
  }

  void _createNewTextFile() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;
    
    if (selectedLitten != null) {
      // 현재 시간 기반 제목 생성
      final now = DateTime.now();
      final defaultTitle = '텍스트${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
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
      final defaultTitle = '필기${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
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
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        print('DEBUG: PDF 파일 선택됨 - ${result.files.single.name}');
        
        final pdfData = result.files.single.bytes!;
        // final document = await PdfDocument.openData(pdfData);  // PDF 기능 임시 비활성화
        throw UnsupportedError('PDF 기능은 현재 비활성화되었습니다.');
        /*
        print('DEBUG: PDF 문서 열기 성공 - 총 ${document.pageCount}페이지');
        
        List<Uint8List> pages = [];
        
        // 모든 페이지를 Uint8List로 변환
        for (int i = 0; i < document.pageCount; i++) {
          final page = await document.getPage(i + 1);
          final pageImage = await page.render(
            width: (page.width * 2).toInt(), // 해상도 2배로 향상
            height: (page.height * 2).toInt(),
          );
          
          // PdfPageImage를 직접 사용하여 ui.Image 생성
          await pageImage.createImageIfNotAvailable();
          final uiImage = pageImage.imageIfAvailable;
          
          if (uiImage != null) {
            // ui.Image를 PNG bytes로 변환
            final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
            final imageBytes = byteData!.buffer.asUint8List();
            pages.add(imageBytes);
            print('DEBUG: 페이지 ${i + 1} 렌더링 완료');
          }
        }
        */
        
        // PDF 기능 임시 비활성화 - 대체 로직
        List<Uint8List> pages = [];
        print('DEBUG: PDF 기능이 임시 비활성화되었습니다.');
        
        // 첫 번째 페이지를 배경으로 설정
        if (pages.isNotEmpty) {
          await _setBackgroundFromBytes(pages.first);
        }
        
        setState(() {
          _pdfPages = pages;
          _currentPdfPage = 0;
          _backgroundImagePath = null;
        });
        
        print('DEBUG: PDF 기능 임시 비활성화');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF 기능은 현재 비활성화되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: PDF 로드 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF 파일 로드에 실패했습니다.'),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
          // 자유 그리기 모드 - FreeStyleDrawable 추가 설정
          _painterController.freeStyleMode = FreeStyleMode.draw;
          _painterController.freeStyleStrokeWidth = _strokeWidth;
          _painterController.freeStyleColor = _selectedColor;
          print('DEBUG: 펜 모드 설정 - 색상: $_selectedColor, 두께: $_strokeWidth');
          break;
        case '하이라이터':
          // 하이라이터 모드
          _painterController.freeStyleMode = FreeStyleMode.draw;
          _painterController.freeStyleStrokeWidth = _strokeWidth * 3;
          _painterController.freeStyleColor = _selectedColor.withOpacity(0.5);
          print('DEBUG: 하이라이터 모드 설정');
          break;
        case '지우개':
          // 지우개 모드
          _painterController.freeStyleMode = FreeStyleMode.erase;
          _painterController.freeStyleStrokeWidth = _strokeWidth * 4;
          print('DEBUG: 지우개 모드 설정');
          break;
        case '도형':
          // 도형 그리기 모드 - ShapeFactory 설정
          _painterController.shapeFactory = RectangleFactory();
          print('DEBUG: 도형 모드 설정');
          break;
        case '초기화':
          _painterController.clearDrawables();
          print('DEBUG: 캔버스 초기화');
          break;
      }
    });
    
    print('DEBUG: 그리기 도구 변경됨 - $tool');
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
          _painterController.freeStyleColor = _selectedColor.withOpacity(0.5);
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
          child: Icon(Icons.text_fields, color: Theme.of(context).primaryColor),
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
              autoAdjustHeight: false,
            ),
            htmlToolbarOptions: const HtmlToolbarOptions(
              toolbarPosition: ToolbarPosition.aboveEditor,
              toolbarType: ToolbarType.nativeGrid,
              defaultToolbarButtons: [
                StyleButtons(style: false),
                FontSettingButtons(
                  fontName: false,
                  fontSize: true,
                  fontSizeUnit: false,
                ),
                FontButtons(
                  bold: true,
                  italic: true,
                  underline: true,
                  clearAll: false,
                  strikethrough: false,
                  subscript: false,
                  superscript: false,
                ),
                ColorButtons(
                  foregroundColor: true,
                  highlightColor: true,
                ),
                ParagraphButtons(
                  textDirection: false,
                  lineHeight: false,
                  caseConverter: false,
                  alignLeft: true,
                  alignCenter: true,
                  alignRight: true,
                  alignJustify: false,
                  decreaseIndent: false,
                  increaseIndent: false,
                ),
                ListButtons(
                  ul: true,
                  ol: true,
                  listStyles: false,
                ),
                InsertButtons(
                  link: true,
                  picture: false,
                  audio: false,
                  video: false,
                  otherFile: false,
                  table: false,
                  hr: true,
                ),
                OtherButtons(
                  fullscreen: false,
                  codeview: false,
                  undo: true,
                  redo: true,
                  help: false,
                ),
              ],
            ),
            otherOptions: const OtherOptions(
              height: 300,
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
        // 파일 로드 버튼들
        Container(
          padding: AppSpacing.paddingM,
          child: Row(
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
        // 필기 도구 패널
        Container(
          height: 120,
          padding: AppSpacing.paddingL,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 도구바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDrawingTool(Icons.edit, '펜', _selectedTool == '펜'),
                  _buildDrawingTool(Icons.highlight, '하이라이터', _selectedTool == '하이라이터'),
                  _buildDrawingTool(Icons.cleaning_services, '지우개', _selectedTool == '지우개'),
                  _buildDrawingTool(Icons.crop_square, '도형', _selectedTool == '도형'),
                  _buildDrawingTool(Icons.clear, '초기화', false),
                ],
              ),
              AppSpacing.verticalSpaceM,
              // 색상 팔레트
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildColorOption(Colors.black, _selectedColor == Colors.black),
                  _buildColorOption(Colors.red, _selectedColor == Colors.red),
                  _buildColorOption(Colors.blue, _selectedColor == Colors.blue),
                  _buildColorOption(Colors.green, _selectedColor == Colors.green),
                  _buildColorOption(Colors.yellow, _selectedColor == Colors.yellow),
                  _buildColorOption(Colors.orange, _selectedColor == Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _loadPdfForNewFile() async {
    await _loadPdfFile();
    if (_pdfPages != null && _pdfPages!.isNotEmpty) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;
      
      if (selectedLitten != null) {
        final newHandwritingFile = HandwritingFile(
          littenId: selectedLitten.id,
          imagePath: '/temp/pdf_handwriting.png',
          type: HandwritingType.pdfConvert,
        );
        
        setState(() {
          _currentHandwritingFile = newHandwritingFile;
          _isEditing = true;
        });
      }
    }
  }

  void _editTextFile(TextFile file) {
    setState(() {
      _currentTextFile = file;
      _isEditing = true;
    });
    
    // HTML 컨텐츠 로드
    _htmlController.setText(file.content);
  }

  void _editHandwritingFile(HandwritingFile file) {
    setState(() {
      _currentHandwritingFile = file;
      _isEditing = true;
    });
    
    // TODO: 저장된 필기 데이터 로드
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
      
      // TODO: 실제 파일 시스템에서 파일 삭제 로직 구현
      // 현재는 메모리에서만 제거
      
      setState(() {
        _textFiles.removeWhere((f) => f.id == file.id);
      });
      
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
      
      // TODO: 실제 파일 시스템에서 이미지 파일 삭제 로직 구현
      // 현재는 메모리에서만 제거
      
      setState(() {
        _handwritingFiles.removeWhere((f) => f.id == file.id);
      });
      
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
        
        // TODO: 실제 파일 시스템에 저장하는 로직 구현
        // 현재는 메모리에만 저장
        
        setState(() {
          _isEditing = false;
          _currentTextFile = null;
        });
        
        print('디버그: 텍스트 파일 저장 완료 - 총 ${_textFiles.length}개 파일');
        
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
      try {
        print('디버그: 필기 파일 저장 시작 - ${_currentHandwritingFile!.displayTitle}');
        
        // TODO: 실제 이미지 저장 로직 구현
        // 현재는 메모리에만 저장, 실제로는 캔버스를 이미지로 변환하여 파일로 저장해야 함
        
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
        
        setState(() {
          _isEditing = false;
          _currentHandwritingFile = null;
        });
        
        print('디버그: 필기 파일 저장 완료 - 총 ${_handwritingFiles.length}개 파일');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${updatedFile.displayTitle} 파일이 저장되었습니다.'),
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