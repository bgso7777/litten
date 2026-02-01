import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  // 음성 인식(STT) 관련
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _lastPartialText = ''; // 마지막 중간 결과 (교체용)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _htmlController = HtmlEditorController();
    _speechToText = stt.SpeechToText();

    _loadFiles();
    _initializeSpeechToText();
  }

  /// 음성 인식 초기화
  Future<void> _initializeSpeechToText() async {
    debugPrint('🎤 SpeechToText 초기화 시작');
    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          debugPrint('❌ STT 에러: ${error.errorMsg}');
          if (mounted) {
            setState(() {
              _isListening = false;
            });

            // 에러 메시지 사용자에게 표시
            String userMessage = '음성 인식 오류가 발생했습니다.';
            if (error.errorMsg == 'error_language_unavailable') {
              userMessage = '선택한 언어의 음성 인식을 사용할 수 없습니다.\n실제 기기에서 사용해주세요.';
            } else if (error.errorMsg == 'error_server_disconnected') {
              userMessage =
                  '음성 인식 서버와 연결할 수 없습니다.\nGoogle 앱을 설치/업데이트하거나 네트워크를 확인해주세요.';
            } else if (error.errorMsg == 'error_no_match') {
              userMessage = '음성을 인식하지 못했습니다.\n다시 시도해주세요.';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        onStatus: (status) {
          debugPrint('ℹ️ STT 상태: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
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
    debugPrint('🎤 _toggleSpeechToText() 진입: _isListening=$_isListening');

    if (_isListening) {
      // 인식 중지
      await _stopListening();
    } else {
      // 인식 시작
      await _startListening();
    }
  }

  /// 음성 인식 시작
  Future<void> _startListening() async {
    debugPrint('🎤 음성 인식 시작 시도');

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

    // 음성 인식 시작 - 이전 인식 결과 초기화
    setState(() {
      _isListening = true;
    });

    debugPrint('✅ 음성 인식 시작');

    await _speechToText.listen(
      onResult: (result) {
        debugPrint(
          '📝 인식 결과 (isFinal: ${result.finalResult}): ${result.recognizedWords}',
        );

        if (result.recognizedWords.isEmpty) return;

        // 텍스트 파일이 선택되지 않았으면 경고
        if (_currentTextFile == null) {
          debugPrint('⚠️ 텍스트 파일이 선택되지 않음');
          return;
        }

        final currentText = result.recognizedWords;

        if (result.finalResult) {
          // 최종 결과: 임시 span 제거 후 실제 텍스트 삽입
          debugPrint('🏁 최종 결과 - 커서 위치에 삽입: "$currentText"');

          _removePartialSpan();
          _insertFinalText('$currentText ');

          // 다음 인식을 위해 초기화
          setState(() {
            _lastPartialText = '';
          });

          debugPrint('✅ 다음 문장 인식 준비 완료');
        } else {
          // 중간 결과: 실시간으로 임시 span에 표시
          debugPrint('💬 중간 결과 (실시간): "$currentText"');

          _updatePartialSpan(currentText);
          _lastPartialText = currentText;
        }
      },
      localeId: selectedLocaleId, // 사용 가능한 한국어 locale 사용
      pauseFor: const Duration(
        seconds: 30,
      ), // 침묵 대기 시간 연장 (30초 동안 말이 없어도 계속 듣기)
      listenOptions: stt.SpeechListenOptions(
        partialResults: true, // 중간 결과도 표시 (실시간 입력용)
        cancelOnError: false, // 에러 발생 시에도 계속 듣기
        listenMode: stt.ListenMode.dictation, // 받아쓰기 모드 (iOS에서 긴 발화 인식에 필수)
        enableHapticFeedback: false,
        onDevice: true, // 온디바이스 우선 (반응 속도 향상)
      ),
    );
  }

  /// 중간 결과를 임시 span에 업데이트
  void _updatePartialSpan(String text) {
    final escapedText = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    final jsCode = '''
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

          // 현재 커서 위치에 삽입
          var selection = window.getSelection();
          if (selection.rangeCount > 0) {
            var range = selection.getRangeAt(0);
            range.insertNode(span);

            // 커서를 span 뒤로 이동
            range.setStartAfter(span);
            range.setEndAfter(span);
            selection.removeAllRanges();
            selection.addRange(range);
          }

          return 'success';
        } catch(e) {
          return 'error: ' + e.message;
        }
      })();
    ''';

    _htmlController.editorController?.evaluateJavascript(source: jsCode).then((result) {
      debugPrint('✅ 중간 결과 span 업데이트: $result');
    }).catchError((e) {
      debugPrint('❌ 중간 결과 span 업데이트 실패: $e');
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

    _htmlController.editorController?.evaluateJavascript(source: jsCode).then((result) {
      debugPrint('🗑️ 임시 span 제거: $result');
    }).catchError((e) {
      debugPrint('❌ 임시 span 제거 실패: $e');
    });
  }

  /// 최종 텍스트 삽입
  void _insertFinalText(String text) {
    final escapedText = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    final jsCode = '''
      (function() {
        try {
          var summernote = \$('#summernote-2');
          if (!summernote.length) return 'editor_not_found';

          summernote.summernote('focus');
          summernote.summernote('insertText', '$escapedText');

          return 'success';
        } catch(e) {
          return 'error: ' + e.message;
        }
      })();
    ''';

    _htmlController.editorController?.evaluateJavascript(source: jsCode).then((result) {
      debugPrint('✅ 최종 텍스트 삽입: $result');
    }).catchError((e) {
      debugPrint('❌ 최종 텍스트 삽입 실패: $e');
    });
  }

  /// 음성 인식 중지
  Future<void> _stopListening() async {
    debugPrint('🛑 음성 인식 중지');

    // 임시 span 제거
    _removePartialSpan();

    await _speechToText.stop();
    setState(() {
      _isListening = false;
      _lastPartialText = '';
    });
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

          // 파일 카운트 업데이트는 파일 추가/삭제 시에만 필요 (저장 시에는 불필요)
          // await appState.updateFileCount();
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

        print('✅ [텍스트 저장 완료] 편집 모드 유지 - 화면 전환하지 않음');
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
              file.title.isNotEmpty
                  ? file.title
                  : '텍스트 ${DateFormat('yyMMddHHmm').format(file.createdAt)}',
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
              child: Column(
                children: [
                  // 마이크 버튼 바 (툴바 위)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        // 마이크 버튼
                        InkWell(
                          onTap: _toggleSpeechToText,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _isListening ? Colors.red.shade50 : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isListening ? Colors.red : Colors.grey.shade600,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? Colors.red : Colors.grey.shade700,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 상태 텍스트
                        Expanded(
                          child: Text(
                            _isListening ? '음성 인식 중...' : '마이크를 눌러 음성 입력',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isListening ? Colors.red : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            _htmlController.editorController
                                ?.evaluateJavascript(
                                  source: '''
                              setTimeout(function() {
                                var style = document.createElement('style');
                                style.innerHTML = 'body { margin: 0 !important; padding: 8px !important; } p { margin: 0 !important; padding: 0 !important; line-height: 1.5 !important; } div { margin: 0 !important; padding: 0 !important; } br { margin: 0 !important; padding: 0 !important; } * { margin-top: 0 !important; margin-bottom: 0 !important; }';
                                document.head.appendChild(style);
                              }, 500);
                            ''',
                                );
                          },
                          onFocus: () {
                            print('HTML 에디터 포커스됨');
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
    ), // Container 닫기
  ), // Expanded 닫기 (outer)
], // Column children 닫기 (outer)
); // Column 닫기 (outer)
} // _buildTextEditor 닫기

}
