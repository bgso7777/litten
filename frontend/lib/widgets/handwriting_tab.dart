import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../services/app_state_provider.dart';
import '../models/handwriting_file.dart';
import '../models/litten.dart';
import '../config/app_spacing.dart';
import '../config/app_text_styles.dart';
import '../widgets/empty_state.dart';

class HandwritingTab extends StatefulWidget {
  const HandwritingTab({super.key});

  @override
  State<HandwritingTab> createState() => _HandwritingTabState();
}

class _HandwritingTabState extends State<HandwritingTab> {
  late PainterController _painterController;
  late TransformationController _transformationController;
  List<HandwritingFile> _handwritingFiles = [];
  bool _isLoading = false;
  bool _isEditing = false;
  HandwritingFile? _currentHandwritingFile;

  // 도구 설정
  String _selectedTool = '펜';
  Color _selectedColor = Colors.black;
  double _strokeWidth = 2.0;
  bool _isGestureMode = false;
  bool _isTextInputMode = false;

  // 텍스트 입력 관련
  Offset? _textInputPosition;
  TextEditingController? _canvasTextController;
  FocusNode? _canvasTextFocusNode;

  // 배경 이미지 관련
  double? _backgroundImageAspectRatio;
  Size? _backgroundImageOriginalSize;

  @override
  void initState() {
    super.initState();
    _painterController = PainterController();
    _transformationController = TransformationController();
    _canvasTextController = TextEditingController();
    _canvasTextFocusNode = FocusNode();

    // 초기 펜 모드 설정
    _painterController.freeStyleMode = FreeStyleMode.draw;
    _painterController.freeStyleStrokeWidth = _strokeWidth;
    _painterController.freeStyleColor = _selectedColor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHandwritingFiles();
    });
  }

  @override
  void dispose() {
    _painterController.dispose();
    _transformationController.dispose();
    _canvasTextController?.dispose();
    _canvasTextFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (appState.selectedLitten == null) {
          return const EmptyState(
            icon: Icons.edit_note,
            title: '리튼을 선택해주세요',
            subtitle: '필기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
          );
        }

        if (_isEditing && _currentHandwritingFile != null) {
          return _buildHandwritingEditor();
        }

        return Container(
          color: Colors.blue.shade50,
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  border: Border(
                    bottom: BorderSide(color: Colors.blue.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.gesture,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '필기 (${_handwritingFiles.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _createNewHandwritingFile,
                      icon: Icon(
                        Icons.add,
                        color: Colors.blue.shade700,
                      ),
                      tooltip: '새 필기 작성',
                    ),
                  ],
                ),
              ),
              // 필기 파일 목록
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _handwritingFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.gesture_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '아직 필기된 파일이 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '우상단의 + 버튼을 눌러 시작해보세요',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _handwritingFiles.length,
                            itemBuilder: (context, index) {
                              return _buildHandwritingFileItem(_handwritingFiles[index]);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandwritingEditor() {
    return Stack(
      children: [
        Column(
          children: [
            // 상단 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _exitEditor,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '뒤로 가기',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentHandwritingFile?.displayTitle ?? '새 필기',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _addBackgroundImage,
                    icon: const Icon(Icons.image),
                    tooltip: '배경 이미지 추가',
                  ),
                  IconButton(
                    onPressed: _saveHandwritingFile,
                    icon: const Icon(Icons.save),
                    tooltip: '저장',
                  ),
                ],
              ),
            ),
            // 도구 모음
            _buildToolbar(),
            // 캔버스 영역
            Expanded(
              child: _buildPainterWidget(),
            ),
          ],
        ),
        // 텍스트 입력 오버레이
        if (_isTextInputMode && _textInputPosition != null)
          _buildCanvasTextInput(),
      ],
    );
  }

  Widget _buildToolbar() {
    final tools = [
      {'name': '제스처', 'icon': Icons.pan_tool, 'color': Colors.grey},
      {'name': '펜', 'icon': Icons.edit, 'color': Colors.black},
      {'name': '하이라이터', 'icon': Icons.highlight, 'color': Colors.yellow},
      {'name': '지우개', 'icon': Icons.cleaning_services, 'color': Colors.pink},
      {'name': '도형', 'icon': Icons.crop_square, 'color': Colors.blue},
      {'name': '원형', 'icon': Icons.circle_outlined, 'color': Colors.green},
      {'name': '직선', 'icon': Icons.remove, 'color': Colors.purple},
      {'name': '화살표', 'icon': Icons.arrow_forward, 'color': Colors.orange},
      {'name': '텍스트', 'icon': Icons.text_fields, 'color': Colors.brown},
    ];

    final actions = [
      {'name': '실행취소', 'icon': Icons.undo},
      {'name': '다시실행', 'icon': Icons.redo},
      {'name': '초기화', 'icon': Icons.clear_all},
    ];

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // 도구들
            ...tools.map((tool) => _buildToolButton(
              tool['name'] as String,
              tool['icon'] as IconData,
              tool['color'] as Color,
            )),
            const VerticalDivider(),
            // 액션들
            ...actions.map((action) => _buildActionButton(
              action['name'] as String,
              action['icon'] as IconData,
            )),
            const VerticalDivider(),
            // 색상 선택
            _buildColorPicker(),
            const SizedBox(width: 8),
            // 선 두께
            _buildStrokeWidthSlider(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(String toolName, IconData icon, Color color) {
    final isSelected = _selectedTool == toolName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => _selectTool(toolName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade100 : null,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Colors.blue) : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.grey.shade700,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String actionName, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => _selectTool(actionName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.grey.shade700,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      Colors.black, Colors.red, Colors.blue, Colors.green,
      Colors.yellow, Colors.orange, Colors.purple, Colors.brown,
    ];

    return Row(
      children: colors.map((color) {
        final isSelected = _selectedColor == color;
        return GestureDetector(
          onTap: () => _selectColor(color),
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.grey.shade800 : Colors.grey.shade400,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrokeWidthSlider() {
    return SizedBox(
      width: 100,
      child: Slider(
        value: _strokeWidth,
        min: 1.0,
        max: 20.0,
        divisions: 19,
        onChanged: (value) {
          setState(() {
            _strokeWidth = value;
            _painterController.freeStyleStrokeWidth = value;
          });
        },
      ),
    );
  }

  Widget _buildPainterWidget() {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspectRatio = _getCanvasAspectRatio();
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          double canvasWidth, canvasHeight;
          if (maxWidth / maxHeight > aspectRatio) {
            canvasHeight = maxHeight;
            canvasWidth = canvasHeight * aspectRatio;
          } else {
            canvasWidth = maxWidth;
            canvasHeight = canvasWidth / aspectRatio;
          }

          return Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.1,
              maxScale: 5.0,
              child: Container(
                width: canvasWidth,
                height: canvasHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: Stack(
                  children: [
                    // 캔버스
                    SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: IgnorePointer(
                        ignoring: _isTextInputMode || _isGestureMode,
                        child: FlutterPainter(controller: _painterController),
                      ),
                    ),
                    // 텍스트 입력 전용 제스처 감지 레이어
                    if (_isTextInputMode)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (details) {
                            final canvasPosition = details.localPosition;
                            setState(() {
                              _textInputPosition = canvasPosition;
                            });
                            _showCanvasTextInput();
                          },
                          child: Container(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCanvasTextInput() {
    return Positioned(
      left: _textInputPosition!.dx,
      top: _textInputPosition!.dy,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 200,
          maxWidth: 300,
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _canvasTextController,
                  focusNode: _canvasTextFocusNode,
                  decoration: const InputDecoration(
                    hintText: '텍스트를 입력하세요',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 3,
                  onSubmitted: (_) => _confirmTextInput(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelTextInput,
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: _confirmTextInput,
                      child: const Text('확인'),
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

  Widget _buildHandwritingFileItem(HandwritingFile handwritingFile) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.paddingS),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.gesture,
            color: Colors.blue.shade700,
            size: 24,
          ),
        ),
        title: Text(
          handwritingFile.displayTitle,
          style: AppTextStyles.headline3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              timeFormat.format(handwritingFile.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(width: 12),
            Icon(Icons.aspect_ratio, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '${handwritingFile.pageInfo}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editHandwritingFile(handwritingFile),
              icon: Icon(
                Icons.edit,
                color: Colors.blue.shade700,
              ),
              tooltip: '편집',
            ),
            IconButton(
              onPressed: () => _deleteHandwritingFile(handwritingFile),
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
              tooltip: '삭제',
            ),
          ],
        ),
        onTap: () => _editHandwritingFile(handwritingFile),
      ),
    );
  }

  double _getCanvasAspectRatio() {
    if (_currentHandwritingFile?.aspectRatio != null) {
      return _currentHandwritingFile!.aspectRatio!;
    }
    if (_backgroundImageAspectRatio != null) {
      return _backgroundImageAspectRatio!;
    }
    return 4.0 / 3.0; // 기본 비율
  }

  void _selectTool(String tool) {
    setState(() {
      _selectedTool = tool;
      _isTextInputMode = false;
      _isGestureMode = false;
    });

    switch (tool) {
      case '제스처':
        _isGestureMode = true;
        break;
      case '펜':
        _painterController.freeStyleMode = FreeStyleMode.draw;
        _painterController.freeStyleStrokeWidth = _strokeWidth;
        _painterController.freeStyleColor = _selectedColor;
        break;
      case '하이라이터':
        _painterController.freeStyleMode = FreeStyleMode.draw;
        _painterController.freeStyleStrokeWidth = _strokeWidth * 3;
        _painterController.freeStyleColor = _selectedColor.withValues(alpha: 0.5);
        break;
      case '지우개':
        _painterController.freeStyleMode = FreeStyleMode.erase;
        _painterController.freeStyleStrokeWidth = _strokeWidth * 4;
        break;
      case '도형':
        _painterController.shapeFactory = RectangleFactory();
        break;
      case '원형':
        _painterController.shapeFactory = OvalFactory();
        break;
      case '직선':
        _painterController.shapeFactory = LineFactory();
        break;
      case '화살표':
        _painterController.shapeFactory = ArrowFactory();
        break;
      case '텍스트':
        _isTextInputMode = true;
        break;
      case '실행취소':
        _painterController.undo();
        break;
      case '다시실행':
        _painterController.redo();
        break;
      case '초기화':
        _painterController.clearDrawables();
        break;
    }
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;

      switch (_selectedTool) {
        case '펜':
          _painterController.freeStyleColor = _selectedColor;
          break;
        case '하이라이터':
          _painterController.freeStyleColor = _selectedColor.withValues(alpha: 0.5);
          break;
      }
    });
  }

  void _showCanvasTextInput() {
    _canvasTextController!.clear();
    _canvasTextFocusNode!.requestFocus();
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
    });
    _canvasTextController!.clear();
    _canvasTextFocusNode!.unfocus();
  }

  void _addTextToCanvas(String text) {
    if (_textInputPosition != null) {
      _painterController.textSettings = TextSettings(
        textStyle: TextStyle(
          color: _selectedColor,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
      );

      final textDrawable = TextDrawable(
        text: text,
        position: _textInputPosition!,
        style: TextStyle(
          color: _selectedColor,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
      );

      _painterController.addDrawables([textDrawable]);
      setState(() {});
    }
  }

  Future<void> _loadHandwritingFiles() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final handwritingFiles = await _getHandwritingFiles(selectedLitten);
      setState(() {
        _handwritingFiles = handwritingFiles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[HandwritingTab] 필기 파일 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<HandwritingFile>> _getHandwritingFiles(Litten litten) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final handwritingDir = Directory('${directory.path}/littens/${litten.id}/handwriting');

      if (!await handwritingDir.exists()) {
        return [];
      }

      final files = await handwritingDir.list().toList();
      final handwritingFiles = <HandwritingFile>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.png')) {
          final stat = await file.stat();
          final fileName = file.path.split('/').last.replaceAll('.png', '');

          final handwritingFile = HandwritingFile(
            id: stat.modified.millisecondsSinceEpoch.toString(),
            littenId: litten.id,
            title: fileName.startsWith('필기') ? fileName : fileName,
            imagePath: file.path,
            createdAt: stat.modified,
            aspectRatio: 4.0 / 3.0,
          );

          handwritingFiles.add(handwritingFile);
        }
      }

      handwritingFiles.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return handwritingFiles;
    } catch (e) {
      debugPrint('[HandwritingTab] 필기 파일 목록 조회 오류: $e');
      return [];
    }
  }

  Future<void> _createNewHandwritingFile() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    try {
      final now = DateTime.now();
      final fileName = '필기${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final directory = await getApplicationDocumentsDirectory();
      final handwritingDir = Directory('${directory.path}/littens/${selectedLitten.id}/handwriting');
      if (!await handwritingDir.exists()) {
        await handwritingDir.create(recursive: true);
      }
      final filePath = '${handwritingDir.path}/$fileName.png';

      final handwritingFile = HandwritingFile(
        id: now.millisecondsSinceEpoch.toString(),
        littenId: selectedLitten.id,
        title: fileName,
        imagePath: filePath,
        createdAt: now,
        aspectRatio: 4.0 / 3.0,
      );

      setState(() {
        _currentHandwritingFile = handwritingFile;
        _isEditing = true;
        _selectedTool = '제스처';
        _isGestureMode = true;
      });

      _painterController.clearDrawables();
      _painterController.background = null;
      _backgroundImageOriginalSize = null;
      _backgroundImageAspectRatio = null;
      _transformationController.value = Matrix4.identity();
    } catch (e) {
      debugPrint('[HandwritingTab] 새 필기 파일 생성 오류: $e');
    }
  }

  Future<void> _editHandwritingFile(HandwritingFile handwritingFile) async {
    setState(() {
      _currentHandwritingFile = handwritingFile;
      _isEditing = true;
      _selectedTool = '제스처';
      _isGestureMode = true;
    });

    try {
      await _loadHandwritingImage(handwritingFile);
      _transformationController.value = Matrix4.identity();
    } catch (e) {
      debugPrint('[HandwritingTab] 필기 이미지 로드 오류: $e');
    }
  }

  Future<void> _loadHandwritingImage(HandwritingFile file) async {
    _painterController.clearDrawables();

    if (file.aspectRatio != null) {
      _backgroundImageAspectRatio = file.aspectRatio;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final littenDir = Directory('${directory.path}/littens/${file.littenId}/handwriting');
      final drawingFile = File('${littenDir.path}/${file.fileName}.png');

      if (await drawingFile.exists()) {
        final imageBytes = await drawingFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(imageBytes);
        final frame = await codec.getNextFrame();
        final uiImage = frame.image;

        _painterController.background = ImageBackgroundDrawable(image: uiImage);
        setState(() {});
      }
    } catch (e) {
      debugPrint('[HandwritingTab] 저장된 필기 이미지 로드 실패: $e');
    }
  }

  Future<void> _addBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final imageBytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(imageBytes);
        final frame = await codec.getNextFrame();
        final uiImage = frame.image;

        setState(() {
          _backgroundImageAspectRatio = uiImage.width / uiImage.height;
          _backgroundImageOriginalSize = Size(uiImage.width.toDouble(), uiImage.height.toDouble());
        });

        _painterController.background = uiImage.backgroundDrawable;
        setState(() {});

        _transformationController.value = Matrix4.identity();
      }
    } catch (e) {
      debugPrint('[HandwritingTab] 배경 이미지 설정 실패: $e');
    }
  }

  Future<void> _exitEditor() async {
    setState(() {
      _isEditing = false;
      _currentHandwritingFile = null;
      _isTextInputMode = false;
      _textInputPosition = null;
    });

    await _loadHandwritingFiles();
  }

  Future<void> _saveHandwritingFile() async {
    if (_currentHandwritingFile == null) return;

    try {
      if (_painterController.drawables.isNotEmpty) {
        await _saveCurrentPageDrawing();
      }

      final currentAspectRatio = _getCanvasAspectRatio();
      _currentHandwritingFile = _currentHandwritingFile!.copyWith(
        aspectRatio: currentAspectRatio,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('필기가 저장되었습니다: ${_currentHandwritingFile!.displayTitle}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('[HandwritingTab] 필기 파일 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('필기 저장에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCurrentPageDrawing() async {
    if (_currentHandwritingFile != null) {
      try {
        if (_painterController.drawables.isEmpty) {
          return;
        }

        final aspectRatio = _getCanvasAspectRatio();
        Size renderSize;
        if (_backgroundImageOriginalSize != null) {
          renderSize = _backgroundImageOriginalSize!;
        } else {
          const double targetWidth = 1200;
          final double targetHeight = targetWidth / aspectRatio;
          renderSize = Size(targetWidth, targetHeight);
        }

        final ui.Image renderedImage = await _painterController.renderImage(renderSize);
        final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final appState = Provider.of<AppStateProvider>(context, listen: false);
          final selectedLitten = appState.selectedLitten!;
          final directory = await getApplicationDocumentsDirectory();
          final handwritingDir = Directory('${directory.path}/littens/${selectedLitten.id}/handwriting');

          if (!await handwritingDir.exists()) {
            await handwritingDir.create(recursive: true);
          }

          final filePath = '${handwritingDir.path}/${_currentHandwritingFile!.fileName}.png';
          final file = File(filePath);
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }
      } catch (e) {
        debugPrint('[HandwritingTab] 현재 페이지 드로잉 저장 오류: $e');
      }
    }
  }

  Future<void> _deleteHandwritingFile(HandwritingFile handwritingFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"${handwritingFile.displayTitle}" 파일을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final handwritingDir = Directory('${directory.path}/littens/${handwritingFile.littenId}/handwriting');
        final filePath = '${handwritingDir.path}/${handwritingFile.fileName}.png';
        final file = File(filePath);

        if (await file.exists()) {
          await file.delete();
          await _loadHandwritingFiles();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${handwritingFile.displayTitle}" 파일이 삭제되었습니다.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[HandwritingTab] 필기 파일 삭제 오류: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('파일 삭제에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}