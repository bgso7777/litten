import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:intl/intl.dart';
import '../services/app_state_provider.dart';
import '../models/text_file.dart';
import '../models/litten.dart';
import '../config/app_spacing.dart';
import '../config/app_text_styles.dart';
import '../widgets/empty_state.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TextTab extends StatefulWidget {
  const TextTab({super.key});

  @override
  State<TextTab> createState() => _TextTabState();
}

class _TextTabState extends State<TextTab> {
  late HtmlEditorController _htmlController;
  List<TextFile> _textFiles = [];
  bool _isLoading = false;
  bool _isEditing = false;
  TextFile? _currentTextFile;

  @override
  void initState() {
    super.initState();
    _htmlController = HtmlEditorController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTextFiles();
    });
  }

  @override
  void dispose() {
    try {
      _htmlController.disable();
    } catch (e) {
      debugPrint('[TextTab] HTML 에디터 비활성화 오류: $e');
    }
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
            subtitle: '텍스트 작성을 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.',
          );
        }

        if (_isEditing && _currentTextFile != null) {
          return _buildTextEditor();
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              Column(
                children: [
                  // 텍스트 파일 목록
                  Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _textFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '아직 작성된 텍스트가 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '하단의 + 버튼을 눌러 시작해보세요',
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
                            itemCount: _textFiles.length,
                            itemBuilder: (context, index) {
                              return _buildTextFileItem(_textFiles[index]);
                            },
                          ),
                ),
              ],
            ),
            // 추가 버튼 (우하단 고정)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: _createNewTextFile,
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                child: const Icon(
                  Icons.add,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      );
      },
    );
  }

  Widget _buildTextEditor() {
    return Column(
      children: [
        // 상단 헤더
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.green.shade200),
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
                  _currentTextFile?.displayTitle ?? '새 텍스트',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _saveTextFile,
                icon: const Icon(Icons.save),
                tooltip: '저장',
              ),
            ],
          ),
        ),
        // HTML 에디터
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: double.infinity,
                color: Colors.white,
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
                        buttonSelectedColor: Colors.green.shade700.withValues(alpha: 0.8),
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
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextFileItem(TextFile textFile) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.paddingS),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.description,
            color: Colors.green.shade700,
            size: 24,
          ),
        ),
        title: Text(
          textFile.displayTitle,
          style: AppTextStyles.headline3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              timeFormat.format(textFile.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(width: 12),
            Icon(Icons.text_fields, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '${textFile.content.length}자',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editTextFile(textFile),
              icon: Icon(
                Icons.edit,
                color: Colors.green.shade700,
              ),
              tooltip: '편집',
            ),
            IconButton(
              onPressed: () => _deleteTextFile(textFile),
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
              tooltip: '삭제',
            ),
          ],
        ),
        onTap: () => _editTextFile(textFile),
      ),
    );
  }

  Future<void> _loadTextFiles() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final textFiles = await _getTextFiles(selectedLitten);
      setState(() {
        _textFiles = textFiles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[TextTab] 텍스트 파일 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<TextFile>> _getTextFiles(Litten litten) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final textDir = Directory('${directory.path}/littens/${litten.id}/text');

      if (!await textDir.exists()) {
        return [];
      }

      final files = await textDir.list().toList();
      final textFiles = <TextFile>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.html')) {
          final stat = await file.stat();
          final fileName = file.path.split('/').last.replaceAll('.html', '');
          final content = await file.readAsString();

          final textFile = TextFile(
            id: stat.modified.millisecondsSinceEpoch.toString(),
            littenId: litten.id,
            title: fileName.startsWith('쓰기') ? fileName : fileName,
            content: content,
            createdAt: stat.modified,
          );

          textFiles.add(textFile);
        }
      }

      textFiles.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return textFiles;
    } catch (e) {
      debugPrint('[TextTab] 텍스트 파일 목록 조회 오류: $e');
      return [];
    }
  }

  Future<void> _createNewTextFile() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final selectedLitten = appState.selectedLitten;

    if (selectedLitten == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final textDir = Directory('${directory.path}/littens/${selectedLitten.id}/text');
      if (!await textDir.exists()) {
        await textDir.create(recursive: true);
      }

      final now = DateTime.now();
      final fileName = '쓰기${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final textFile = TextFile(
        id: now.millisecondsSinceEpoch.toString(),
        littenId: selectedLitten.id,
        title: fileName,
        content: '',
        createdAt: now,
      );

      setState(() {
        _currentTextFile = textFile;
        _isEditing = true;
      });

      // HTML 에디터 초기화
      await Future.delayed(const Duration(milliseconds: 300));
      _htmlController.setText('');
    } catch (e) {
      debugPrint('[TextTab] 새 텍스트 파일 생성 오류: $e');
    }
  }

  Future<void> _editTextFile(TextFile textFile) async {
    setState(() {
      _currentTextFile = textFile;
      _isEditing = true;
    });

    // HTML 에디터가 로딩될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      _htmlController.setText(textFile.content);
    } catch (e) {
      debugPrint('[TextTab] HTML 에디터 로딩 오류: $e');
    }
  }

  Future<void> _exitEditor() async {
    setState(() {
      _isEditing = false;
      _currentTextFile = null;
    });

    await _loadTextFiles();
  }

  Future<void> _saveTextFile() async {
    if (_currentTextFile == null) return;

    try {
      String htmlContent = '';
      try {
        htmlContent = await _htmlController.getText();
      } catch (e) {
        htmlContent = _currentTextFile?.content ?? '';
      }

      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final textDir = Directory('${directory.path}/littens/${selectedLitten.id}/text');
      if (!await textDir.exists()) {
        await textDir.create(recursive: true);
      }

      final filePath = '${textDir.path}/${_currentTextFile!.fileName}.html';
      final file = File(filePath);
      await file.writeAsString(htmlContent);

      _currentTextFile = _currentTextFile!.copyWith(content: htmlContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('텍스트가 저장되었습니다: ${_currentTextFile!.displayTitle}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TextTab] 텍스트 파일 저장 오류: $e');
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

  Future<void> _deleteTextFile(TextFile textFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"${textFile.displayTitle}" 파일을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
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
        final textDir = Directory('${directory.path}/littens/${textFile.littenId}/text');
        final filePath = '${textDir.path}/${textFile.fileName}.html';
        final file = File(filePath);

        if (await file.exists()) {
          await file.delete();
          await _loadTextFiles();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${textFile.displayTitle}" 파일이 삭제되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[TextTab] 텍스트 파일 삭제 오류: $e');
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