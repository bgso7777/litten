import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../config/themes.dart';
import '../models/text_file.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';

class TextTab extends StatefulWidget {
  const TextTab({super.key});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _htmlController = HtmlEditorController();

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

  @override
  void dispose() {
    // 메모리 누수 방지를 위한 리소스 정리
    WidgetsBinding.instance.removeObserver(this);
    try {
      _htmlController.disable();
    } catch (e) {
      debugPrint('HtmlEditorController dispose 에러 (무시됨): $e');
    }
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

        // 한 번의 setState로 모든 상태 업데이트
        if (mounted) {
          setState(() {
            _textFiles
              ..clear()
              ..addAll(loadedTextFiles);
            _isLoading = false;
          });
        }

        print(
          '디버그: 파일 목록 로드 완료 - 텍스트: ${_textFiles.length}개',
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
      });
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
    } catch (e) {
      print('HTML 에디터 로딩 에러: $e');
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
      text: file.title.isNotEmpty ? file.title : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
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

          // 파일 카운트 업데이트
          await appState.updateFileCount();
        }

        print('디버그: 텍스트 파일 저장 완료 - 총 ${_textFiles.length}개 파일');

        // 저장 완료 알림
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('저장되었습니다'),
              duration: const Duration(seconds: 1),
            ),
          );
        }

        // 편집 모드를 유지하고 화면 전환하지 않음
        // setState(() {
        //   _isEditing = false;
        //   _currentTextFile = null;
        // });
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
            Text(
              file.title.isNotEmpty ? file.title : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.verticalSpaceXS,
            Text(
              '${file.characterCount}자 • ${file.updatedAt.toString().substring(0, 16)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  Widget _buildTextEditor() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // 상단 헤더 (폭 20% 감소)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
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

        // HTML 에디터
        Expanded(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: HtmlEditor(
                        controller: _htmlController,
                        htmlEditorOptions: const HtmlEditorOptions(
                          hint: '여기에 텍스트를 입력하세요...',
                          shouldEnsureVisible: true,
                          adjustHeightForKeyboard: true,
                          darkMode: false,
                          autoAdjustHeight: false,
                          spellCheck: false,
                        ),
                        htmlToolbarOptions: HtmlToolbarOptions(
                          toolbarPosition: ToolbarPosition.aboveEditor,
                          toolbarType: ToolbarType.nativeScrollable,
                          renderBorder: false,
                          toolbarItemHeight: 32,
                          renderSeparatorWidget: true,
                          separatorWidget: Container(
                            width: 1,
                            height: 24,
                            color: Colors.grey.shade600,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          buttonColor: Colors.grey.shade800,
                          buttonSelectedColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          buttonBorderColor: Colors.transparent,
                          buttonBorderWidth: 0,
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
                          onInit: () {
                            print('HTML 에디터 초기화 완료');
                            // CSS 주입으로 줄 간격 유지
                            _htmlController.editorController?.evaluateJavascript(source: '''
                              setTimeout(function() {
                                var style = document.createElement('style');
                                style.innerHTML = 'body { margin: 0 !important; padding: 8px !important; } p { margin: 0 !important; padding: 0 !important; line-height: 1.5 !important; } div { margin: 0 !important; padding: 0 !important; } br { margin: 0 !important; padding: 0 !important; } * { margin-top: 0 !important; margin-bottom: 0 !important; }';
                                document.head.appendChild(style);
                              }, 500);
                            ''');
                          },
                          onFocus: () {
                            print('HTML 에디터 포커스됨');
                          },
                          onBlur: () {
                            print('HTML 에디터 포커스 해제됨');
                          },
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
}
