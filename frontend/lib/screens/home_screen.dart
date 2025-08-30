import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/litten_item.dart';
import '../config/themes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 화면 로드 후 최신 리튼으로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showCreateLittenDialog() {
    final l10n = AppLocalizations.of(context);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    if (!appState.canCreateMoreLittens) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.freeUserLimitMessage ?? '무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다. 업그레이드하여 무제한으로 생성하세요!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    _titleController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.createLitten ?? '리튼 생성'),
        content: TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l10n?.title ?? '제목',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
                );
                return;
              }
              
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              try {
                await appState.createLitten(title);
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('$title 리튼이 생성되었습니다.')),
                  );
                  // 새로 생성된 리튼(최신)으로 스크롤
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
                  );
                }
              }
            },
            child: Text(l10n?.create ?? '생성'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          body: appState.littens.isEmpty
              ? EmptyState(
                  icon: Icons.note_add,
                  title: l10n?.emptyLittenTitle ?? '리튼을 생성하거나 선택하세요',
                  description: l10n?.emptyLittenDescription ?? '하단의 \'리튼 생성\' 버튼을 사용해서 첫 번째 노트를 시작하세요',
                  actionText: l10n?.createLitten ?? '리튼 생성',
                  onAction: _showCreateLittenDialog,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await appState.refreshLittens();
                    // 새로고침 후에도 최신 리튼으로 스크롤
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      left: AppSpacing.paddingL.left,
                      right: AppSpacing.paddingL.right,
                      top: AppSpacing.paddingL.top,
                      bottom: AppSpacing.paddingL.bottom + 96, // FloatingActionButton 공간 확보 (16px 추가)
                    ),
                    itemCount: appState.littens.length,
                    itemBuilder: (context, index) {
                      final litten = appState.littens[index];
                      return LittenItem(
                        litten: litten,
                        isSelected: appState.selectedLitten?.id == litten.id,
                        onTap: () => appState.selectLitten(litten),
                        onDelete: () => _showDeleteDialog(litten.id, litten.title),
                        onLongPress: () => _showRenameLittenDialog(litten.id, litten.title),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateLittenDialog,
            tooltip: l10n?.createLitten ?? '리튼 생성',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showRenameLittenDialog(String littenId, String currentTitle) {
    final l10n = AppLocalizations.of(context);
    final TextEditingController renameController = TextEditingController(text: currentTitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.renameLitten ?? '리튼 이름 변경'),
        content: TextField(
          controller: renameController,
          decoration: InputDecoration(
            labelText: l10n?.newName ?? '새 이름',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _performRename(littenId, renameController.text.trim(), renameController, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () => _performRename(littenId, renameController.text.trim(), renameController, context),
            child: Text(l10n?.change ?? '변경'),
          ),
        ],
      ),
    ).then((_) {
      renameController.dispose();
    });
  }

  void _performRename(String littenId, String newTitle, TextEditingController controller, BuildContext dialogContext) async {
    final l10n = AppLocalizations.of(context);
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
      );
      return;
    }
    
    if (newTitle == controller.text) {
      Navigator.of(dialogContext).pop();
      return;
    }
    
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final navigator = Navigator.of(dialogContext);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      await appState.renameLitten(littenId, newTitle);
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('리튼 이름이 \'$newTitle\'로 변경되었습니다.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
      );
    }
  }

  void _showDeleteDialog(String littenId, String title) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteLitten ?? '리튼 삭제'),
        content: Text(l10n?.confirmDeleteLitten != null 
            ? l10n!.confirmDeleteLitten(title)
            : '\'$title\' 리튼을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              await appState.deleteLitten(littenId);
              
              if (mounted) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('$title 리튼이 삭제되었습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}