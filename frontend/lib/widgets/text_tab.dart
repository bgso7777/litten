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
import '../models/audio_file.dart';
import '../services/file_storage_service.dart';
import '../services/litten_service.dart';
import '../services/audio_service.dart';

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

  // 오디오 녹음 관련 (STT와 동시 실행)
  final AudioService _audioService = AudioService();
  bool _isRecordingWithSTT = false; // STT 중 녹음 진행 여부

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
        // ✅ 중복 입력 방지: STT 종료 후 들어오는 결과 무시
        if (!_isListening) {
          debugPrint('⚠️ STT 종료 후 onResult 호출됨 - 무시');
          return;
        }

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

    // 🎙️ STT 시작 직후 녹음도 즉시 시작 (앞부분 누락 방지)
    if (mounted) {
      _startRecordingWithSTT();
    }
  }

  /// 중간 결과를 임시 span에 업데이트
  void _updatePartialSpan(String text) {
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

    _htmlController.editorController
        ?.evaluateJavascript(source: jsCode)
        .then((result) {
          debugPrint('✅ 중간 결과 span 업데이트: $result');
        })
        .catchError((e) {
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

    _htmlController.editorController
        ?.evaluateJavascript(source: jsCode)
        .then((result) {
          debugPrint('🗑️ 임시 span 제거: $result');
        })
        .catchError((e) {
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

    final jsCode =
        '''
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

    _htmlController.editorController
        ?.evaluateJavascript(source: jsCode)
        .then((result) {
          debugPrint('✅ 최종 텍스트 삽입: $result');
        })
        .catchError((e) {
          debugPrint('❌ 최종 텍스트 삽입 실패: $e');
        });
  }

  /// 음성 인식 중지
  Future<void> _stopListening() async {
    debugPrint('🛑 음성 인식 중지');

    // ✅ 중요: STT 중지 전에 상태 변경하여 추가 onResult 무시
    setState(() {
      _isListening = false;
    });

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
    });

    // 🎙️ STT와 함께 녹음이 진행 중이었다면 녹음도 중지하고 파일 저장
    if (_isRecordingWithSTT) {
      await _stopRecordingWithSTT();
    }

    // 💾 STT 중지 시 텍스트 자동 저장 (편집 화면은 유지)
    debugPrint('💾 STT 종료 후 텍스트 자동 저장 시작...');
    await _saveCurrentTextFile();
    debugPrint('✅ STT 종료 후 텍스트 자동 저장 완료');
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
    try {
      debugPrint('🛑 STT 녹음 중지 시도...');

      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final selectedLitten = appState.selectedLitten;

      if (selectedLitten == null) {
        debugPrint('⚠️ 리튼이 선택되지 않음');
        setState(() {
          _isRecordingWithSTT = false;
        });
        return;
      }

      // 녹음 중지 및 파일 생성
      final audioFile = await _audioService.stopRecording(selectedLitten);

      setState(() {
        _isRecordingWithSTT = false;
      });

      if (audioFile != null) {
        debugPrint('✅ STT 녹음 파일 생성됨: ${audioFile.fileName}');

        // 리튼에 오디오 파일 추가
        await LittenService().addAudioFileToLitten(
          selectedLitten.id,
          audioFile.id,
        );

        debugPrint('✅ STT 녹음 파일이 리튼에 저장됨');

        // ⚠️ refreshLittens() 호출하지 않음 - notifyListeners()가 화면 rebuild를 일으켜 편집 모드가 종료됨
        // 녹음 파일은 녹음 탭에서 확인 가능

        // 사용자에게 알림
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
      setState(() {
        _isRecordingWithSTT = false;
      });
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 1. STT 마이크 버튼 (맨 앞)
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
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: Colors.grey.shade400,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
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
          ],
        ),
      ),
    );
  }

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
                onPressed: () async {
                  // 파일 목록 새로고침하여 최근 저장된 파일이 위로 오도록
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
                                hint: '여기에 텍스트를 입력하세요...',
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
                                  print('HTML 에디터 초기화 완료');
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
          ), // Container 닫기
        ), // Expanded 닫기 (outer)
      ], // Column children 닫기 (outer)
    ); // Column 닫기 (outer)
  } // _buildTextEditor 닫기
}
