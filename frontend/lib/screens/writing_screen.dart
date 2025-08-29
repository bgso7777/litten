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
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HtmlEditorController _htmlController;
  late PainterController _painterController;
  WritingMode _currentMode = WritingMode.text;
  
  // 필기 모드 관련 상태
  Color _selectedColor = Colors.black;
  double _strokeWidth = 2.0;
  List<Uint8List>? _pdfPages;
  int _currentPdfPage = 0;
  String? _backgroundImagePath;
  String _selectedTool = '펜';

  @override
  void initState() {
    super.initState();
    _htmlController = HtmlEditorController();
    _painterController = PainterController();
    
    // 초기 펜 모드 설정
    _painterController.freeStyleMode = FreeStyleMode.draw;
    _painterController.freeStyleStrokeWidth = _strokeWidth;
    _painterController.freeStyleColor = _selectedColor;
    
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentMode.index) {
        setState(() {
          _currentMode = WritingMode.values[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            title: '리튼을 선택해주세요',
            description: '쓰기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
            actionText: '홈으로 이동',
            onAction: () => appState.changeTabIndex(0),
          );
        }

        return Column(
          children: [
            // 음성-쓰기 동기화 상태 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade100),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, color: Colors.blue.shade600, size: 16),
                  AppSpacing.horizontalSpaceS,
                  Text(
                    '음성 동기화 준비됨',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '00:00',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // 모드 선택 탭
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.text_fields),
                    text: l10n?.textWriting ?? '텍스트 쓰기',
                  ),
                  Tab(
                    icon: const Icon(Icons.draw),
                    text: l10n?.handwriting ?? '필기',
                  ),
                ],
              ),
            ),
            // 콘텐츠 영역
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTextWritingMode(),
                  _buildHandwritingMode(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextWritingMode() {
    return Column(
      children: [
        // HTML 에디터
        Expanded(
          child: HtmlEditor(
            controller: _htmlController,
            htmlEditorOptions: HtmlEditorOptions(
              hint: '여기에 텍스트를 입력하세요...\n\n🎙️ 음성 동기화 마커를 사용할 수 있습니다.',
              shouldEnsureVisible: true,
              initialText: "",
              adjustHeightForKeyboard: true,
              darkMode: Theme.of(context).brightness == Brightness.dark,
              autoAdjustHeight: false,
            ),
            htmlToolbarOptions: const HtmlToolbarOptions(
              toolbarPosition: ToolbarPosition.aboveEditor,
              toolbarType: ToolbarType.nativeExpandable,
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
        // 저장 버튼
        Container(
          padding: AppSpacing.paddingL,
          child: ElevatedButton(
            onPressed: () async {
              final htmlText = await _htmlController.getText();
              if (htmlText.isNotEmpty) {
                _saveTextContent(htmlText);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('텍스트가 저장되었습니다.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('저장'),
          ),
        ),
      ],
    );
  }

  Widget _buildHandwritingMode() {
    return Column(
      children: [
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
                    // 새 페이지를 배경으로 설정
                    await _setBackgroundFromBytes(_pdfPages![_currentPdfPage]);
                    print('DEBUG: PDF 페이지 변경 - ${_currentPdfPage + 1}/${_pdfPages!.length}');
                  } : null,
                  icon: const Icon(Icons.navigate_before),
                ),
                IconButton(
                  onPressed: _currentPdfPage < _pdfPages!.length - 1 ? () async {
                    setState(() {
                      _currentPdfPage++;
                    });
                    // 새 페이지를 배경으로 설정
                    await _setBackgroundFromBytes(_pdfPages![_currentPdfPage]);
                    print('DEBUG: PDF 페이지 변경 - ${_currentPdfPage + 1}/${_pdfPages!.length}');
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
                color: Colors.black.withOpacity(0.1),
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

  Widget _buildPainterWidget() {
    return Container(
      color: Colors.white,
      child: FlutterPainter(
        controller: _painterController,
      ),
    );
  }

  Future<void> _saveTextContent(String htmlContent) async {
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;
      
      if (selectedLitten != null) {
        // TODO: 실제 파일 저장 로직 구현
        // 현재는 시뮬레이션으로 처리
        print('DEBUG: 텍스트 파일 저장 - Litten: ${selectedLitten.title}');
        print('DEBUG: HTML 콘텐츠 길이: ${htmlContent.length}');
        print('DEBUG: HTML 콘텐츠 미리보기: ${htmlContent.substring(0, htmlContent.length > 100 ? 100 : htmlContent.length)}...');
        
        // 향후 TextFile 모델에 저장하는 로직으로 교체 예정
      }
    } catch (e) {
      print('ERROR: 텍스트 저장 실패 - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('텍스트 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
}

enum WritingMode {
  text,
  handwriting,
}