import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../services/subscription_service.dart';
import '../services/preferences_service.dart';
import '../models/note_model.dart';
import '../widgets/note_create_dialog.dart';
import '../widgets/note_list_item.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/upgrade_dialog.dart';
import '../config/app_config.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToRecorder;
  
  const HomeScreen({super.key, this.onNavigateToRecorder});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<NoteProvider, SubscriptionService>(
      builder: (context, noteProvider, subscriptionService, child) {
        // 디버그 로그
        debugPrint('HomeScreen build - notes count: ${noteProvider.notes.length}');
        debugPrint('HomeScreen build - isLoading: ${noteProvider.isLoading}');
        
        final filteredNotes = _searchQuery.isEmpty
            ? noteProvider.notes
            : noteProvider.searchNotes(_searchQuery);
        
        return Scaffold(
          body: Column(
            children: [
              // 사용량 통계 카드 (상단에 표시)
              _buildUsageStatsCard(noteProvider.usageStats, subscriptionService),
              
              // 검색 바
              if (noteProvider.notes.isNotEmpty) _buildSearchBar(),
              
              // 노트 목록
              Expanded(
                child: noteProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredNotes.isEmpty
                        ? _buildEmptyState(noteProvider)
                        : _buildNoteList(filteredNotes),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createNote(noteProvider, subscriptionService),
            icon: const Icon(Icons.add),
            label: const Text('리튼 생성'),
          ),
        );
      },
    );
  }
  
  // 검색 바 위젯
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '리튼 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }
  
  // 빈 상태 위젯
  Widget _buildEmptyState(NoteProvider noteProvider) {
    debugPrint('_buildEmptyState - notes.isEmpty: ${noteProvider.notes.isEmpty}');
    debugPrint('_buildEmptyState - searchQuery: $_searchQuery');
    
    if (noteProvider.notes.isEmpty) {
      // 노트가 아예 없을 때
      return const EmptyStateWidget(
        icon: Icons.note_add,
        title: '첫 번째 리튼을 만들어보세요',
        subtitle: '음성, 텍스트, 필기를 하나의 공간에서\n통합 관리할 수 있습니다',
        actionText: '리튼 생성',
      );
    } else {
      // 검색 결과가 없을 때
      return EmptyStateWidget(
        icon: Icons.search_off,
        title: '검색 결과가 없습니다',
        subtitle: '"$_searchQuery"와 일치하는 리튼을 찾을 수 없습니다',
        actionText: '검색어 지우기',
        onActionPressed: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
        },
      );
    }
  }
  
  // 사용량 통계 카드
  Widget _buildUsageStatsCard(Map<String, int> stats, SubscriptionService subscriptionService) {
    try {
      final subscriptionType = PreferencesService.getSubscriptionType();
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '사용량 통계',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subscriptionService.isFreePlan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '무료 플랜',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatItem('리튼', '${stats['totalNotes']}', '${AppConfig.maxNotesForFree}', subscriptionService.isFreePlan)),
                  Expanded(child: _buildStatItem('오디오', '${stats['totalAudioFiles']}', subscriptionService.isFreePlan ? '${AppConfig.maxNotesForFree * AppConfig.maxAudioFilesPerNoteForFree}' : '∞', subscriptionService.isFreePlan)),
                  Expanded(child: _buildStatItem('텍스트', '${stats['totalTextFiles']}', subscriptionService.isFreePlan ? '${AppConfig.maxNotesForFree * AppConfig.maxTextFilesPerNoteForFree}' : '∞', subscriptionService.isFreePlan)),
                  Expanded(child: _buildStatItem('필기', '${stats['totalHandwritingFiles']}', subscriptionService.isFreePlan ? '${AppConfig.maxNotesForFree * AppConfig.maxHandwritingFilesPerNoteForFree}' : '∞', subscriptionService.isFreePlan)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    } catch (e) {
      debugPrint('사용량 통계 카드 오류: $e');
      return Container(
        margin: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('사용량 통계 로딩 중... ($e)'),
          ),
        ),
      );
    }
  }
  
  Widget _buildStatItem(String label, String current, String max, bool showLimit) {
    final currentNum = int.tryParse(current) ?? 0;
    final maxNum = max == '∞' ? null : (int.tryParse(max) ?? 0);
    final isNearLimit = showLimit && maxNum != null && currentNum >= maxNum * 0.8;
    final isAtLimit = showLimit && maxNum != null && currentNum >= maxNum;
    
    return Column(
      children: [
        Text(
          showLimit && max != '∞' ? '$current/$max' : current,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isAtLimit 
                ? Colors.red 
                : isNearLimit 
                    ? Colors.orange
                    : Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        if (isNearLimit && !isAtLimit)
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 2,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(1),
            ),
          )
        else if (isAtLimit)
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 2,
            width: 30,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }

  // 노트 목록 위젯
  Widget _buildNoteList(List<NoteModel> notes) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<NoteProvider>().refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NoteListItem(
              note: notes[index],
              onTap: () => _onNoteSelected(notes[index]),
              onDelete: () => _deleteNote(notes[index].id),
              onEdit: (newTitle, newDescription) => _editNote(notes[index], newTitle, newDescription),
            ),
          );
        },
      ),
    );
  }
  
  // 노트 생성
  Future<void> _createNote(NoteProvider noteProvider, SubscriptionService subscriptionService) async {
    // 무료 버전 제한 확인
    if (!subscriptionService.canUseFeature('unlimited_notes') &&
        noteProvider.notes.length >= AppConfig.maxNotesForFree) {
      UpgradeDialog.show(
        context,
        featureName: '무제한 리튼 생성',
        specificBenefits: [
          '무제한 리튼 생성',
          '무제한 파일 저장',
          '광고 완전 제거',
          '클라우드 동기화',
        ],
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const NoteCreateDialog(),
    );
    
    if (result == true) {
      // 노트가 생성되면 새로고침
      if (mounted) {
        await noteProvider.refresh();
        
        // 듣기 탭으로 이동
        if (widget.onNavigateToRecorder != null) {
          widget.onNavigateToRecorder!();
        }
      }
    }
  }
  
  // 노트 선택
  void _onNoteSelected(NoteModel note) {
    final noteProvider = context.read<NoteProvider>();
    noteProvider.selectNote(note.id);
    
    // 선택된 노트 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${note.title} 선택됨'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // 듣기 탭으로 이동
    if (widget.onNavigateToRecorder != null) {
      widget.onNavigateToRecorder!();
    }
  }
  
  // 노트 삭제
  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리튼 삭제'),
        content: const Text('이 리튼을 삭제하시겠습니까?\n모든 파일이 함께 삭제됩니다.'),
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
    
    if (confirmed == true && mounted) {
      try {
        final success = await context.read<NoteProvider>().deleteNote(noteId);
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리튼이 삭제되었습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('리튼 삭제 실패: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
  
  // 리튼 편집
  Future<void> _editNote(NoteModel note, String newTitle, String newDescription) async {
    try {
      final updatedNote = note.copyWith(
        title: newTitle,
        description: newDescription,
      );
      
      final success = await context.read<NoteProvider>().updateNote(updatedNote);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\'${newTitle}\'로 수정되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('리튼 편집 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}