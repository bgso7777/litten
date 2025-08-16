import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/note_provider.dart';
import '../config/app_config.dart';
import '../services/preferences_service.dart';
import '../services/audio_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../models/note_model.dart';
import 'home_screen.dart';
import 'recorder_screen.dart';
import 'recorder_screen_simple.dart';
import 'writer_screen.dart';
import 'settings_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  String _subscriptionType = 'free';
  bool _isTextEditorVisible = false;
  String? _editingNoteId;
  FileModel? _editingFile;
  
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _loadSubscriptionType();
    _screens = [
      HomeScreen(onNavigateToRecorder: _navigateToRecorder),
      const RecorderScreen(),
      WriterScreen(onShowTextEditor: showTextEditor),
      const SettingsScreen(),
    ];
  }
  
  Future<void> _loadSubscriptionType() async {
    final subscriptionType = PreferencesService.getSubscriptionType();
    setState(() {
      _subscriptionType = subscriptionType;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<NoteProvider, AudioService>(
      builder: (context, noteProvider, audioService, child) {
        return Scaffold(
          appBar: AppBar(
            title: _buildAppBarTitle(noteProvider, audioService),
            centerTitle: true,
            actions: _buildAppBarActions(noteProvider),
            elevation: 0,
          ),
          body: Stack(
            children: [
              // 기본 화면
              Column(
                children: [
                  // 무료 사용자만 광고 배너 표시
                  if (_subscriptionType == 'free' && AppConfig.showAdsForFreeUsers)
                    const AdBannerWidget(),
                  
                  // 메인 콘텐츠
                  Expanded(
                    child: _screens[_currentIndex],
                  ),
                ],
              ),
              
              // 텍스트 에디터 오버레이
              if (_isTextEditorVisible)
                Positioned(
                  top: (_subscriptionType == 'free' && AppConfig.showAdsForFreeUsers) 
                      ? AppConfig.adBannerHeight.toDouble() 
                      : 0,
                  left: 0,
                  right: 0,
                  bottom: 80, // 탭 바 높이만큼 여백
                  child: _buildTextEditor(),
                ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.mic),
                label: '듣기',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.edit),
                label: '쓰기',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: '설정',
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 앱바 제목 생성
  Widget _buildAppBarTitle(NoteProvider noteProvider, AudioService audioService) {
    if (noteProvider.selectedNote != null) {
      return Text(
        noteProvider.selectedNote!.title,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    String titleText;
    switch (_currentIndex) {
      case 0:
        titleText = '리튼';
        break;
      case 1:
        titleText = '듣기';
        break;
      case 2:
        titleText = '쓰기';
        break;
      case 3:
        titleText = '설정';
        break;
      default:
        titleText = '리튼';
    }
    
    return Text(titleText);
  }
  
  // 앱바 액션 버튼들 생성
  List<Widget> _buildAppBarActions(NoteProvider noteProvider) {
    final actions = <Widget>[];
    
    // 선택된 노트가 있을 때 파일 카운터 표시
    if (noteProvider.selectedNote != null) {
      final note = noteProvider.selectedNote!;
      
      // 오디오 파일 카운터
      if (note.audioFileCount > 0) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFileCountBadge(
              Icons.mic,
              note.audioFileCount,
              AppConfig.maxAudioFilesPerNoteForFree,
              Colors.red,
            ),
          ),
        );
      }
      
      // 쓰기 파일 카운터
      if (note.writingFileCount > 0) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFileCountBadge(
              Icons.edit,
              note.writingFileCount,
              AppConfig.maxTextFilesPerNoteForFree + 
              AppConfig.maxHandwritingFilesPerNoteForFree,
              Colors.blue,
            ),
          ),
        );
      }
    } else {
      // 전체 통계 표시
      final stats = noteProvider.usageStats;
      final totalNotes = stats['totalNotes'] ?? 0;
      
      if (totalNotes > 0) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFileCountBadge(
              Icons.folder,
              totalNotes,
              AppConfig.maxNotesForFree,
              Colors.green,
            ),
          ),
        );
      }
    }
    
    return actions;
  }
  
  // 파일 카운터 배지 위젯
  Widget _buildFileCountBadge(
    IconData icon,
    int count,
    int maxCount,
    Color color,
  ) {
    final isLimitReached = _subscriptionType == 'free' && count >= maxCount;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLimitReached ? Colors.orange : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLimitReached ? Colors.orange : color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isLimitReached ? Colors.white : color,
          ),
          const SizedBox(width: 4),
          Text(
            _subscriptionType == 'free' ? '$count/$maxCount' : '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isLimitReached ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
  
  // 텍스트 에디터 빌드
  Widget _buildTextEditor() {
    return Material(
      elevation: 8,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // 텍스트 에디터 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.text_fields, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editingFile != null ? '텍스트 편집' : '새 텍스트 파일',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _closeTextEditor,
                  ),
                ],
              ),
            ),
            
            // 파일명 입력
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _fileNameController,
                decoration: const InputDecoration(
                  labelText: '파일명',
                  border: OutlineInputBorder(),
                  hintText: '파일명을 입력하세요',
                ),
                maxLines: 1,
              ),
            ),
            
            // 텍스트 에디터
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _textEditingController,
                  decoration: const InputDecoration(
                    hintText: '내용을 입력하세요...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
            
            // 저장 버튼
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTextFile,
                child: Text(
                  _editingFile != null ? '수정 완료' : '저장',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 텍스트 컨트롤러들
  final TextEditingController _textEditingController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  
  // 텍스트 에디터 열기
  void showTextEditor({String? noteId, FileModel? existingFile}) {
    _editingNoteId = noteId;
    _editingFile = existingFile;
    
    if (existingFile != null) {
      _textEditingController.text = existingFile.content;
      _fileNameController.text = existingFile.name;
    } else {
      _textEditingController.clear();
      _fileNameController.text = '새 텍스트 파일';
    }
    
    setState(() {
      _isTextEditorVisible = true;
    });
  }
  
  // 텍스트 에디터 닫기
  void _closeTextEditor() {
    setState(() {
      _isTextEditorVisible = false;
    });
    _textEditingController.clear();
    _fileNameController.clear();
    _editingNoteId = null;
    _editingFile = null;
  }
  
  // 텍스트 파일 저장
  Future<void> _saveTextFile() async {
    final fileName = _fileNameController.text.trim();
    final content = _textEditingController.text.trim();
    
    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파일명을 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final noteProvider = context.read<NoteProvider>();
      String targetNoteId = _editingNoteId ?? '';
      
      // 노트가 선택되지 않은 경우 기본리튼 생성
      if (targetNoteId.isEmpty || noteProvider.getNoteById(targetNoteId) == null) {
        final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
        if (defaultNote != null) {
          targetNoteId = defaultNote.id;
        }
      }
      
      if (_editingFile != null) {
        // 기존 파일 수정
        final updatedFile = _editingFile!.copyWith(
          name: fileName,
          content: content,
          updatedAt: DateTime.now(),
        );
        await noteProvider.updateFileInNote(targetNoteId, updatedFile);
      } else {
        // 새 파일 생성
        final newFile = FileModel(
          id: const Uuid().v4(),
          name: fileName,
          type: FileType.text,
          content: content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteId: targetNoteId,
        );
        await noteProvider.addFileToNote(targetNoteId, newFile);
      }
      
      _closeTextEditor();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fileName이(가) 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // 듣기 탭으로 이동
  void _navigateToRecorder() {
    setState(() {
      _currentIndex = 1; // 듣기 탭 인덱스
    });
  }
  
  @override
  void dispose() {
    _textEditingController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }
}